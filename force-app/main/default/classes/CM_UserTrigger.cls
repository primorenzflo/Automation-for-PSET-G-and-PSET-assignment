public without sharing class CM_UserTrigger {
    // handle after insert event for users
    public static void handleAfterInsert(List<User> newUsers) {
        // call main logic in DAO
        CM_UserDAO.applyAssignments(newUsers); // delegate work
    }

    // handle after update event for users
    public static void handleAfterUpdate(List<User> newUsers, Map<Id, User> oldMap) {
        // call same main logic in DAO
        CM_UserDAO.applyAssignments(newUsers); // delegate work
    }
}
