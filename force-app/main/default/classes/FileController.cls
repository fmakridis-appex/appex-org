public with sharing class FileController {
    @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getSharedFiles() {
        Id userId = UserInfo.getUserId();
        List<FileWrapper> fileList = new List<FileWrapper>();

        // Query files linked to the user (Direct shares)
        // We exclude files owned by the user to mimic "Shared with Me"
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title, 
                   ContentDocument.FileExtension, ContentDocument.CreatedDate,
                   ContentDocument.Owner.Name, ShareType, Visibility
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :userId
            AND ContentDocument.OwnerId != :userId
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 50
        ];

        for (ContentDocumentLink link : links) {
            FileWrapper fw = new FileWrapper();
            fw.id = link.ContentDocumentId;
            fw.title = link.ContentDocument.Title;
            fw.extension = link.ContentDocument.FileExtension;
            fw.ownerName = link.ContentDocument.Owner.Name;
            fw.sharedDate = link.ContentDocument.CreatedDate; // or SystemModstamp
            fileList.add(fw);
        }
        return fileList;
    }

    public class FileWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String extension;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Datetime sharedDate;
    }
}