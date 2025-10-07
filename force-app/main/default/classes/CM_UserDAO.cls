public without sharing class CM_UserDAO {
    public static Map<Id, String> profileIdToName = new Map<Id, String>();
    public static Map<Id, String> roleIdToDeveloperName = new Map<Id, String>();

    public class TargetAssignments {
        public Set<Id> permissionSetIds;
        public Set<Id> permissionSetGroupIds;
        public TargetAssignments() {
            permissionSetIds = new Set<Id>();
            permissionSetGroupIds = new Set<Id>();
        }
    }

    public static void applyAssignments(List<User> users) {
        if (users == null || users.isEmpty()) return;

        loadProfileAndRoleNames(users);

        List<CM_CommonConstants.AssignmentRule> rules = CM_CommonConstants.getRules();

        Set<String> allPsDeveloperNames = new Set<String>();
        Set<String> allPsgDeveloperNames = new Set<String>();
        for (CM_CommonConstants.AssignmentRule r : rules) {
            allPsDeveloperNames.addAll(r.permissionSetDeveloperNames);
            allPsgDeveloperNames.addAll(r.permissionSetGroupDeveloperNames);
        }

        Map<String, Id> psDevNameToId = new Map<String, Id>();
        if (!allPsDeveloperNames.isEmpty()) {
            for (PermissionSet ps : [
                SELECT Id, Name
                FROM PermissionSet
                WHERE Name IN :allPsDeveloperNames
            ]) {
                psDevNameToId.put(ps.Name, ps.Id);
            }
        }

        Map<String, Id> psgDevNameToId = new Map<String, Id>();
        if (!allPsgDeveloperNames.isEmpty()) {
            for (PermissionSetGroup psg : [
                SELECT Id, DeveloperName
                FROM PermissionSetGroup
                WHERE DeveloperName IN :allPsgDeveloperNames
            ]) {
                psgDevNameToId.put(psg.DeveloperName, psg.Id);
            }
        }

        Map<Id, TargetAssignments> userIdToTargets = new Map<Id, TargetAssignments>();
        for (User u : users) {
            TargetAssignments targets = new TargetAssignments();
            for (CM_CommonConstants.AssignmentRule r : rules) {
                if (r.matches(u)) {
                    for (String psDevName : r.permissionSetDeveloperNames) {
                        if (psDevNameToId.containsKey(psDevName)) targets.permissionSetIds.add(psDevNameToId.get(psDevName));
                    }
                    for (String psgDevName : r.permissionSetGroupDeveloperNames) {
                        if (psgDevNameToId.containsKey(psgDevName)) targets.permissionSetGroupIds.add(psgDevNameToId.get(psgDevName));
                    }
                }
            }
            userIdToTargets.put(u.Id, targets);
        }

        Set<Id> userIds = new Set<Id>();
        for (User u : users) userIds.add(u.Id);

        Map<Id, Map<Id, PermissionSetAssignment>> userIdToExistingPsByPsId = new Map<Id, Map<Id, PermissionSetAssignment>>();
        if (!userIds.isEmpty() && !allPsDeveloperNames.isEmpty()) {
            for (PermissionSetAssignment psa : [
                SELECT Id, AssigneeId, PermissionSetId, PermissionSet.Name
                FROM PermissionSetAssignment
                WHERE AssigneeId IN :userIds
                AND PermissionSet.Name IN :allPsDeveloperNames
            ]) {
                Map<Id, PermissionSetAssignment> psIdToAssign = userIdToExistingPsByPsId.get(psa.AssigneeId);
                if (psIdToAssign == null) {
                    psIdToAssign = new Map<Id, PermissionSetAssignment>();
                    userIdToExistingPsByPsId.put(psa.AssigneeId, psIdToAssign);
                }
                psIdToAssign.put(psa.PermissionSetId, psa);
            }
        }

        Map<Id, Map<Id, PermissionSetGroupAssignment>> userIdToExistingPsgByPsgId = new Map<Id, Map<Id, PermissionSetGroupAssignment>>();
        if (!userIds.isEmpty() && !allPsgDeveloperNames.isEmpty()) {
            for (PermissionSetGroupAssignment psga : [
                SELECT Id, AssigneeId, PermissionSetGroupId, PermissionSetGroup.DeveloperName
                FROM PermissionSetGroupAssignment
                WHERE AssigneeId IN :userIds
                AND PermissionSetGroup.DeveloperName IN :allPsgDeveloperNames
            ]) {
                Map<Id, PermissionSetGroupAssignment> psgIdToAssign = userIdToExistingPsgByPsgId.get(psga.AssigneeId);
                if (psgIdToAssign == null) {
                    psgIdToAssign = new Map<Id, PermissionSetGroupAssignment>();
                    userIdToExistingPsgByPsgId.put(psga.AssigneeId, psgIdToAssign);
                }
                psgIdToAssign.put(psga.PermissionSetGroupId, psga);
            }
        }

        List<PermissionSetAssignment> psToInsert = new List<PermissionSetAssignment>();
        List<PermissionSetGroupAssignment> psgToInsert = new List<PermissionSetGroupAssignment>();
        List<PermissionSetAssignment> psToDelete = new List<PermissionSetAssignment>();
        List<PermissionSetGroupAssignment> psgToDelete = new List<PermissionSetGroupAssignment>();

        for (Id userId : userIdToTargets.keySet()) {
            TargetAssignments targets = userIdToTargets.get(userId);

            Map<Id, PermissionSetAssignment> existingPs = userIdToExistingPsByPsId.get(userId);
            if (existingPs == null) existingPs = new Map<Id, PermissionSetAssignment>();

            Map<Id, PermissionSetGroupAssignment> existingPsg = userIdToExistingPsgByPsgId.get(userId);
            if (existingPsg == null) existingPsg = new Map<Id, PermissionSetGroupAssignment>();

            for (Id targetPsId : targets.permissionSetIds) {
                if (!existingPs.containsKey(targetPsId)) {
                    PermissionSetAssignment psa = new PermissionSetAssignment();
                    psa.AssigneeId = userId;
                    psa.PermissionSetId = targetPsId;
                    psToInsert.add(psa);
                }
            }
            for (Id existingPsId : existingPs.keySet()) {
                if (!targets.permissionSetIds.contains(existingPsId)) {
                    psToDelete.add(existingPs.get(existingPsId));
                }
            }

            for (Id targetPsgId : targets.permissionSetGroupIds) {
                if (!existingPsg.containsKey(targetPsgId)) {
                    PermissionSetGroupAssignment psga = new PermissionSetGroupAssignment();
                    psga.AssigneeId = userId;
                    psga.PermissionSetGroupId = targetPsgId;
                    psgToInsert.add(psga);
                }
            }
            for (Id existingPsgId : existingPsg.keySet()) {
                if (!targets.permissionSetGroupIds.contains(existingPsgId)) {
                    psgToDelete.add(existingPsg.get(existingPsgId));
                }
            }
        }

        if (!psToInsert.isEmpty()) insert psToInsert;
        if (!psgToInsert.isEmpty()) insert psgToInsert;
        if (!psToDelete.isEmpty()) delete psToDelete;
        if (!psgToDelete.isEmpty()) delete psgToDelete;
    }

    private static void loadProfileAndRoleNames(List<User> users) {
        profileIdToName.clear();
        roleIdToDeveloperName.clear();

        Set<Id> profileIds = new Set<Id>();
        Set<Id> roleIds = new Set<Id>();

        for (User u : users) {
            if (u.ProfileId != null) profileIds.add(u.ProfileId);
            if (u.UserRoleId != null) roleIds.add(u.UserRoleId);
        }

        if (!profileIds.isEmpty()) {
            for (Profile p : [SELECT Id, Name FROM Profile WHERE Id IN :profileIds]) {
                profileIdToName.put(p.Id, p.Name);
            }
        }

        if (!roleIds.isEmpty()) {
            for (UserRole r : [SELECT Id, DeveloperName FROM UserRole WHERE Id IN :roleIds]) {
                roleIdToDeveloperName.put(r.Id, r.DeveloperName);
            }
        }
    }
}
