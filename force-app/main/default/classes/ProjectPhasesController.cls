public with sharing class ProjectPhasesController {

    @AuraEnabled(cacheable=true)
    public static List<ProjectPhaseWrapper> getProjectPhases(Id parentId) {
        List<ProjectPhaseWrapper> treeData = new List<ProjectPhaseWrapper>();
        if (parentId == null) return treeData;

        Schema.SObjectType parentType = parentId.getSObjectType();

        String whereClause;
        if (parentType == Opportunity.SObjectType) {
            whereClause = 'Opportunity__c = :parentId';
        } else if (parentType.getDescribe().getName() == 'Project__c') {
            whereClause = 'Project__c = :parentId';
        } else {
            return treeData;
        }

        // 1. Ensure Billable__c is in the query
        List<Project_Phase__c> allPhases = Database.query(
            'SELECT Id, Name__c, Description__c, Phase_Number__c, Hours__c,' +
            ' CR_1_Hours__c, CR_2_Hours__c, Billable__c,' + 
            ' Parent_Phase__c, Is_Phase__c, Opportunity__c, Project__c' +
            ' FROM Project_Phase__c' +
            ' WHERE ' + whereClause +
            ' ORDER BY Phase_Number__c NULLS LAST, Name__c'
        );

        Map<Id, ProjectPhaseWrapper> phaseMap = new Map<Id, ProjectPhaseWrapper>();
        for (Project_Phase__c phase : allPhases) {
            phaseMap.put(phase.Id, new ProjectPhaseWrapper(phase));
        }

        for (ProjectPhaseWrapper wrapper : phaseMap.values()) {
            if (wrapper.data.Parent_Phase__c == null) {
                treeData.add(wrapper);
            } else {
                ProjectPhaseWrapper parent = phaseMap.get(wrapper.data.Parent_Phase__c);
                if (parent != null) parent.children.add(wrapper);
            }
        }

        return treeData;
    }

    @AuraEnabled
    public static void saveProjectPhases(List<ProjectPhaseDto> phasesToSave, List<Id> phasesToDelete, Id parentId) {
        try {
            System.debug('phasesToSave: ' + phasesToSave);
            System.debug('First Item Billable: ' + phasesToSave[0].billable);
            
            // Debug the first item to see if billable is coming through
            if (phasesToSave != null && !phasesToSave.isEmpty()) {
                System.debug('First Item Billable: ' + phasesToSave[0].billable);
            }

            if (parentId == null) return;

            Schema.SObjectType parentType = parentId.getSObjectType();
            Boolean isOpp = (parentType == Opportunity.SObjectType);
            Boolean isProject = (parentType.getDescribe().getName() == 'Project__c');
            if (!isOpp && !isProject) return;

            if (phasesToDelete != null && !phasesToDelete.isEmpty()) {
                delete [SELECT Id FROM Project_Phase__c WHERE Id IN :phasesToDelete];
            }

            if (phasesToSave == null || phasesToSave.isEmpty()) return;

            List<Project_Phase__c> parentsToUpsert = new List<Project_Phase__c>();
            List<ProjectPhaseDto> childDtos = new List<ProjectPhaseDto>();
            Map<String, Project_Phase__c> tempIdToRecord = new Map<String, Project_Phase__c>();

            // Parents
            for (ProjectPhaseDto dto : phasesToSave) {
                if (String.isBlank(dto.parentId)) {
                    Project_Phase__c p = new Project_Phase__c(
                        Id = (String.isNotBlank(dto.id) && !dto.id.startsWith('new_')) ? dto.id : null,
                        Name__c = dto.name,
                        Description__c = dto.description,
                        Phase_Number__c = dto.phaseNumber,
                        Hours__c = dto.hours,
                        CR_1_Hours__c = dto.cr1Hours,
                        CR_2_Hours__c = dto.cr2Hours,
                        Billable__c = dto.billable, // Map Billable
                        Is_Phase__c = true
                    );
                    if (isOpp) p.Opportunity__c = parentId;
                    if (isProject) p.Project__c = parentId;

                    parentsToUpsert.add(p);
                    if (dto.id != null && dto.id.startsWith('new_')) tempIdToRecord.put(dto.id, p);
                } else {
                    childDtos.add(dto);
                }
            }

            if (!parentsToUpsert.isEmpty()) upsert parentsToUpsert;

            // Children
            List<Project_Phase__c> childrenToUpsert = new List<Project_Phase__c>();
            for (ProjectPhaseDto dto : childDtos) {
                Id realParentId = null;

                if (dto.parentId != null && dto.parentId.startsWith('new_')) {
                    if (tempIdToRecord.containsKey(dto.parentId)) {
                        realParentId = tempIdToRecord.get(dto.parentId).Id;
                    }
                } else {
                    realParentId = (Id)dto.parentId;
                }

                Project_Phase__c c = new Project_Phase__c(
                    Id = (String.isNotBlank(dto.id) && !dto.id.startsWith('new_')) ? dto.id : null,
                    Name__c = dto.name,
                    Description__c = dto.description,
                    Phase_Number__c = dto.phaseNumber,
                    Hours__c = dto.hours,
                    CR_1_Hours__c = dto.cr1Hours,
                    CR_2_Hours__c = dto.cr2Hours,
                    Billable__c = dto.billable, // Map Billable
                    Is_Phase__c = false,
                    Parent_Phase__c = realParentId
                );
                if (isOpp) c.Opportunity__c = parentId;
                if (isProject) c.Project__c = parentId;

                childrenToUpsert.add(c);
            }

            if (!childrenToUpsert.isEmpty()) upsert childrenToUpsert;

        } catch (Exception e) {
            // Add setMessage so the real DML error prints in your test execution logs
            AuraHandledException ex = new AuraHandledException('Save Error: ' + e.getMessage());
            ex.setMessage(e.getMessage()); 
            throw ex;
        }
    }

    public class ProjectPhaseWrapper {
        @AuraEnabled public Project_Phase__c data;
        @AuraEnabled public List<ProjectPhaseWrapper> children;
        public ProjectPhaseWrapper(Project_Phase__c phase) {
            data = phase;
            children = new List<ProjectPhaseWrapper>();
        }
    }

    // 2. Ensure DTO has the field
    public class ProjectPhaseDto {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String phaseNumber { get; set; }
        @AuraEnabled public Decimal hours { get; set; }
        @AuraEnabled public String parentId { get; set; }
        @AuraEnabled public Boolean isPhase { get; set; }
        @AuraEnabled public Decimal cr1Hours { get; set; }
        @AuraEnabled public Decimal cr2Hours { get; set; }
        @AuraEnabled public Boolean billable { get; set; } // Must be present
    }
}