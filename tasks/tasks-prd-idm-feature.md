# Tasks for Microsoft Identity Management Runbook Automation

## Relevant Files

- `Main.ps1` - Entry point script
- `Discovery.ps1` - Gets tenant info
- `Configure.ps1` - Applies settings
- `templates/` - JSON config files

### Notes

- Run tests with `Invoke-Pester`

## Tasks

- [ ] 1.0 Create basic scripts and connect to Graph API
  - [ ] 1.1 Create Main.ps1 with basic structure
    - [ ] 1.1.1 Create Main.ps1 file
    - [ ] 1.1.2 Add parameter handling for tenant ID
    - [ ] 1.1.3 Add menu options for discovery/configuration
    - [ ] 1.1.4 Add basic error handling
  - [ ] 1.2 Add Graph API authentication
    - [ ] 1.2.1 Install Microsoft.Graph PowerShell module
    - [ ] 1.2.2 Add Connect-MgGraph function
    - [ ] 1.2.3 Request required permissions (Policy.Read.All, Policy.ReadWrite.ConditionalAccess, etc.)
    - [ ] 1.2.4 Test authentication with Get-MgContext
  - [ ] 1.3 Test connection works
    - [ ] 1.3.1 Create test function to verify Graph connection
    - [ ] 1.3.2 Test reading basic tenant info
- [ ] 2.0 Build discovery script
  - [ ] 2.1 Get all Conditional Access policies
    - [ ] 2.1.1 Create Discovery.ps1 file
    - [ ] 2.1.2 Use Get-MgIdentityConditionalAccessPolicy
    - [ ] 2.1.3 Export policy details to object
  - [ ] 2.2 Check MFA and SSPR status
    - [ ] 2.2.1 Get MFA registration status with Get-MgReportAuthenticationMethodUserRegistrationDetail
    - [ ] 2.2.2 Check SSPR enabled status
    - [ ] 2.2.3 Get legacy MFA policy settings
  - [ ] 2.3 Get authentication methods
    - [ ] 2.3.1 Use Get-MgPolicyAuthenticationMethodPolicy
    - [ ] 2.3.2 List enabled authentication methods
  - [ ] 2.4 Get Identity Secure Score
    - [ ] 2.4.1 Use Get-MgSecuritySecureScore
    - [ ] 2.4.2 Export current score and recommendations
  - [ ] 2.5 Export sign-in logs
    - [ ] 2.5.1 Use Get-MgAuditLogSignIn with date filter (last 7 days)
    - [ ] 2.5.2 Filter by status "Failure" and "Interrupted"
    - [ ] 2.5.3 Export filtered logs
  - [ ] 2.6 Check organizational branding
    - [ ] 2.6.1 Use Get-MgDirectorySettingTemplate for branding
    - [ ] 2.6.2 Check for existing logos and images
  - [ ] 2.7 Export to JSON file
    - [ ] 2.7.1 Combine all discovery data into single object
    - [ ] 2.7.2 Export to JSON with ConvertTo-Json
    - [ ] 2.7.3 Save with timestamp in filename
- [ ] 3.0 Create configuration templates
  - [ ] 3.1 Make CA policy templates (admin MFA, user MFA, guest MFA)
    - [ ] 3.1.1 Create templates folder
    - [ ] 3.1.2 Create admin-mfa-policy.json template
    - [ ] 3.1.3 Create user-mfa-policy.json template
    - [ ] 3.1.4 Create guest-mfa-policy.json template
  - [ ] 3.2 Make SSPR template
    - [ ] 3.2.1 Create sspr-config.json template
    - [ ] 3.2.2 Set 2 methods required
    - [ ] 3.2.3 Enable mobile app notification and SMS
  - [ ] 3.3 Make branding template
    - [ ] 3.3.1 Create branding-config.json template
    - [ ] 3.3.2 Include logo and background image paths
- [ ] 4.0 Build configuration script
  - [ ] 4.1 Create emergency access account
    - [ ] 4.1.1 Create Configure.ps1 file
    - [ ] 4.1.2 Generate random password for emergency account
    - [ ] 4.1.3 Create user with New-MgUser
    - [ ] 4.1.4 Assign Global Admin role
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
  - [ ] 5.1 Generate HTML report
    - [ ] 5.1.1 Create simple HTML template
    - [ ] 5.1.2 Convert discovery JSON to HTML table
    - [ ] 5.1.3 Save report with timestamp
  - [ ] 5.2 Add basic logging
    - [ ] 5.2.1 Create log file with timestamp
    - [ ] 5.2.2 Log all API calls and results
    - [ ] 5.2.3 Log errors and warnings