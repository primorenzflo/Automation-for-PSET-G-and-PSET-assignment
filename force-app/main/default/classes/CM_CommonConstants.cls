public without sharing class CM_CommonConstants {
    // Constants for Permission Set Groups
    public static final String PSG_APPROVAL = 'cm_ApprovGrPermSet'; // Approval Group
    public static final String PSG_DOCU = 'cm_DocuGrPermSet'; // Document Group
    public static final String PSG_STANDARD = 'cm_StdGrPermSet'; // Standard Group

    // Constants for Permission Sets
    public static final String PS_STANDARD = 'cm_StandardPermSet'; // Standard Permission Set
    public static final String PS_HQ_STANDARD = 'cm_HQStandardPermSet'; // HQ Standard Permission Set

    // Profile name constants
    public static final String PROFILE_NCINO_EMPLOYEE = 'nCino行員プロファイル'; // Target profile name

    // Role developer name constants
    public static final String ROLE_HQ = 'cm_Headquarters'; // Target role dev name

    // Rule model that defines matching criteria and permission artifacts
    public class AssignmentRule {
        public String constantName; // Name to identify the rule
        public Set<String> officerCodes; // Officer_Codes__c values to match
        public Set<String> cmCategories; // cm_Category__c values to match
        public Set<String> excludedDepartments; // Departments that must NOT match
        public Set<String> includedDepartments; // Departments that must match (optional)
        public String profileName; // Profile name to match
        public String roleDeveloperName; // UserRole.DeveloperName to match
        public Set<String> permissionSetGroupDeveloperNames; // PSG developer names to assign
        public Set<String> permissionSetDeveloperNames; // PS developer names to assign

        public AssignmentRule(
            String constantName,
            Set<String> officerCodes,
            Set<String> cmCategories,
            Set<String> excludedDepartments,
            Set<String> includedDepartments,
            String profileName,
            String roleDeveloperName,
            Set<String> psgDeveloperNames,
            Set<String> psDeveloperNames
        ) {
            this.constantName = constantName;
            this.officerCodes = officerCodes == null ? new Set<String>() : new Set<String>(officerCodes);
            this.cmCategories = cmCategories == null ? new Set<String>() : new Set<String>(cmCategories);
            this.excludedDepartments = excludedDepartments == null ? new Set<String>() : new Set<String>(excludedDepartments);
            this.includedDepartments = includedDepartments == null ? new Set<String>() : new Set<String>(includedDepartments);
            this.profileName = profileName;
            this.roleDeveloperName = roleDeveloperName;
            this.permissionSetGroupDeveloperNames = psgDeveloperNames == null ? new Set<String>() : new Set<String>(psgDeveloperNames);
            this.permissionSetDeveloperNames = psDeveloperNames == null ? new Set<String>() : new Set<String>(psDeveloperNames);
        }

        public Boolean matches(User u) {
            // Check Officer Codes
            if (!officerCodes.isEmpty()) {
                if (String.isBlank(u.Officer_Codes__c) || !officerCodes.contains(u.Officer_Codes__c)) {
                    return false; // Not matched
                }
            }

            // Check Category
            if (!cmCategories.isEmpty()) {
                if (String.isBlank(u.cm_Category__c) || !cmCategories.contains(String.valueOf(u.cm_Category__c))) {
                    return false; // Not matched
                }
            }

            // Department included check (OR set)
            if (!includedDepartments.isEmpty()) {
                if (String.isBlank(u.Department)) {
                    return false; // Not matched
                }
                if (!includedDepartments.contains(u.Department)) {
                    return false; // Not matched
                }
            }

            // Department excluded check (NOT EQUAL/OR set)
            if (!excludedDepartments.isEmpty()) {
                if (!String.isBlank(u.Department) && excludedDepartments.contains(u.Department)) {
                    return false; // Not matched
                }
            }

            // Profile name check
            if (!String.isBlank(profileName)) {
                if (u.ProfileId == null) {
                    return false; // Not matched
                }
                if (!CM_UserDAO.profileIdToName.containsKey(u.ProfileId)) {
                    return false; // Not matched
                }
                if (CM_UserDAO.profileIdToName.get(u.ProfileId) != profileName) {
                    return false; // Not matched
                }
            }

            // Role developer name check
            if (!String.isBlank(roleDeveloperName)) {
                if (u.UserRoleId == null) {
                    return false; // Not matched
                }
                if (!CM_UserDAO.roleIdToDeveloperName.containsKey(u.UserRoleId)) {
                    return false; // Not matched
                }
                if (CM_UserDAO.roleIdToDeveloperName.get(u.UserRoleId) != roleDeveloperName) {
                    return false; // Not matched
                }
            }

            return true; // All checks passed
        }
    }

    public static List<AssignmentRule> getRules() {
        List<AssignmentRule> rules = new List<AssignmentRule>();

        // Rule 1: Head Office (Non-Screening) – Editing Permissions Granted
        rules.add(new AssignmentRule(
            'Head Office (Non-Screening) – Editing Permissions Granted',
            new Set<String>{'本部'}, // Officer_Codes__c must be 本部
            new Set<String>{'Standard'}, // cm_Category__c must be Standard
            new Set<String>{'審査一部', '審査二部'}, // Departments excluded
            null, // No included departments
            PROFILE_NCINO_EMPLOYEE, // Profile name equals
            ROLE_HQ, // Role developer name equals
            new Set<String>{PSG_APPROVAL, PSG_DOCU, PSG_STANDARD}, // PSGs to assign
            new Set<String>{PS_STANDARD, PS_HQ_STANDARD} // PSs to assign
        ));

        // Add more rules here by copying the snippet above

        return rules;
    }
}
