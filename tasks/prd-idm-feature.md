Product Requirements Document: Automated Microsoft Identity Management Runbook
Author: Gemini
Version: 1.0
Date: 2025-07-11
1. Overview
This document outlines the requirements for a PowerShell-based automation solution to streamline the processes detailed in the "Microsoft Identity Management Runbook." The goal is to replace the current manual discovery and configuration tasks with a script that leverages the Microsoft Graph API and JSON configuration files for consistency, speed, and accuracy.
2. The Problem: "As-Is" State
Currently, the process of onboarding and configuring a new Microsoft 365 tenant for Identity Management is a manual, time-consuming, and error-prone process. It involves:
Manual Discovery: An engineer must manually navigate through the Microsoft Entra admin center to gather information about the existing environment, such as Conditional Access policies, MFA status, and branding settings. This information is then manually recorded in a checklist.
Manual Configuration: Based on the discovery findings and a predefined set of best practices, the engineer manually configures various settings, including Conditional Access policies, Self-Service Password Reset (SSPR), and organizational branding.
Inconsistency: The manual nature of the process can lead to inconsistencies in configurations across different tenants.
Time Consuming: The entire process, from discovery to handover, requires significant engineering time.
3. The Solution: "To-Be" State
The proposed solution is a PowerShell script that automates the entire Identity Management runbook process. This script will:
Automate Discovery: The script will use the Microsoft Graph API to automatically discover the existing configuration of a target tenant and generate a detailed report.
Automate Configuration: The script will use a set of predefined JSON configuration templates to apply standardized settings for Conditional Access, SSPR, branding, and other Identity Management features.
Ensure Consistency: By using templates, the script will ensure that all tenants are configured to the same high standard.
Reduce Engineering Time: The automation will significantly reduce the time required to onboard and configure a new tenant.
4. Key Features
4.1. Discovery Module
This module will be responsible for gathering information about the existing environment.
Functionality:
Connect to the target tenant using the Microsoft Graph API.
Read and export all existing Conditional Access policies.
Check the migration status for legacy MFA and SSPR.
Check the status of Self-Service Password Reset (SSPR).
Check the legacy MFA policy.
List all enabled authentication methods.
Retrieve the current Identity Secure Score.
Export sign-in event logs for the last 7 days, filtered by "Failure" and "Interrupted."
Check for existing organizational branding.
Output:
A consolidated HTML or Markdown report detailing all the discovered settings.
A JSON file containing the raw data retrieved from the Graph API.
4.2. Configuration Module
This module will be responsible for applying the new configuration to the tenant.
Functionality:
Read configuration settings from a set of JSON templates.
User Onboarding: (No direct automation, but the script can be a part of the process).
Organizational Branding:
Apply branding elements (favicon, logos, background images, etc.) based on a JSON configuration file and a folder of image assets.
Emergency Access Account:
Create a new emergency access account with the "Global Administrator" role.
Exclude the emergency access account from all Conditional Access policies.
Conditional Access:
Create a default set of Conditional Access policies from JSON templates, including:
MFA for all administrators.
MFA for all users.
MFA for all guests.
Allow for the creation of custom Conditional Access policies from additional JSON templates.
Self-Service Password Reset (SSPR):
Enable and configure SSPR based on a JSON template.
Set the number of methods required to reset to 2.
Enable "Mobile app notification" and "Mobile phone (SMS only)."
Configure SSPR registration to be required at sign-in.
Configure notifications for password resets.
Authentication Methods & Password Policies:
Enable "Microsoft Authenticator" and "Temporary Access Pass (TAP)."
Configure password protection settings (lockout threshold, duration, etc.) from a JSON template.
4.3. Configuration Templates (JSON)
A set of JSON files will be used to define the desired configuration for each feature. This will allow for easy customization and reuse.
Example conditional_access_template.json:
{
  "displayName": "[Grant] MFA for all administrators",
  "state": "enabled",
  "conditions": {
    "users": {
      "includeRoles": [
        "62e90394-69f5-4237-9190-012177145e10"
      ]
    },
    "applications": {
      "includeApplications": [
        "all"
      ]
    }
  },
  "grantControls": {
    "operator": "OR",
    "builtInControls": [
      "mfa"
    ]
  }
}


5. Non-Functional Requirements
Error Handling: The script must include robust error handling to gracefully manage any issues that may arise during execution.
Logging: The script should generate a detailed log file of all actions taken, including any errors encountered.
Security: The script must securely handle credentials and access tokens. It should not store any secrets in the code.
Readability: The PowerShell code should be well-commented and easy to understand.
6. Technologies to be Used
PowerShell: The primary scripting language for the automation.
Microsoft Graph API: To interact with the Microsoft 365 tenant.
JSON: For configuration templates.
7. Success Criteria
The script successfully automates all the tasks outlined in the "Microsoft Identity Management Runbook."
The script reduces the time to onboard a new tenant by at least 80%.
The script produces consistent and accurate configurations across all tenants.
The script generates a comprehensive discovery report.
