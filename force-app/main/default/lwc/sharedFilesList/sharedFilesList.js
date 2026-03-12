import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getSharedFiles from '@salesforce/apex/FileController.getSharedFiles';

const COLUMNS = [
    { label: 'Title', fieldName: 'title', type: 'text' },
    { label: 'Type', fieldName: 'extension', type: 'text', initialWidth: 80 },
    { label: 'Owner', fieldName: 'ownerName', type: 'text' },
    { label: 'Date Shared', fieldName: 'sharedDate', type: 'date' },
    {
        type: 'button',
        typeAttributes: {
            label: 'View',
            name: 'view_file',
            variant: 'base'
        }
    }
];

export default class SharedFilesList extends NavigationMixin(LightningElement) {
    columns = COLUMNS;

    @wire(getSharedFiles)
    files;

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'view_file') {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'filePreview'
                },
                state: {
                    recordIds: row.id,
                    selectedRecordId: row.id
                }
            });
        }
    }
}