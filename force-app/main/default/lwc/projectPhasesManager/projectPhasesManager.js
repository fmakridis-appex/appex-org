import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getProjectPhases from '@salesforce/apex/ProjectPhasesController.getProjectPhases';
import saveProjectPhases from '@salesforce/apex/ProjectPhasesController.saveProjectPhases';

export default class ProjectPhasesManager extends LightningElement {
    @api recordId;
    @api objectApiName;

    gridData = [];
    columns = [];
    expandedRows = [];
    projectTotalHours = 0;
    cr1TotalHours = 0;
    cr2TotalHours = 0;

    isSaving = false;

    isEditModalOpen = false;
    showHoursInput = true;
    isHoursDisabled = false;

    showCr1 = false;
    showCr2 = false;

    showCr1InModal = false;
    showCr2InModal = false;

    get isProject() {
        return this.objectApiName === 'Project__c'; 
    }

    editRow = { id: null, name: '', description: '', hours: 0, cr1Hours: 0, cr2Hours: 0, billable: false };

    wiredPhasesResult;
    changedIds = new Set();
    saveTimeout;

    @wire(getProjectPhases, { parentId: '$recordId' })
    wiredPhases(result) {
        this.wiredPhasesResult = result;
        const { data, error } = result;

        if (data) {
            this.gridData = this.buildGridData(data);

            const hasCrByName = (rows, name) =>
                (rows || []).some(r =>
                    (r.name || '').trim().toLowerCase() === name.toLowerCase() ||
                    (r._children || []).some(c => (c.name || '').trim().toLowerCase() === name.toLowerCase())
                );

            this.showCr1 = hasCrByName(this.gridData, 'Change Request 1');
            this.showCr2 = hasCrByName(this.gridData, 'Change Request 2');

            this.buildColumns();
            this.updateNumberingAndTotals();
        } else if (error) {
            this.showToast('Error', error.body?.message || 'Load failed', 'error');
        }
    }

    connectedCallback() {
        this.buildColumns();
    }

    buildColumns() {
        const cols = [
            { label: 'No.', fieldName: 'phaseNumber', type: 'text', initialWidth: 80 },
            { label: 'Name', fieldName: 'name', type: 'text' },
            { label: 'Description', fieldName: 'description', type: 'text' },
        ];

        if (this.isProject) {
            cols.push({
                label: 'Payment Milestone',
                fieldName: 'billable',
                type: 'boolean',
                initialWidth: 80,
                cellAttributes: { alignment: 'center' }
            });
        }

        cols.push({
            label: 'Hours',
            fieldName: 'hours',
            type: 'number',
            initialWidth: 100,
            typeAttributes: { minimumFractionDigits: 1, maximumFractionDigits: 1 }
        });

        if (this.showCr1) {
            cols.push({
                label: 'CR1 Hours',
                fieldName: 'cr1Hours',
                type: 'number',
                initialWidth: 110,
                typeAttributes: { minimumFractionDigits: 1, maximumFractionDigits: 1 }
            });
        }

        if (this.showCr2) {
            cols.push({
                label: 'CR2 Hours',
                fieldName: 'cr2Hours',
                type: 'number',
                initialWidth: 110,
                typeAttributes: { minimumFractionDigits: 1, maximumFractionDigits: 1 }
            });
        }

        cols.push({
            type: 'action',
            typeAttributes: { rowActions: this.getRowActions, menuAlignment: 'right' },
            initialWidth: 80
        });

        this.columns = cols;
    }

    getRowActions(row, doneCallback) {
        const actions = [
            { label: 'Edit', name: 'edit_row', iconName: 'utility:edit' },
            { label: 'Move Up', name: 'move_up', iconName: 'utility:chevronup' },
            { label: 'Move Down', name: 'move_down', iconName: 'utility:chevrondown' },
            { label: 'Delete', name: 'delete', iconName: 'utility:delete' }
        ];
    
        if (!row.parentId) {
            actions.splice(3, 0, { label: 'Add Subtask', name: 'add_subtask', iconName: 'utility:add' });
            actions.splice(4, 0, { label: 'Add Phase', name: 'add_phase', iconName: 'utility:add' });
        }
    
        doneCallback(actions);
    }
    

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
    
