import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
// Added deleteRecord here
import { getRecord, getFieldValue, deleteRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import getTimesheetsInRange from '@salesforce/apex/TimesheetController.getTimesheetsInRange';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';

export default class WeeklyTimesheet extends LightningElement {
    // Record page context
    @api recordId;        // Project__c or Contract Id
    @api objectApiName;   // 'Project__c', 'Contract', or undefined (Tab/Community)

    // Timesheet object name for record-edit-form
    timesheetObjectApiName = 'Timesheet__c';

    // Field API names
    fields = {
        date: 'Date__c',
        hours: 'Billable_Hours__c',
        project: 'Project__c',
        contract: 'Contract__c',
        description: 'Description__c',
        submittedFor: 'Submitted_For__c',
        amountContract: 'Amount_Based_On_Contract_Price__c'
    };

    // Contract context: Project__c on the Contract
    @track contractProjectId;

    // View state
    @track viewMode = 'week';        // 'week' | 'month'
    @track calendarDays = [];
    @track currentStartStr;          // YYYY-MM-DD
    @track currentEndStr;            // YYYY-MM-DD

    // Modal state
    isModalOpen = false;
    selectedDate;
    @track selectedRecordId;

    // Data / wire state
    wiredTimesheetResult;
    currentUserProfileName;

    // ---------- NEW GETTERS ----------

    // Populates current User ID for new records, leaves undefined for existing records
    get defaultSubmittedFor() {
        return this.selectedRecordId ? undefined : USER_ID;
    }

    // Only show delete if it's an existing record AND the user is a System Admin
    get showDeleteButton() {
        return this.selectedRecordId && this.currentUserProfileName === 'System Administrator';
    }

    // ---------- Helpers ----------
    toYMDLocal(dateObj) {
        const y = dateObj.getFullYear();
        const m = String(dateObj.getMonth() + 1).padStart(2, '0');
        const d = String(dateObj.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
    }

    // ---------- Context ----------
    get isProjectContext() {
        return this.objectApiName === 'Project__c' && !!this.recordId;
    }

    get isContractContext() {
        return this.objectApiName === 'Contract' && !!this.recordId; // standard Contract
    }

    get isOnRecordPage() {
        return !!this.recordId && !!this.objectApiName;
    }

    get notOnRecordPage() {
        return !this.isOnRecordPage;
    }

    get isWeekView() { return this.viewMode === 'week'; }
    get isMonthView() { return this.viewMode === 'month'; }

    // Wire-safe params (never undefined)
    get contextRecordIdParam() {
        return this.recordId || null;
    }

    get contextObjectApiNameParam() {
        return this.objectApiName || null;
    }

    // Contract wire only when on Contract page
    get contractRecordIdForWire() {
        return this.isContractContext ? this.recordId : null;
    }

    // ---------- User profile (optional) ----------
    @wire(getRecord, { recordId: USER_ID, fields: [PROFILE_NAME_FIELD] })
    wiredUser({ data }) {
        if (data) {
            this.currentUserProfileName =
                data.fields?.Profile?.displayValue || data.fields?.Profile?.value;
        }
    }

    // ---------- Contract.Project__c ----------
    @wire(getRecord, { recordId: '$contractRecordIdForWire', fields: ['Contract.Project__c'] })
    wiredContract({ data, error }) {
        if (data) {
            this.contractProjectId = getFieldValue(data, 'Contract.Project__c');
        } else if (error) {
            this.contractProjectId = null;
        }
    }

    // ---------- Timesheets ----------
    @wire(getTimesheetsInRange, {
        startDate: '$currentStartStr',
        endDate: '$currentEndStr',
        contextRecordId: '$contextRecordIdParam',
        contextObjectApiName: '$contextObjectApiNameParam'
    })
    wiredTimesheets(result) {
        this.wiredTimesheetResult = result;
        
        console.log('Wire Result:', result);
        
        if (result?.data) {
            this.mapDataToDays(result.data);
        } else if (result?.error) {
            console.error('CRITICAL APEX ERROR:', result.error); 
        }
    }

    // ---------- Labels ----------
    get weekViewVariant() {
        return this.viewMode === 'week' ? 'brand' : 'neutral';
    }

    get monthViewVariant() {
        return this.viewMode === 'month' ? 'brand' : 'neutral';
    }

    get modalTitle() {
        return this.selectedRecordId ? 'Edit Timesheet' : `Log Time: ${this.selectedDate}`;
    }

    get currentPeriodLabel() {
        if (!this.currentStartStr) return '';
        // Changed 'el-GR' to 'en-US'
        const formatter = new Intl.DateTimeFormat('en-US', {
            day: '2-digit', month: '2-digit', year: 'numeric'
        });
        const start = new Date(this.currentStartStr + 'T00:00:00');

        if (this.viewMode === 'week') {
            const end = new Date(start);
            end.setDate(end.getDate() + 6);
            return `${formatter.format(start)} - ${formatter.format(end)}`;
        }

        const mid = new Date(start);
        mid.setDate(mid.getDate() + 15);
        return new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(mid);
    }


    // ---------- Lifecycle ----------
    connectedCallback() {
        this.setCalendarDate(new Date());
    }

    // ---------- View / Calendar ----------
    handleViewChange(event) {
        this.viewMode = event.target.value;
        this.setCalendarDate(new Date());
    }

    setCalendarDate(targetDate) {
        const date = new Date(targetDate);
        let startDate;
        let numDays;

        if (this.viewMode === 'week') {
            const day = date.getDay(); // 0=Sun
            const diff = date.getDate() - day + (day === 0 ? -6 : 1);
            startDate = new Date(date.setDate(diff));
            numDays = 7;
        } else {
            const firstOfMonth = new Date(date.getFullYear(), date.getMonth(), 1);
            const day = firstOfMonth.getDay();
            const diff = firstOfMonth.getDate() - day + (day === 0 ? -6 : 1);
            startDate = new Date(firstOfMonth.setDate(diff));
            numDays = 42; // 6 weeks
        }

        this.generateGrid(startDate, numDays);
    }

    generateGrid(startDate, numDays) {
        const todayStr = this.toYMDLocal(new Date());
        const days = [];

        const endDate = new Date(startDate);
        endDate.setDate(startDate.getDate() + (numDays - 1));

        this.currentStartStr = this.toYMDLocal(startDate);
        this.currentEndStr = this.toYMDLocal(endDate);

        for (let i = 0; i < numDays; i++) {
            const d = new Date(startDate);
            d.setDate(startDate.getDate() + i);

            const dateKey = this.toYMDLocal(d);
            const isFuture = dateKey > todayStr;
            const isToday = dateKey === todayStr;

            let cssClass = 'calendar-col';
            if (this.viewMode === 'month') cssClass += ' month-view-col';
            if (isToday) cssClass += ' today-col';

            days.push({
                dateKey,
                dayName: this.viewMode === 'week'
                    ? new Intl.DateTimeFormat('en-US', { weekday: 'long' }).format(d)
                    : '',
                formattedDate: new Intl.DateTimeFormat('en-US', { day: 'numeric' }).format(d),
                monthName: new Intl.DateTimeFormat('en-US', { month: 'short' }).format(d),
                records: [],
                totalHours: 0,
                isFuture,
                isToday,
                cssClass,
                actionLabel: this.viewMode === 'week' ? '+ Add Time' : '+',
                isActionDisabled: isFuture
            });
        }
        this.calendarDays = days;
    }

    mapDataToDays(timesheets) {
        const daysMap = JSON.parse(JSON.stringify(this.calendarDays));

        daysMap.forEach(day => {
            day.records = [];
            day.totalHours = 0;
        });

        timesheets.forEach(ts => {
            const day = daysMap.find(d => d.dateKey === ts.Date__c);
            if (!day) return;

            const displayLabel = ts.Project__r ? ts.Project__r.Name : ts.Name;

            day.records.push({
                Id: ts.Id,
                Hours: ts.Billable_Hours__c,
                DisplayTitle: displayLabel,
                Description: ts.Description__c,
                AmountContract: ts.Amount_Based_On_Contract_Price__c,
                showAmount: this.isContractContext && ts.Amount_Based_On_Contract_Price__c != null,
                showProjectName: this.notOnRecordPage
            });

            day.totalHours += ts.Billable_Hours__c;
        });

        this.calendarDays = daysMap;
    }

    // ---------- Navigation ----------
    handlePrev() {
        const date = new Date(this.currentStartStr + 'T00:00:00');
        const delta = this.viewMode === 'week' ? 7 : 42;
        date.setDate(date.getDate() - delta);
        this.setCalendarDate(date);
    }

    handleNext() {
        const date = new Date(this.currentStartStr + 'T00:00:00');
        const delta = this.viewMode === 'week' ? 7 : 42;
        date.setDate(date.getDate() + delta);
        this.setCalendarDate(date);
    }

    // ---------- Interactions ----------
    handleAddClick(event) {
        const dateKey = event.target.dataset.date;
        const isFuture = event.target.dataset.future === 'true';
        if (isFuture) return;

        this.selectedDate = dateKey;
        this.selectedRecordId = null;
        this.isModalOpen = true;
    }

    handleRecordClick(event) {
        event.stopPropagation();
        const timesheetId = event.currentTarget.dataset.id;

        let recordDate = null;
        for (const day of this.calendarDays) {
            const found = day.records.find(r => r.Id === timesheetId);
            if (found) {
                recordDate = day.dateKey;
                break;
            }
        }

        this.selectedDate = recordDate;
        this.selectedRecordId = timesheetId;
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedDate = null;
        this.selectedRecordId = null;
    }

    // ---------- Delete ----------
    handleDelete() {
        deleteRecord(this.selectedRecordId)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Timesheet deleted successfully',
                        variant: 'success'
                    })
                );
                this.closeModal();
                return refreshApex(this.wiredTimesheetResult);
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error deleting record',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    })
                );
            });
    }

    // Inject defaults before save
    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;

        if (this.isProjectContext) {
            fields.Project__c = this.recordId;
        }

        if (this.isContractContext) {
            fields.Contract__c = this.recordId;
            if (this.contractProjectId) {
                fields.Project__c = this.contractProjectId;
            }
        }

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess() {
        this.closeModal();
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Timesheet saved',
                variant: 'success'
            })
        );
        refreshApex(this.wiredTimesheetResult);
    }
}