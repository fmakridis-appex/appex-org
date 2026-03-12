# SFSC - Appex Salesforce Project

This repository contains all custom metadata components for the SF Appex Salesforce org.

## 📋 Custom Objects

The project includes the following custom objects:

- **Project__c** - Project management
- **Project_Phase__c** - Project phases and tasks (hierarchical structure)
- **Timesheet__c** - Work hours tracking
- **Payment__c** - Payment management
- **Change_Request__c** - Project change requests
- **Subcontractor_Partner__c** - Subcontractor management

## ⚡ Lightning Web Components

### projectPhasesManager
Project phases and tasks management with hierarchical tree structure. Features:
- Create and edit phases
- Parent-child relationships
- Billable/non-billable tracking
- Change Request hours (CR1, CR2)

### weeklyTimesheet
Weekly timesheet calendar for work hours tracking. Features:
- Weekly view with calendar interface
- Link to Projects and Contracts
- Billable hours tracking
- User-specific or admin view

### sharedFilesList
Display files shared with the current user.

## 🔧 Apex Classes

### Controllers
- `ProjectPhasesController` - Backend for project phases management
- `TimesheetController` - Backend for timesheet functionality
- `FileController` - Shared files management
- `SubcontractorPartnerHandler` - Business logic for subcontractors

### Communities/Portal Controllers
- `CommunitiesLoginController` - Login functionality
- `CommunitiesLandingController` - Landing page
- `CommunitiesSelfRegController` - Self registration
- `LightningLoginFormController` - Lightning login
- `LightningSelfRegisterController` - Lightning registration
- `ForgotPasswordController` - Password reset

## 🔄 Triggers

- `SubcontractorPartnerTrigger` - Automation for Subcontractor Partners
- `OpportunityTrigger` - Opportunity automation
- `linkCOACustomerToLMALicense` - License management

## 📦 Deployment

### Retrieve from Org
```bash
sf project retrieve start -x manifest/package.xml
```

### Deploy to Org
```bash
sf project deploy start -x manifest/package.xml
```

### Deploy to Sandbox
```bash
sf project deploy start -x manifest/package.xml --target-org YOUR_SANDBOX_ALIAS
```

## 🏗️ Project Structure

```
force-app/main/default/
├── classes/          # Apex classes
├── triggers/         # Apex triggers
├── lwc/             # Lightning Web Components
├── aura/            # Aura components
├── objects/         # Custom objects, fields, validation rules
├── layouts/         # Page layouts
├── flexipages/      # Lightning pages
├── flows/           # Flows
├── profiles/        # Profiles
├── permissionsets/  # Permission sets
├── tabs/            # Custom tabs
└── applications/    # Custom apps
```

## 📝 Notes

- This repository keeps only metadata (force-app, manifest) and documentation
- All configuration files (package.json, scripts, etc.) are ignored by Git
- Uses Salesforce API version 66.0

## 🔗 Resources

- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)

