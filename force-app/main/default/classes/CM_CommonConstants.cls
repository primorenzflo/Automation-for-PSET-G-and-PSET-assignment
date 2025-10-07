public without sharing class CM_CommonConstants {
    // Permission Set Group developer names
    public static final String PSG_APPROVAL = 'cm_ApprovGrPermSet';
    public static final String PSG_DOCU = 'cm_DocuGrPermSet';
    public static final String PSG_STANDARD = 'cm_StdGrPermSet';

    // Permission Set developer names (PermissionSet.Name)
    public static final String PS_STANDARD = 'cm_StandardPermSet';
    public static final String PS_HQ_STANDARD = 'cm_HQStandardPermSet';

    // Profile label to match (Profile.Name)
    public static final String PROFILE_NCINO_EMPLOYEE = 'nCino行員プロファイル';

    // UserRole.DeveloperName to match
    public static final String ROLE_HQ = 'cm_Headquarters';

    // Rule model that defines matching criteria and permission artifacts
    public class AssignmentRule {
        public String constantName; // Rule label for maintainers
        public Set<String> officerCodes; // Match Officer_Codes__c values
        public Set<String> cmCategories; // Match cm_Category__c values
        public Set<String> excludedDepartments; // Department values to EXCLUDE
        public Set<String> includedDepartments; // Department values to INCLUDE (optional)
        public String profileName; // Match Profile.Name
        public String roleDeveloperName; // Match UserRole.DeveloperName
        public Set<String> permissionSetGroupDeveloperNames; // PSG developer names to assign
        public Set<String> permissionSetDeveloperNames; // PermissionSet.Name values to assign

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

        /*
         * TEMPLATE: Copy, paste, and edit to add another combination
         *
         * rules.add(new AssignmentRule(
         *     'YOUR RULE NAME HERE',
         *     new Set<String>{'OfficerCodeA','OfficerCodeB'}, // Officer_Codes__c values (leave empty set if not used)
         *     new Set<String>{'Standard','Another'},         // cm_Category__c values (leave empty set if not used)
         *     new Set<String>{'DeptToExclude1','DeptToExclude2'}, // Department values to EXCLUDE (NOT)
         *     null, // OR use: new Set<String>{'DeptToInclude1','DeptToInclude2'} (Department values to INCLUDE)
         *     'Profile Label Here',          // Profile.Name to match (e.g., nCino行員プロファイル)
         *     'RoleDeveloperNameHere',       // UserRole.DeveloperName to match (e.g., cm_Headquarters)
         *     new Set<String>{'PSG_DevName1','PSG_DevName2'}, // Permission Set Group DeveloperName values
         *     new Set<String>{'PS_DevName1','PS_DevName2'}    // Permission Set Developer Name values (PermissionSet.Name)
         * ));
         */

        return rules;
    }
}
