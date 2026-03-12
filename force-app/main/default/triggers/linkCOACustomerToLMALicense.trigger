trigger linkCOACustomerToLMALicense on CHANNEL_ORDERS__Customer__c (after insert, after update) {
    // map to capture license id + customer id
    map<string,id> allCustomersWithOrgID = new map<string,id>();
    // retrieve all customer org id in the trigger
    string customerOrgId = '';
    for (CHANNEL_ORDERS__Customer__c c : trigger.new)
    {
        customerOrgId=c.CHANNEL_ORDERS__Customer_Org_ID__c;
        allCustomersWithOrgID.put(customerOrgId.left(15), c.id);
    }

    list<sfLma__License__c> licenseToUpdate = new list<sfLma__License__c>();
    // retrieve all licenses
    list<sfLma__License__c> allLicensesWithCustomer = [select id, sfLma__Account__c, COA_Customer__c, sfLma__Subscriber_Org_ID__c 
                                                       from sfLma__License__c 
                                                       where sfLma__Subscriber_Org_ID__c in :allCustomersWithOrgID.keyset()];
    
    for (sfLma__License__c mylicense : allLicensesWithCustomer)
    {
        // assigne the right customer to the right license via orgid
        mylicense.COA_Customer__c = allCustomersWithOrgID.get(mylicense.sfLma__Subscriber_Org_ID__c); 
        licenseToUpdate.add(mylicense);
    }

    update licenseToUpdate;
}