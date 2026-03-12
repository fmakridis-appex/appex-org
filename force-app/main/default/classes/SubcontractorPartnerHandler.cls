public without sharing class SubcontractorPartnerHandler {
    
    public static void handleAfterInsert(List<Subcontractor_Partner__c> newList) {
        Set<Id> partnerAccountIds = new Set<Id>();
        
        for (Subcontractor_Partner__c sp : newList) {
            if (sp.Subcontractor_Partner__c != null) {
                partnerAccountIds.add(sp.Subcontractor_Partner__c);
            }
        }
        
        if (partnerAccountIds.isEmpty()) return;

        Map<Id, List<Id>> accountToGroupIds = getPartnerGroups(partnerAccountIds);
        
        List<OpportunityShare> oppSharesToInsert = new List<OpportunityShare>();
        List<Project__Share> projSharesToInsert = new List<Project__Share>();
        
        for (Subcontractor_Partner__c sp : newList) {
            if (sp.Subcontractor_Partner__c != null && accountToGroupIds.containsKey(sp.Subcontractor_Partner__c)) {
                for (Id groupId : accountToGroupIds.get(sp.Subcontractor_Partner__c)) {
                    
                    if (sp.Opportunity__c != null) {
                        OpportunityShare oppShare = new OpportunityShare();
                        oppShare.OpportunityId = sp.Opportunity__c;
                        oppShare.UserOrGroupId = groupId;
                        oppShare.OpportunityAccessLevel = 'Read'; 
                        oppShare.RowCause = 'Manual';
                        oppSharesToInsert.add(oppShare);
                    }
                    
                    if (sp.Project__c != null) {
                        Project__Share projShare = new Project__Share();
                        projShare.ParentId = sp.Project__c; 
                        projShare.UserOrGroupId = groupId;
                        projShare.AccessLevel = 'Read';     
                        projShare.RowCause = 'Manual'; 
                        projSharesToInsert.add(projShare);
                    }
                }
            }
        }
        
        if (!oppSharesToInsert.isEmpty()) Database.insert(oppSharesToInsert, false);
        if (!projSharesToInsert.isEmpty()) Database.insert(projSharesToInsert, false);
    }

    public static void handleAfterUpdate(Map<Id, Subcontractor_Partner__c> newMap, Map<Id, Subcontractor_Partner__c> oldMap) {
        List<Subcontractor_Partner__c> recordsToRevoke = new List<Subcontractor_Partner__c>();
        List<Subcontractor_Partner__c> recordsToGrant = new List<Subcontractor_Partner__c>();
        
        for (Subcontractor_Partner__c newSp : newMap.values()) {
            Subcontractor_Partner__c oldSp = oldMap.get(newSp.Id);
            
            Boolean projectChanged = newSp.Project__c != oldSp.Project__c;
            Boolean oppChanged = newSp.Opportunity__c != oldSp.Opportunity__c;
            Boolean accountChanged = newSp.Subcontractor_Partner__c != oldSp.Subcontractor_Partner__c;
            
            if (projectChanged || oppChanged || accountChanged) {
                recordsToRevoke.add(oldSp);
                recordsToGrant.add(newSp);
            }
        }
        
        if (!recordsToRevoke.isEmpty()) {
            handleAfterDelete(recordsToRevoke); 
        }
        
        if (!recordsToGrant.isEmpty()) {
            handleAfterInsert(recordsToGrant);
        }
    }

    public static void handleAfterDelete(List<Subcontractor_Partner__c> oldList) {
        Set<Id> partnerAccountIds = new Set<Id>();
        Set<Id> oppIds = new Set<Id>();
        Set<Id> projIds = new Set<Id>();
        
        for (Subcontractor_Partner__c sp : oldList) {
            if (sp.Subcontractor_Partner__c != null) {
                partnerAccountIds.add(sp.Subcontractor_Partner__c);
                if (sp.Opportunity__c != null) oppIds.add(sp.Opportunity__c);
                if (sp.Project__c != null) projIds.add(sp.Project__c);
            }
        }
        
        if (partnerAccountIds.isEmpty()) return;

        Map<Id, List<Id>> accountToGroupIds = getPartnerGroups(partnerAccountIds);
        Set<Id> allGroupIds = new Set<Id>();
        for (List<Id> groups : accountToGroupIds.values()) {
            allGroupIds.addAll(groups);
        }
        
        if (!oppIds.isEmpty() && !allGroupIds.isEmpty()) {
            List<OpportunityShare> oppSharesToDelete = [
                SELECT Id FROM OpportunityShare 
                WHERE OpportunityId IN :oppIds AND UserOrGroupId IN :allGroupIds AND RowCause = 'Manual'
            ];
            if (!oppSharesToDelete.isEmpty()) Database.delete(oppSharesToDelete, false);
        }
        
        if (!projIds.isEmpty() && !allGroupIds.isEmpty()) {
            List<Project__Share> projSharesToDelete = [
                SELECT Id FROM Project__Share 
                WHERE ParentId IN :projIds AND UserOrGroupId IN :allGroupIds AND RowCause = 'Manual'
            ];
            if (!projSharesToDelete.isEmpty()) Database.delete(projSharesToDelete, false);
        }
    }
    
    // Helper method to retrieve RoleAndSubordinates groups for Partner Accounts AND their Contacts
    private static Map<Id, List<Id>> getPartnerGroups(Set<Id> accountIds) {
        Map<Id, List<Id>> accountToGroups = new Map<Id, List<Id>>();
        Map<Id, Id> roleIdToAccountId = new Map<Id, Id>();
        
        // 1. Standard Portal Roles linked directly to the Partner Accounts
        for (UserRole ur : [SELECT Id, PortalAccountId FROM UserRole WHERE PortalAccountId IN :accountIds]) {
            roleIdToAccountId.put(ur.Id, ur.PortalAccountId);
        }
        
        // 2. Roles of the Users tied to the Contacts under these Accounts
        List<User> partnerUsers = [
            SELECT Id, UserRoleId, Contact.AccountId 
            FROM User 
            WHERE Contact.AccountId IN :accountIds 
            AND IsActive = true 
            AND UserRoleId != null
        ];
        
        for (User u : partnerUsers) {
            roleIdToAccountId.put(u.UserRoleId, u.Contact.AccountId);
        }
        
        if (roleIdToAccountId.isEmpty()) return accountToGroups;
        
        // 3. Retrieve 'RoleAndSubordinates' Groups for ALL Role IDs
        for (Group g : [SELECT Id, RelatedId FROM Group WHERE Type = 'RoleAndSubordinates' AND RelatedId IN :roleIdToAccountId.keySet()]) {
            Id accId = roleIdToAccountId.get(g.RelatedId);
            
            if (!accountToGroups.containsKey(accId)) {
                accountToGroups.put(accId, new List<Id>());
            }
            accountToGroups.get(accId).add(g.Id);
        }
        
        return accountToGroups;
    }
}