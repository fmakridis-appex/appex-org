trigger SubcontractorPartnerTrigger on Subcontractor_Partner__c (after insert, after delete) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            SubcontractorPartnerHandler.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isDelete) {
            SubcontractorPartnerHandler.handleAfterDelete(Trigger.old);
        }
    }
}