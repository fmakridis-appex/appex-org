@isTest
private class FileControllerTest {

    // ─── Helper: create a ContentVersion and return its ContentDocumentId ───
    private static Id insertFileAndGetDocId(String title, String ext) {
        ContentVersion cv = new ContentVersion(
            Title         = title,
            PathOnClient  = title + '.' + ext,
            VersionData   = Blob.valueOf('Test content for ' + title),
            Origin        = 'H'
        );
        insert cv;
        // Must re-query — ContentDocumentId is null on the inserted sObject
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    // ─── Scenario 1: User has files shared with them ─────────────────────────
    @isTest
    static void testGetSharedFiles_returnsTwoFiles() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // The "receiver" user
        User receiver = new User(
            Alias            = 'rcvr',
            Email            = 'receiver@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName         = 'Receiver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey     = 'en_US',
            ProfileId        = p.Id,
            TimeZoneSidKey   = 'America/Los_Angeles',
            UserName         = 'receiver@testorg.com.unitTest'
        );
        insert receiver;

        // The "sharer" user (different owner)
        User sharer = new User(
            Alias            = 'shar',
            Email            = 'sharer@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName         = 'Sharer',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey     = 'en_US',
            ProfileId        = p.Id,
            TimeZoneSidKey   = 'America/Los_Angeles',
            UserName         = 'sharer@testorg.com.unitTest'
        );
        insert sharer;

        // Create files as the sharer and share them with the receiver
        System.runAs(sharer) {
            Id docId1 = insertFileAndGetDocId('Shared File 1', 'txt');
            Id docId2 = insertFileAndGetDocId('Shared File 2', 'pdf');

            insert new List<ContentDocumentLink>{
                new ContentDocumentLink(
                    ContentDocumentId = docId1,
                    LinkedEntityId    = receiver.Id,
                    ShareType         = 'V'
                ),
                new ContentDocumentLink(
                    ContentDocumentId = docId2,
                    LinkedEntityId    = receiver.Id,
                    ShareType         = 'C'
                )
            };
        }

        // Run the method as the receiver
        System.runAs(receiver) {
            Test.startTest();
            List<FileController.FileWrapper> results = FileController.getSharedFiles();
            Test.stopTest();

            System.assertEquals(2, results.size(), 'Should return exactly 2 shared files');

            // Collect titles for flexible assertion (order not guaranteed)
            Set<String> titles = new Set<String>();
            for (FileController.FileWrapper fw : results) {
                titles.add(fw.title);
                System.assertNotEquals(null, fw.id,         'Id should not be null');
                System.assertNotEquals(null, fw.extension,  'Extension should not be null');
                System.assertNotEquals(null, fw.ownerName,  'Owner should not be null');
                System.assertNotEquals(null, fw.sharedDate, 'SharedDate should not be null');
            }

            System.assert(titles.contains('Shared File 1'), 'Results should contain Shared File 1');
            System.assert(titles.contains('Shared File 2'), 'Results should contain Shared File 2');
        }
    }

        // ─── Scenario 2: User owns files — they must NOT appear in results ────────
        @isTest
        static void testGetSharedFiles_ownFilesExcluded() {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    
            User owner = new User(
                Alias            = 'ownr',
                Email            = 'owner@testorg.com',
                EmailEncodingKey = 'UTF-8',
                LastName         = 'Owner',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey     = 'en_US',
                ProfileId        = p.Id,
                TimeZoneSidKey   = 'America/Los_Angeles',
                UserName         = 'owner@testorg.com.unitTest'
            );
            insert owner;
    
            System.runAs(owner) {
                // 1. Insert file. Salesforce AUTOMATICALLY creates a ContentDocumentLink 
                // linking this file to the 'owner' user. 
                Id ownDocId = insertFileAndGetDocId('My Own File', 'txt');
    
                // Do NOT manually insert a ContentDocumentLink for the owner here!
                // Doing so causes the "Invalid sharing type V" or "INSUFFICIENT_ACCESS" error.
    
                Test.startTest();
                // 2. Call the controller. It should find the auto-created link, 
                // but filter it out because ContentDocument.OwnerId == userId
                List<FileController.FileWrapper> results = FileController.getSharedFiles();
                Test.stopTest();
    
                // 3. Verify the file is excluded from the "Shared with Me" list
                System.assertEquals(0, results.size(), 'Self-owned files must be excluded from results');
            }
        }
    

    // ─── Scenario 3: User has no files at all ────────────────────────────────
    @isTest
    static void testGetSharedFiles_noFilesReturnsEmpty() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User emptyUser = new User(
            Alias            = 'empty',
            Email            = 'empty@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName         = 'Empty',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey     = 'en_US',
            ProfileId        = p.Id,
            TimeZoneSidKey   = 'America/Los_Angeles',
            UserName         = 'empty@testorg.com.unitTest'
        );
        insert emptyUser;

        System.runAs(emptyUser) {
            Test.startTest();
            List<FileController.FileWrapper> results = FileController.getSharedFiles();
            Test.stopTest();

            System.assertEquals(0, results.size(), 'User with no shared files should get empty list');
        }
    }
}