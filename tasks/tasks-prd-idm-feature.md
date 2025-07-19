# Tasks for Microsoft Identity Management Runbook Automation

## Relevant Files

- `Main.ps1` - Entry point script
- `Discovery.ps1` - Gets tenant info
- `Configure.ps1` - Applies settings
- `templates/` - JSON config files

### Notes

- Run tests with `Invoke-Pester`

## Tasks

- [x] 1.0 Create basic scripts and connect to Graph API
  - [x] 1.1 Create Main.ps1 with basic structure
    - [x] 1.1.1 Create Main.ps1 file
    - [x] 1.1.2 Add parameter handling for tenant ID
    - [x] 1.1.3 Add menu options for discovery/configuration
    - [x] 1.1.4 Add basic error handling
  - [x] 1.2 Add Graph API authentication
    - [x] 1.2.1 Install Microsoft.Graph PowerShell module
    - [x] 1.2.2 Add Connect-MgGraph function
    - [x] 1.2.3 Request required permissions (Policy.Read.All, Policy.ReadWrite.ConditionalAccess, etc.)
    - [x] 1.2.4 Test authentication with Get-MgContext
  - [x] 1.3 Test connection works
    - [x] 1.3.1 Create test function to verify Graph connection
    - [x] 1.3.2 Test reading basic tenant info
- [x] 2.0 Build discovery script
  - [x] 2.1 Get all Conditional Access policies
    - [x] 2.1.1 Create Discovery.ps1 file
    - [x] 2.1.2 Use Get-MgIdentityConditionalAccessPolicy
    - [x] 2.1.3 Export policy details to object
  - [x] 2.2 Check MFA and SSPR status
    - [x] 2.2.1 Get MFA registration status with Get-MgReportAuthenticationMethodUserRegistrationDetail
    - [x] 2.2.2 Check SSPR enabled status
    - [x] 2.2.3 Get legacy MFA policy settings
  - [x] 2.3 Get authentication methods
    - [x] 2.3.1 Use Get-MgPolicyAuthenticationMethodPolicy
    - [x] 2.3.2 List enabled authentication methods
  - [x] 2.4 Get Identity Secure Score
    - [x] 2.4.1 Use Get-MgSecuritySecureScore
    - [x] 2.4.2 Export current score and recommendations
  - [x] 2.5 Export sign-in logs
    - [x] 2.5.1 Use Get-MgAuditLogSignIn with date filter (last 7 days)
    - [x] 2.5.2 Filter by status "Failure" and "Interrupted"
    - [x] 2.5.3 Export filtered logs
  - [x] 2.6 Check organizational branding
    - [x] 2.6.1 Use Get-MgOrganizationBrandingLocalization for branding
    - [x] 2.6.2 Check for existing logos and images
  - [x] 2.7 Export to JSON file
    - [x] 2.7.1 Combine all discovery data into single object
    - [x] 2.7.2 Export to JSON with ConvertTo-Json
    - [x] 2.7.3 Save with timestamp in filename
- [x] 3.0 Create configuration templates
  - [x] 3.1 Make CA policy templates (admin MFA, user MFA, guest MFA)
    - [x] 3.1.1 Create templates folder
    - [x] 3.1.2 Create admin-mfa-policy.json template
    - [x] 3.1.3 Create user-mfa-policy.json template
    - [x] 3.1.4 Create guest-mfa-policy.json template
  - [x] 3.2 Make SSPR template
    - [x] 3.2.1 Create sspr-config.json template
    - [x] 3.2.2 Set 2 methods required
    - [x] 3.2.3 Enable mobile app notification and SMS
  - [x] 3.3 Make branding template
    - [x] 3.3.1 Create branding-config.json template
    - [x] 3.3.2 Include logo and background image paths
- [ ] 4.0 Build configuration script
  - [x] 4.1 Create emergency access account
    - [x] 4.1.1 Create Configure.ps1 file
    - [x] 4.1.2 Generate random password for emergency account
    - [x] 4.1.3 Create user with New-MgUser
    - [x] 4.1.4 Assign Global Admin role
  - [ ] 4.2 Apply CA policies from templates
    - [ ] 4.2.1 Read JSON templates from templates folder
    - [ ] 4.2.2 Create policies with New-MgIdentityConditionalAccessPolicy
    - [ ] 4.2.3 Exclude emergency account from all policies
  - [ ] 4.3 Configure SSPR settings
    - [ ] 4.3.1 Read SSPR template
    - [ ] 4.3.2 Apply settings using Update-MgPolicyAuthorizationPolicy
    - [ ] 4.3.3 Configure notification settings
  - [ ] 4.4 Apply branding
    - [ ] 4.4.1 Read branding template
    - [ ] 4.4.2 Upload logo and background images
    - [ ] 4.4.3 Apply branding with Update-MgDirectorySettingTemplate
- [ ] 5.0 Add reporting
  - [x] 5.1 Generate HTML report
    - [x] 5.1.1 Create simple HTML template
    - [x] 5.1.2 Convert discovery JSON to HTML table
    - [x] 5.1.3 Save report with timestamp
  - [ ] 5.2 Add basic logging
    - [ ] 5.2.1 Create log file with timestamp
    - [ ] 5.2.2 Log all API calls and results
    - [ ] 5.2.3 Log errors and warnings