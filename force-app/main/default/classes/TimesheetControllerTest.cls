@isTest
private class TimesheetControllerTest {

    @testSetup
    static void setup() {

        Account testAccount = new Account(
            Name = 'Test Account for Contract'
        );
        insert testAccount;

        // 1. Create a Standard User to test RLS (Row Level Security)
        Profile p = [SELECT Id FROM Profile WHERE Name='Subcontractor User' LIMIT 1];
        User u = new User(
            Alias = 'standt', Email='standarduser@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='standarduser' + DateTime.now().getTime() + '@testorg.com'
        );
        insert u;

        // 2. Create Parent Records (Project & Contract)
        // Adjust these if you have required fields on Project__c or Contract
        Project__c proj = new Project__c(Name = 'Test Project');
        insert proj;

        Contract contr = new Contract(
            AccountId = testAccount.id, // Or create an Account if required
            StartDate = Date.today(), 
            ContractTerm = 12
        );
        // If Account is required on Contract in your org, create one first!
        // Account acc = new Account(Name='Test Acc'); insert acc; contr.AccountId = acc.Id;
        insert contr;

        // 3. Create Timesheets for Admin (Current User)
        Timesheet__c tsAdmin = new Timesheet__c(
            Date__c = Date.today(),
            Billable_Hours__c = 4,
            Project__c = proj.Id,
            Contract__c = contr.Id,
            Submitted_For__c = UserInfo.getUserId()
        );
        insert tsAdmin;

        // 4. Create Timesheets for Standard User
        System.runAs(u) {
            Timesheet__c tsUser = new Timesheet__c(
                Date__c = Date.today(),
                Billable_Hours__c = 8,
                Project__c = proj.Id,
                Submitted_For__c = u.Id
            );
            insert tsUser;
        }
    }

    @isTest
    static void testGetTimesheets_AsAdmin_NoContext() {
        Date startDt = Date.today().addDays(-1);
        Date endDt = Date.today().addDays(1);

        Test.startTest();
        // Admin should see ALL records (Admin's + Standard User's)
        List<Timesheet__c> results = TimesheetController.getTimesheetsInRange(startDt, endDt, null, null);
        Test.stopTest();

        // Expecting 2 records (1 Admin + 1 Standard User)
        System.assertEquals(2, results.size(), 'Admin should see all timesheets');
    }

    @isTest
    static void testGetTimesheets_AsStandardUser_NoContext() {
        User u = [SELECT Id FROM User WHERE LastName='Testing' LIMIT 1];
        Date startDt = Date.today().addDays(-1);
        Date endDt = Date.today().addDays(1);

        System.runAs(u) {
            Test.startTest();
            // Standard User should ONLY see their own record
            List<Timesheet__c> results = TimesheetController.getTimesheetsInRange(startDt, endDt, null, null);
            Test.stopTest();

            System.assertEquals(1, results.size(), 'Standard user should only see their own timesheet');
            System.assertEquals(u.Id, results[0].OwnerId, 'Owner should match standard user');
        }
    }

    @isTest
    static void testGetTimesheets_ProjectContext() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Date startDt = Date.today().addDays(-1);
        Date endDt = Date.today().addDays(1);

        Test.startTest();
        // Filter by Project Context
        List<Timesheet__c> results = TimesheetController.getTimesheetsInRange(startDt, endDt, proj.Id, 'Project__c');
        Test.stopTest();

        System.assert(results.size() > 0, 'Should return project timesheets');
        for(Timesheet__c ts : results) {
            System.assertEquals(proj.Id, ts.Project__c, 'Should match project ID');
        }
    }

/*     @isTest
static void testGetTimesheets_ContractContext() {
    // Arrange: Retrieve the Contract we created in @testSetup
    Contract contr = [SELECT Id FROM Contract LIMIT 1];
    Date startDt = Date.today().addDays(-1);
    Date endDt = Date.today().addDays(1);
    
    Test.startTest();
    
    // Act: Pass the Contract Id to the controller
    // Assuming your method signature is something like: getTimesheets(Id recordId)
    List<Timesheet__c> results = TimesheetController.getTimesheetsInRange(startDt, endDt, contr.Id, 'Contract');
    
    Test.stopTest();
    
    // Assert: Verify the controller found the related record
    System.assertEquals(1, results.size(), 'Should return exactly one contract timesheet');
    
    // Pro-tip: Always assert the actual data, not just the list size
    System.assertEquals(contr.Id, results[0].Contract__c, 'The timesheet should be linked to our test contract');
} */

}