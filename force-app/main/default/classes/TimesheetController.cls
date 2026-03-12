public with sharing class TimesheetController {
    @AuraEnabled(cacheable=true)
    public static List<Timesheet__c> getTimesheetsInRange(
        Date startDate,
        Date endDate,
        String contextRecordId,
        String contextObjectApiName
    ) {
        Id currentUserId = UserInfo.getUserId();

        Boolean isSystemAdmin =
            [SELECT Profile.Name FROM User WHERE Id = :currentUserId]
            .Profile.Name == 'System Administrator';

        String q =
            'SELECT Id, Name, Date__c, Billable_Hours__c, Description__c, ' +
            'Project__c, Project__r.Name, ' +
            'Contract__c, Contract__r.ContractNumber, ' +
            'Submitted_For__c, Amount_Based_On_Contract_Price__c, Owner.Name ' +
            'FROM Timesheet__c ' +
            'WHERE Date__c >= :startDate AND Date__c <= :endDate ';

        // Owner filter (non-admins see only their own)
        if (!isSystemAdmin) {
            q += 'AND OwnerId = :currentUserId ';
        }

        // Context filter (Project or standard Contract)
        if (String.isNotBlank(contextRecordId) && String.isNotBlank(contextObjectApiName)) {
            if (contextObjectApiName == 'Project__c') {
                q += 'AND Project__c = :contextRecordId ';
            } else if (contextObjectApiName == 'Contract') {
                q += 'AND Contract__c = :contextRecordId ';
            }
        }

        q += 'WITH USER_MODE ORDER BY Date__c ASC, CreatedDate ASC';
        return Database.query(q);
    }
}