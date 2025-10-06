public without sharing class CM_UserDAO {
    // Map to hold Profile Id to Profile Name
    public static Map<Id, String> profileIdToName = new Map<Id, String>(); // profile id => name
    // Map to hold Role Id to Role DeveloperName
    public static Map<Id, String> roleIdToDeveloperName = new Map<Id, String>(); // role id => developer name

    public class TargetAssignments {
        public Set<Id> permissionSetIds; // target PS ids for a user
        public Set<Id> permissionSetGroupIds; // target PSG ids for a user
        public TargetAssignments() {
            // create empty sets to store ids
            permissionSetIds = new Set<Id>(); // start empty
            permissionSetGroupIds = new Set<Id>(); // start empty
        }
    }

    public static void applyAssignments(List<User> users) {
        // stop if list is empty
        if (users == null || users.isEmpty()) return; // nothing to do

        // load profile and role names for all users
        loadProfileAndRoleNames(users); // fills maps above

        // get all rules from constants
        List<CM_CommonConstants.AssignmentRule> rules = CM_CommonConstants.getRules(); // list of rules

        // collect all PS developer names used by any rule
        Set<String> allPsDeveloperNames = new Set<String>(); // holds all PS names
        // collect all PSG developer names used by any rule
        Set<String> allPsgDeveloperNames = new Set<String>(); // holds all PSG names
        for (CM_CommonConstants.AssignmentRule r : rules) {
            // add PS names from this rule
            allPsDeveloperNames.addAll(r.permissionSetDeveloperNames); // merge
            // add PSG names from this rule
            allPsgDeveloperNames.addAll(r.permissionSetGroupDeveloperNames); // merge
        }

        // map PS developer name to Id
        Map<String, Id> psDevNameToId = new Map<String, Id>(); // PS name => PS id
        if (!allPsDeveloperNames.isEmpty()) {
            // query PS ids by developer name once
            for (PermissionSet ps : [
                SELECT Id, Name
                FROM PermissionSet
                WHERE Name IN :allPsDeveloperNames
            ]) {
                // store the id for quick lookup
                psDevNameToId.put(ps.Name, ps.Id); // map
            }
        }

        // map PSG developer name to Id
        Map<String, Id> psgDevNameToId = new Map<String, Id>(); // PSG name => PSG id
        if (!allPsgDeveloperNames.isEmpty()) {
            // query PSG ids by developer name once
            for (PermissionSetGroup psg : [
                SELECT Id, DeveloperName
                FROM PermissionSetGroup
                WHERE DeveloperName IN :allPsgDeveloperNames
            ]) {
                // store the id for quick lookup
                psgDevNameToId.put(psg.DeveloperName, psg.Id); // map
            }
        }

        // map each user to the target PS/PSG ids based on matching rules
        Map<Id, TargetAssignments> userIdToTargets = new Map<Id, TargetAssignments>(); // user id => targets
        for (User u : users) {
            // create target holder for this user
            TargetAssignments targets = new TargetAssignments(); // new empty targets

            // check all rules for this user
            for (CM_CommonConstants.AssignmentRule r : rules) {
                // if this rule matches the user
                if (r.matches(u)) {
                    // add PS ids for this rule
                    for (String psDevName : r.permissionSetDeveloperNames) {
                        // get PS id by name if exists
                        if (psDevNameToId.containsKey(psDevName)) targets.permissionSetIds.add(psDevNameToId.get(psDevName)); // add
                    }
                    // add PSG ids for this rule
                    for (String psgDevName : r.permissionSetGroupDeveloperNames) {
                        // get PSG id by name if exists
                        if (psgDevNameToId.containsKey(psgDevName)) targets.permissionSetGroupIds.add(psgDevNameToId.get(psgDevName)); // add
                    }
                }
            }

            // store targets for this user
            userIdToTargets.put(u.Id, targets); // save
        }

        // collect user ids to query existing assignments
        Set<Id> userIds = new Set<Id>(); // set of user ids
        for (User u : users) userIds.add(u.Id); // add all user ids

        // build maps for existing PS assignments per user
        Map<Id, Map<Id, PermissionSetAssignment>> userIdToExistingPsByPsId = new Map<Id, Map<Id, PermissionSetAssignment>>(); // user => (ps id => psa)
        if (!userIds.isEmpty() && !allPsDeveloperNames.isEmpty()) {
            // query existing PS assignments that we manage
            for (PermissionSetAssignment psa : [
                SELECT Id, AssigneeId, PermissionSetId, PermissionSet.Name
                FROM PermissionSetAssignment
                WHERE AssigneeId IN :userIds
                AND PermissionSet.Name IN :allPsDeveloperNames
            ]) {
                // get inner map for this user
                Map<Id, PermissionSetAssignment> psIdToAssign = userIdToExistingPsByPsId.get(psa.AssigneeId); // inner
                // create inner map if missing
                if (psIdToAssign == null) {
                    psIdToAssign = new Map<Id, PermissionSetAssignment>(); // create
                    userIdToExistingPsByPsId.put(psa.AssigneeId, psIdToAssign); // put
                }
                // store by PS id
                psIdToAssign.put(psa.PermissionSetId, psa); // save record
            }
        }

        // build maps for existing PSG assignments per user
        Map<Id, Map<Id, PermissionSetGroupAssignment>> userIdToExistingPsgByPsgId = new Map<Id, Map<Id, PermissionSetGroupAssignment>>(); // user => (psg id => psga)
        if (!userIds.isEmpty() && !allPsgDeveloperNames.isEmpty()) {
            // query existing PSG assignments that we manage
            for (PermissionSetGroupAssignment psga : [
                SELECT Id, AssigneeId, PermissionSetGroupId, PermissionSetGroup.DeveloperName
                FROM PermissionSetGroupAssignment
                WHERE AssigneeId IN :userIds
                AND PermissionSetGroup.DeveloperName IN :allPsgDeveloperNames
            ]) {
                // get inner map for this user
                Map<Id, PermissionSetGroupAssignment> psgIdToAssign = userIdToExistingPsgByPsgId.get(psga.AssigneeId); // inner
                // create inner map if missing
                if (psgIdToAssign == null) {
                    psgIdToAssign = new Map<Id, PermissionSetGroupAssignment>(); // create
                    userIdToExistingPsgByPsgId.put(psga.AssigneeId, psgIdToAssign); // put
                }
                // store by PSG id
                psgIdToAssign.put(psga.PermissionSetGroupId, psga); // save record
            }
        }

        // lists to collect new assignments to insert
        List<PermissionSetAssignment> psToInsert = new List<PermissionSetAssignment>(); // new PS assignments
        List<PermissionSetGroupAssignment> psgToInsert = new List<PermissionSetGroupAssignment>(); // new PSG assignments

        // lists to collect old assignments to delete
        List<PermissionSetAssignment> psToDelete = new List<PermissionSetAssignment>(); // old PS assignments
        List<PermissionSetGroupAssignment> psgToDelete = new List<PermissionSetGroupAssignment>(); // old PSG assignments

        // for each user, calculate adds and removals
        for (Id userId : userIdToTargets.keySet()) {
            // get target sets for this user
            TargetAssignments targets = userIdToTargets.get(userId); // desired

            // get existing PS assignments for this user
            Map<Id, PermissionSetAssignment> existingPs = userIdToExistingPsByPsId.get(userId);
            if (existingPs == null) existingPs = new Map<Id, PermissionSetAssignment>(); // ensure not null

            // get existing PSG assignments for this user
            Map<Id, PermissionSetGroupAssignment> existingPsg = userIdToExistingPsgByPsgId.get(userId);
            if (existingPsg == null) existingPsg = new Map<Id, PermissionSetGroupAssignment>(); // ensure not null

            // add any missing PS assignments
            for (Id targetPsId : targets.permissionSetIds) {
                // if not already assigned
                if (!existingPs.containsKey(targetPsId)) {
                    // create new assignment record
                    PermissionSetAssignment psa = new PermissionSetAssignment(); // new record
                    psa.AssigneeId = userId; // set user
                    psa.PermissionSetId = targetPsId; // set ps
                    psToInsert.add(psa); // collect to insert
                }
            }
            // remove PS assignments that are no longer needed
            for (Id existingPsId : existingPs.keySet()) {
                // if existing id is not in targets
                if (!targets.permissionSetIds.contains(existingPsId)) {
                    // mark for deletion
                    psToDelete.add(existingPs.get(existingPsId)); // collect to delete
                }
            }

            // add any missing PSG assignments
            for (Id targetPsgId : targets.permissionSetGroupIds) {
                // if not already assigned
                if (!existingPsg.containsKey(targetPsgId)) {
                    // create new assignment record
                    PermissionSetGroupAssignment psga = new PermissionSetGroupAssignment(); // new record
                    psga.AssigneeId = userId; // set user
                    psga.PermissionSetGroupId = targetPsgId; // set psg
                    psgToInsert.add(psga); // collect to insert
                }
            }
            // remove PSG assignments that are no longer needed
            for (Id existingPsgId : existingPsg.keySet()) {
                // if existing id is not in targets
                if (!targets.permissionSetGroupIds.contains(existingPsgId)) {
                    // mark for deletion
                    psgToDelete.add(existingPsg.get(existingPsgId)); // collect to delete
                }
            }
        }

        // insert new assignments in bulk if any
        if (!psToInsert.isEmpty()) insert psToInsert; // add PS assignments
        if (!psgToInsert.isEmpty()) insert psgToInsert; // add PSG assignments

        // delete old assignments in bulk if any
        if (!psToDelete.isEmpty()) delete psToDelete; // remove PS assignments
        if (!psgToDelete.isEmpty()) delete psgToDelete; // remove PSG assignments
    }

    private static void loadProfileAndRoleNames(List<User> users) {
        // clear maps first
        profileIdToName.clear(); // reset profiles map
        roleIdToDeveloperName.clear(); // reset roles map

        // collect unique profile ids
        Set<Id> profileIds = new Set<Id>(); // set of profile ids
        // collect unique role ids
        Set<Id> roleIds = new Set<Id>(); // set of role ids

        for (User u : users) {
            // add profile id if present
            if (u.ProfileId != null) profileIds.add(u.ProfileId); // collect
            // add role id if present
            if (u.UserRoleId != null) roleIds.add(u.UserRoleId); // collect
        }

        // query profile names once
        if (!profileIds.isEmpty()) {
            for (Profile p : [SELECT Id, Name FROM Profile WHERE Id IN :profileIds]) {
                // store id to name
                profileIdToName.put(p.Id, p.Name); // map
            }
        }

        // query role developer names once
        if (!roleIds.isEmpty()) {
            for (UserRole r : [SELECT Id, DeveloperName FROM UserRole WHERE Id IN :roleIds]) {
                // store id to developer name
                roleIdToDeveloperName.put(r.Id, r.DeveloperName); // map
            }
        }
    }
}
