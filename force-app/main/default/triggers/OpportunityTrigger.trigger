trigger OpportunityTrigger on Opportunity (before insert) {
    for(Opportunity opp : Trigger.new) {

        //if(opp.Product_Interest__c != null && opp.AccountId != null) {
        //    String accountName = opp.Company_Name__c;
       //     String services = opp.Product_Interest__c; 
        //    opp.Name = accountName + ' - ' + services;
        //}
    }
}