trigger CM_UserAssignmentTrigger on User (after insert, after update) {
    // when new users are created
    if (Trigger.isAfter && Trigger.isInsert) {
        // delegate to handler class
        CM_UserTrigger.handleAfterInsert(Trigger.new); // process
    }
    // when users are updated
    if (Trigger.isAfter && Trigger.isUpdate) {
        // delegate to handler class
        CM_UserTrigger.handleAfterUpdate(Trigger.new, Trigger.oldMap); // process
    }
}
