trigger CM_UserTrigger on User (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        CM_UserDAO.applyAssignments(Trigger.new);
    }
}