        switch (name) {
            case 'edit_row':
                this.openEditModal(row);
                break;
            case 'move_up':
                this.moveRow(row, -1); // -1 moves up (lower index)
                break;
            case 'move_down':
                this.moveRow(row, 1);  // 1 moves down (higher index)
                break;
            case 'add_subtask':
                this.addSubtask(row.id);
                break;
            case 'add_phase':
                this.handleAddPhase();
                break;
            case 'delete':
                this.removeRow(row.id);
                break;
        }
    }

    moveRow(row, direction) {
        let listToReorder = null;
        let index = -1;
    
        // 1. Identify the list containing this row
        if (!row.parentId) {
            // It's a Top-Level Phase
            listToReorder = this.gridData;
            index = listToReorder.findIndex(r => r.id === row.id);
        } else {
            // It's a Subtask: find the parent first
            const parent = this.findRowById(row.parentId);
            if (parent && parent._children) {
                listToReorder = parent._children;
                index = listToReorder.findIndex(r => r.id === row.id);
            }
        }
    
        // 2. Validate move
        if (!listToReorder || index === -1) return;
        
        const newIndex = index + direction;
        
        // Check bounds (can't move up from 0, can't move down from last)
        if (newIndex < 0 || newIndex >= listToReorder.length) return;
    
        // 3. Swap Rows
        const rowToMove = listToReorder[index];
        const rowToSwap = listToReorder[newIndex];
        
        // Perform swap
        listToReorder[index] = rowToSwap;
        listToReorder[newIndex] = rowToMove;
    
        // 4. Mark both as changed so they save
        this.changedIds.add(rowToMove.id);
        this.changedIds.add(rowToSwap.id);
    
        // 5. Update UI & Numbering
        // If we modified a children array, we need to force gridData refresh
        // (If we modified gridData directly, the reference updates in updateNumberingAndTotals)
        
        this.updateNumberingAndTotals(); // This will recalculate 1.1, 1.2 etc.
        this.scheduleSave();
    }
    
    

    openEditModal(row) {
        const hasChildren = !!row._children?.length;

        this.editRow = {
            id: row.id,
            name: row.name || '',
            description: row.description || '',
            hours: row.hours || 0,
            cr1Hours: row.cr1Hours || 0,
            cr2Hours: row.cr2Hours || 0,
            billable: !!row.billable
        };

        this.showHoursInput = true;
        this.isHoursDisabled = (!row.parentId && hasChildren);

        this.showCr1InModal = this.showCr1;
        this.showCr2InModal = this.showCr2;

        this.isEditModalOpen = true;
    }

    closeEditModal() {
        this.isEditModalOpen = false;
        this.editRow = { id: null, name: '', description: '', hours: 0, cr1Hours: 0, cr2Hours: 0, billable: false };
        this.showCr1InModal = false;
        this.showCr2InModal = false;
    }

    handleEditChange(event) {
        const field = event.target.dataset.field;
        
        let value;
        if (event.target.type === 'checkbox' || event.target.type === 'toggle') {
            value = event.target.checked;
        } else {
            value = event.target.value;
        }

        if (field === 'hours' || field === 'cr1Hours' || field === 'cr2Hours') {
            value = parseFloat(value) || 0;
        }

        this.editRow = { ...this.editRow, [field]: value };
    }

    saveEditRow() {
        if (!this.editRow.name?.trim()) {
            this.showToast('Validation', 'Name is required', 'error');
            return;
        }

        if (this.editRow.description?.length > 5000) {
            this.showToast('Validation', 'Description max 255 chars', 'error');
            return;
        }

        const updated = this.gridData.map(p => {
            // Edit Parent
            if (p.id === this.editRow.id) {
                return {
                    ...p,
                    name: this.editRow.name.trim(),
                    description: this.editRow.description || '',
                    hours: Number(this.editRow.hours) || 0,
                    cr1Hours: Number(this.editRow.cr1Hours) || 0,
                    cr2Hours: Number(this.editRow.cr2Hours) || 0,
                    billable: !!this.editRow.billable
                };
            }

            // Edit Child
            if (p._children?.length) {
                const newChildren = p._children.map(c => {
                    if (c.id === this.editRow.id) {
                        return {
                            ...c,
                            name: this.editRow.name.trim(),
                            description: this.editRow.description || '',
                            hours: Number(this.editRow.hours) || 0,
                            cr1Hours: Number(this.editRow.cr1Hours) || 0,
                            cr2Hours: Number(this.editRow.cr2Hours) || 0,
                            billable: !!this.editRow.billable
                        };
                    }
                    return c;
                });

                const changed = newChildren.some((c, i) => c !== p._children[i]);
                if (changed) {
                    return { ...p, _children: newChildren };
                }
            }
            return p;
        });

        this.gridData = updated;
        this.changedIds.add(this.editRow.id);

        this.updateNumberingAndTotals();
        this.scheduleSave();
        this.closeEditModal();
    }

    handleAddPhase() {
        this.insertNewRow(null, true);
    }

    addSubtask(parentId) {
        this.insertNewRow(parentId, false);
    }

    insertNewRow(parentId, isPhase) {
        const newRow = {
            id: `new_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
            phaseNumber: '',
            name: isPhase ? 'New Phase' : 'New Subtask',
            description: '',
            hours: 0,
            cr1Hours: 0,
            cr2Hours: 0,
            billable: false,
            isPhase,
            parentId,
            _children: []
        };

        if (isPhase) {
            this.gridData = [...this.gridData, newRow];
        } else {
            const parent = this.findRowById(parentId);
            if (parent) {
                parent._children = parent._children || [];
                parent._children.push(newRow);
                
                if (!this.expandedRows.includes(parentId)) {
                    this.expandedRows = [...this.expandedRows, parentId];
                }
            }
        }

        this.changedIds.add(newRow.id);

        const nm = (newRow.name || '').trim().toLowerCase();
        if (nm === 'change request 1') this.showCr1 = true;
        if (nm === 'change request 2') this.showCr2 = true;

        this.buildColumns();
        this.updateNumberingAndTotals();
        this.scheduleSave();
    }

    removeRow(rowId) {
        if (!confirm('Delete this item?')) return;

        const row = this.findRowById(rowId);
        if (!row) return;

        if (!row.parentId) {
            this.gridData = this.gridData.filter(r => r.id !== rowId);
        } else {
            const parent = this.findRowById(row.parentId);
            if (parent?._children) {
                parent._children = parent._children.filter(r => r.id !== rowId);
            }
        }

        this.changedIds.add(rowId);
        this.updateNumberingAndTotals();
        this.scheduleSave();
    }

    handleExpandAll() {
        const allIds = [];
        this.gridData.forEach(p => {
            allIds.push(p.id);
            (p._children || []).forEach(c => allIds.push(c.id));
        });
        this.expandedRows = allIds;
    }

    handleCollapseAll() {
        this.expandedRows = [];
    }

    scheduleSave() {
        clearTimeout(this.saveTimeout);
        this.saveTimeout = setTimeout(() => this.handleSave(), 400);
    }

    handleSave() {
        if (this.isSaving) return;
        this.isSaving = true;

        const phasesToSave = [];
        const phasesToDelete = [];

        this.changedIds.forEach(id => {
            if (!id.startsWith('new_') && !this.findRowById(id)) {
                phasesToDelete.push(id);
            }
        });

        this.collectChanges(this.gridData, null, phasesToSave);
        console.log("phasesToSave - collectChanges: "+JSON.stringify(phasesToSave,null,2));
        
        if (!phasesToSave.length && !phasesToDelete.length) {
            this.isSaving = false;
            return;
        }

        saveProjectPhases({
            phasesToSave: phasesToSave,
            phasesToDelete: phasesToDelete,
            parentId: this.recordId
        })
            .then(() => {
                this.changedIds.clear();
                return refreshApex(this.wiredPhasesResult);
            })
            .then(() => this.showToast('Saved', 'Changes saved.', 'success'))
            .catch(error => {
                console.error('Save Error:', JSON.stringify(error));
                this.showToast('Error', error.body?.message || error.message, 'error');
            })
            .finally(() => (this.isSaving = false));
    }

    updateNumberingAndTotals() {
        let phaseNum = 1;
        let totalHours = 0;
        let cr1Total = 0;
        let cr2Total = 0;

        this.gridData = this.gridData.map(phase => {
            const newPhase = { ...phase };
            // EXPLICIT COPY OF BILLABLE (redundant but safe)
            newPhase.billable = !!phase.billable;
            
            newPhase.phaseNumber = `${phaseNum}.`;
            phaseNum++;

            const children = newPhase._children || [];
            
            newPhase.hours = Number(newPhase.hours) || 0;
            newPhase.cr1Hours = Number(newPhase.cr1Hours) || 0;
            newPhase.cr2Hours = Number(newPhase.cr2Hours) || 0;

            if (children.length > 0) {
                let phaseHours = 0;
                let phaseCr1 = 0;
                let phaseCr2 = 0;

                const newChildren = children.map((sub, idx) => {
                    const newSub = { ...sub };
                    // EXPLICIT COPY OF BILLABLE (redundant but safe)
                    newSub.billable = !!sub.billable;

                    newSub.phaseNumber = `${newPhase.phaseNumber}${idx + 1}.`;
                    
                    newSub.hours = Number(newSub.hours) || 0;
                    newSub.cr1Hours = Number(newSub.cr1Hours) || 0;
                    newSub.cr2Hours = Number(newSub.cr2Hours) || 0;

                    phaseHours += newSub.hours;
                    phaseCr1 += newSub.cr1Hours;
                    phaseCr2 += newSub.cr2Hours;

                    totalHours += newSub.hours;
                    cr1Total += newSub.cr1Hours;
                    cr2Total += newSub.cr2Hours;
                    
                    console.log("newSub: "+JSON.stringify(newSub,null,2));
                    return newSub;
                });

                newPhase._children = newChildren;

                const oldHours = newPhase.hours;
                const oldCr1 = newPhase.cr1Hours;
                const oldCr2 = newPhase.cr2Hours;

                newPhase.hours = phaseHours;
                newPhase.cr1Hours = phaseCr1;
                newPhase.cr2Hours = phaseCr2;

                if (newPhase.hours !== oldHours || 
                    newPhase.cr1Hours !== oldCr1 || 
                    newPhase.cr2Hours !== oldCr2) {
                    this.changedIds.add(newPhase.id);
                }

            } else {
                totalHours += newPhase.hours;
                cr1Total += newPhase.cr1Hours;
                cr2Total += newPhase.cr2Hours;
            }

            console.log("newPhase: "+JSON.stringify(newPhase,null,2));
            return newPhase;
        });

        this.projectTotalHours = totalHours;
        this.cr1TotalHours = cr1Total;
        this.cr2TotalHours = cr2Total;

        console.log("projectTotalHours: "+ this.projectTotalHours);
        console.log("cr1TotalHours: "+ this.cr1TotalHours);
        console.log("cr2TotalHours: "+ this.cr2TotalHours);
    }

    collectChanges(rows, parentId, phasesToSave) {
        rows.forEach(row => {
            if (this.changedIds.has(row.id) || row.id.startsWith('new_')) {
                console.log("row.cr1Hours: "+row.cr1Hours);
                console.log("row.cr2Hours: "+row.cr2Hours);
                phasesToSave.push({
                    id: row.id,
                    name: row.name ?? '',
                    description: row.description ?? '',
                    phaseNumber: row.phaseNumber ?? '',
                    hours: Number(row.hours) || 0,
                    parentId: parentId,
                    isPhase: !!row.isPhase,
                    cr1Hours: Number(row.cr1Hours) || 0,
                    cr2Hours: Number(row.cr2Hours) || 0,
                    billable: !!row.billable // Explicit boolean conversion
                });
                console.log("phasesToSave - inside collectChanges "+JSON.stringify(phasesToSave,null,2));
            }

            if (row._children?.length) {
                this.collectChanges(row._children, row.id, phasesToSave);
            }
        });
    }

    buildGridData(apexData) {
        return (apexData || []).map(p => ({
            id: p.data.Id,
            phaseNumber: p.data.Phase_Number__c,
            name: p.data.Name__c,
            description: p.data.Description__c,
            hours: p.data.Hours__c ?? 0,
            cr1Hours: p.data.CR_1_Hours__c || 0,
            cr2Hours: p.data.CR_2_Hours__c || 0,
            billable: p.data.Billable__c === true, // Ensure we map the field
            isPhase: p.data.Is_Phase__c === true,
            parentId: p.data.Parent_Phase__c,
            _children: (p.children || []).map(c => ({
                id: c.data.Id,
                phaseNumber: c.data.Phase_Number__c,
                name: c.data.Name__c,
                description: c.data.Description__c,
                hours: c.data.Hours__c ?? 0,
                cr1Hours: c.data.CR_1_Hours__c || 0,
                cr2Hours: c.data.CR_2_Hours__c || 0,
                billable: c.data.Billable__c === true, // Ensure we map the field
                isPhase: c.data.Is_Phase__c === true,
                parentId: c.data.Parent_Phase__c,
                _children: []
            }))
        }));
    }

    findRowById(id) {
        for (const p of this.gridData) {
            if (p.id === id) return p;
            for (const c of p._children || []) {
                if (c.id === id) return c;
            }
        }
        return null;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}