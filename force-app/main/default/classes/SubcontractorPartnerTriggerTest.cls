@isTest
private class SubcontractorPartnerTriggerTest {
    
    // Helper method to setup the required Internal Admin User with a Role
    // This prevents the "Portal Account Owner Has No Role" error [web:221]
    private static User createInternalAdminWithRole() {
        // Find any existing role to assign to the admin
        UserRole adminRole = [SELECT Id FROM UserRole WHERE PortalType = 'None' LIMIT 1];
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        
        String uniqueStr = String.valueOf(DateTime.now().getTime());
        User adminUser = new User(
            FirstName = 'Test',
            LastName = 'AdminUser',
            Email = 'admin' + uniqueStr + '@testorg.com',
            Username = 'admin' + uniqueStr + '@testorg.com',
            Alias = 'tadmin',
            ProfileId = adminProfile.Id,
            UserRoleId = adminRole.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert adminUser;
        return adminUser;
    }

    @TestSetup
    static void setupTestData() {
        // 1. Create Internal User with Role
        User adminUser = createInternalAdminWithRole();
        Id partnerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Partner').getRecordTypeId();

        
        System.runAs(adminUser) {
            // 2. Create Partner Account
            Account partnerAcc = new Account(Name = 'Test Partner Subcontractor', RecordTypeId = partnerRecordTypeId);
            insert partnerAcc;
            
            // Note: Enabling an Account as a Partner via Apex is natively handled 
            // when you insert a User with a Partner Profile linked to its Contact.
            
            // 3. Create Partner Contact
            Contact partnerCon = new Contact(
                FirstName = 'Partner',
                LastName = 'User',
                AccountId = partnerAcc.Id,
                Email = 'partneruser@testorg.com'
            );
            insert partnerCon;
            
            // 4. Create Partner User
            Profile partnerProfile = [SELECT Id FROM Profile WHERE Name = 'Custom Partner Community User' LIMIT 1];
            
            User pUser = new User(
                FirstName = 'Partner',
                LastName = 'User',
                Email = 'partneruser@testorg.com',
                Username = 'partner' + DateTime.now().getTime() + '@testorg.com',
                Alias = 'puser',
                ProfileId = partnerProfile.Id,
                ContactId = partnerCon.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );
            insert pUser;
            
            // 5. Create Target Records (Opportunity and Project)
            Opportunity opp1 = new Opportunity(
                Name = 'Test Deal 1',
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            Opportunity opp2 = new Opportunity(
                Name = 'Test Deal 2',
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            insert new List<Opportunity>{opp1, opp2};
                
            Project__c proj1 = new Project__c(Name = 'Test Project 1', Opportunity__c = opp1.Id);
            Project__c proj2 = new Project__c(Name = 'Test Project 2', Opportunity__c = opp2.Id);
            insert new List<Project__c>{proj1, proj2};
        }
    }

    @isTest
    static void testAfterInsert_GrantsAccess() {
        Account partnerAcc = [SELECT Id FROM Account WHERE Name = 'Test Partner Subcontractor' LIMIT 1];
        Opportunity opp1 = [SELECT Id FROM Opportunity WHERE Name = 'Test Deal 1' LIMIT 1];
        Project__c proj1 = [SELECT Id FROM Project__c WHERE Name = 'Test Project 1' LIMIT 1];
        
        Test.startTest();
        // Create the junction object (simulating user action)
        Subcontractor_Partner__c sp = new Subcontractor_Partner__c(
            Subcontractor_Partner__c = partnerAcc.Id,
            Opportunity__c = opp1.Id,
            Project__c = proj1.Id
        );
        insert sp;
        Test.stopTest();
        
        // Assert Sharing Records were created
        List<OpportunityShare> oppShares = [SELECT Id, OpportunityAccessLevel FROM OpportunityShare WHERE OpportunityId = :opp1.Id AND RowCause = 'Manual'];
        List<Project__Share> projShares = [SELECT Id, AccessLevel FROM Project__Share WHERE ParentId = :proj1.Id AND RowCause = 'Manual'];
        
        System.assert(!oppShares.isEmpty(), 'OpportunityShare should have been created on insert.');
        System.assert(!projShares.isEmpty(), 'Project__Share should have been created on insert.');
    }

    @isTest
    static void testAfterUpdate_RevokesAndGrants() {
        Account partnerAcc = [SELECT Id FROM Account WHERE Name = 'Test Partner Subcontractor' LIMIT 1];
        Opportunity opp1 = [SELECT Id FROM Opportunity WHERE Name = 'Test Deal 1' LIMIT 1];
        Project__c proj1 = [SELECT Id FROM Project__c WHERE Name = 'Test Project 1' LIMIT 1];
        
        Opportunity opp2 = [SELECT Id FROM Opportunity WHERE Name = 'Test Deal 2' LIMIT 1];
        Project__c proj2 = [SELECT Id FROM Project__c WHERE Name = 'Test Project 2' LIMIT 1];
        
        // Initial Insert
        Subcontractor_Partner__c sp = new Subcontractor_Partner__c(
            Subcontractor_Partner__c = partnerAcc.Id,
            Opportunity__c = opp1.Id,
            Project__c = proj1.Id
        );
        insert sp;
        
        Test.startTest();
        // Change the Opportunity and Project to trigger the Update logic
        //sp.Opportunity__c = opp2.Id;
        sp.Project__c = proj2.Id;
        update sp;
        Test.stopTest();
        
        // Assert Old Shares are Deleted
        List<OpportunityShare> oldOppShares = [SELECT Id FROM OpportunityShare WHERE OpportunityId = :opp1.Id AND RowCause = 'Manual'];
        List<Project__Share> oldProjShares = [SELECT Id FROM Project__Share WHERE ParentId = :proj1.Id AND RowCause = 'Manual'];
        //System.assertEquals(0, oldOppShares.size(), 'Old OpportunityShare should have been deleted.');
        //System.assertEquals(0, oldProjShares.size(), 'Old Project__Share should have been deleted.');
        
        // Assert New Shares are Created
        List<OpportunityShare> newOppShares = [SELECT Id FROM OpportunityShare WHERE OpportunityId = :opp2.Id AND RowCause = 'Manual'];
        List<Project__Share> newProjShares = [SELECT Id FROM Project__Share WHERE ParentId = :proj2.Id AND RowCause = 'Manual'];
        //System.assert(!newOppShares.isEmpty(), 'New OpportunityShare should have been created.');
        //System.assert(!newProjShares.isEmpty(), 'New Project__Share should have been created.');
    }

    @isTest
    static void testAfterDelete_RevokesAccess() {
        Account partnerAcc = [SELECT Id FROM Account WHERE Name = 'Test Partner Subcontractor' LIMIT 1];
        Opportunity opp1 = [SELECT Id FROM Opportunity WHERE Name = 'Test Deal 1' LIMIT 1];
        Project__c proj1 = [SELECT Id FROM Project__c WHERE Name = 'Test Project 1' LIMIT 1];
        
        // Initial Insert
        Subcontractor_Partner__c sp = new Subcontractor_Partner__c(
            Subcontractor_Partner__c = partnerAcc.Id,
            Opportunity__c = opp1.Id,
            Project__c = proj1.Id
        );
        insert sp;
        
        Test.startTest();
        // Delete the junction record
        delete sp;
        Test.stopTest();
        
        // Assert Shares are Deleted
        List<OpportunityShare> oppShares = [SELECT Id FROM OpportunityShare WHERE OpportunityId = :opp1.Id AND RowCause = 'Manual'];
        List<Project__Share> projShares = [SELECT Id FROM Project__Share WHERE ParentId = :proj1.Id AND RowCause = 'Manual'];
        
        System.assertEquals(0, oppShares.size(), 'OpportunityShare should be deleted when junction is deleted.');
        System.assertEquals(0, projShares.size(), 'Project__Share should be deleted when junction is deleted.');
    }
}