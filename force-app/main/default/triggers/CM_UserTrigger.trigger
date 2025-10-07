trigger CM_UserTrigger on User (after insert, after update) {
    // After inserting users
    if (Trigger.isAfter && Trigger.isInsert) {
        // Apply assignments for new users
        CM_UserDAO.applyAssignments(Trigger.new);
    }
    // After updating users
    if (Trigger.isAfter && Trigger.isUpdate) {
        // Apply assignments for updated users
        CM_UserDAO.applyAssignments(Trigger.new);
    }
}
