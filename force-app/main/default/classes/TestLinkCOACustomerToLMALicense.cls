@isTest
public class TestLinkCOACustomerToLMALicense {
	@testSetup
    static void setup() {
        // Create test data for licenses
        List<sfLma__License__c> licenses = new List<sfLma__License__c>();
        for (Integer i = 0; i < 5; i++) {
            sfLma__License__c license = new sfLma__License__c();
                license.sfLma__Subscriber_Org_ID__c = '00D' + i + '00000000001';
            	license.sfLma__Seats__c = 4;
            licenses.add(license);
        }
        insert licenses;
    }
	
    @isTest
    static void testTriggerAfterInsert() {
        // Create test customer records
        List<CHANNEL_ORDERS__Customer__c> customers = new List<CHANNEL_ORDERS__Customer__c>();
        for (Integer i = 0; i < 5; i++) {
            CHANNEL_ORDERS__Customer__c customer = new CHANNEL_ORDERS__Customer__c();
             customer.CHANNEL_ORDERS__Customer_Company_Name__c = 'Test Customer'+ i;
             customer.CHANNEL_ORDERS__Customer_Country__c = 'US';
             customer.CHANNEL_ORDERS__Customer_State__c = 'CA';
             customer.CHANNEL_ORDERS__Customer_City__c = 'Marseille';
             customer.CHANNEL_ORDERS__Customer_Street__c = 'MyStreet';
             customer.CHANNEL_ORDERS__Customer_Zip_Postal_Code__c = '13001';
             customer.CHANNEL_ORDERS__Customer_Org_ID__c = '00D' + i + '00000000001';
            customers.add(customer);
        }
        insert customers;

        // Query licenses to verify they are updated
        List<sfLma__License__c> updatedLicenses = [SELECT COA_Customer__c 
                                                   FROM sfLma__License__c 
                                                   WHERE COA_Customer__c != null];
        
        // Assert that the licenses have been correctly updated with customer references
        System.assertEquals(5, updatedLicenses.size(), 'All licenses should be updated');
        for (sfLma__License__c license : updatedLicenses) {
            System.assertNotEquals(null, license.COA_Customer__c, 'License should be linked to a customer');
        }
    }

    @isTest
    static void testTriggerAfterUpdate() {
        // Create a test customer record and insert it
        CHANNEL_ORDERS__Customer__c customer = new CHANNEL_ORDERS__Customer__c();
            customer.CHANNEL_ORDERS__Customer_Company_Name__c = 'Test Customer A';
             customer.CHANNEL_ORDERS__Customer_Country__c = 'US';
             customer.CHANNEL_ORDERS__Customer_State__c = 'CA';
             customer.CHANNEL_ORDERS__Customer_City__c = 'Marseille';
             customer.CHANNEL_ORDERS__Customer_Street__c = 'MyStreet';
             customer.CHANNEL_ORDERS__Customer_Zip_Postal_Code__c = '13001';
             customer.CHANNEL_ORDERS__Customer_Org_ID__c = '00DA00000000001';
        insert customer;

        // Update the customer to trigger the update scenario
        customer.CHANNEL_ORDERS__Customer_Org_ID__c = '00D100000000001';
        update customer;

        // Query licenses to verify they are updated
        List<sfLma__License__c> updatedLicenses = [SELECT Id, COA_Customer__c, sfLma__Subscriber_Org_ID__c 
                                                   FROM sfLma__License__c 
                                                   WHERE sfLma__Subscriber_Org_ID__c = :customer.CHANNEL_ORDERS__Customer_Org_ID__c];
        
        // Assert that the license has been correctly updated with customer references
        System.assertEquals(1, updatedLicenses.size(), 'One license should be updated');
        for (sfLma__License__c license : updatedLicenses) {
            System.assertEquals(customer.Id, license.COA_Customer__c, 'License should be linked to the updated customer');
        }
    }

    @isTest
    static void testTriggerNoMatchingLicense() {
        // Create a customer with an org ID that does not match any licenses
        CHANNEL_ORDERS__Customer__c customer = new CHANNEL_ORDERS__Customer__c();
             customer.CHANNEL_ORDERS__Customer_Company_Name__c = 'Test Customer B';
             customer.CHANNEL_ORDERS__Customer_Country__c = 'US';
             customer.CHANNEL_ORDERS__Customer_State__c = 'CA';
             customer.CHANNEL_ORDERS__Customer_City__c = 'Marseille';
             customer.CHANNEL_ORDERS__Customer_Street__c = 'MyStreet';
             customer.CHANNEL_ORDERS__Customer_Zip_Postal_Code__c = '13001';
             customer.CHANNEL_ORDERS__Customer_Org_ID__c = '00D000000000999';
        insert customer;

        // Ensure no licenses are updated
        List<sfLma__License__c> licenses = [SELECT Id, COA_Customer__c FROM sfLma__License__c WHERE COA_Customer__c != null];
        System.assertEquals(0, licenses.size(), 'No licenses should be updated when there is no matching org ID');
    }
}