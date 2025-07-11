# Microsoft Identity Management Runbook Automation (idm-pack)

PowerShell automation solution for Microsoft 365 Identity Management processes using Microsoft Graph API.

## Overview

This tool automates the manual discovery and configuration tasks for Microsoft 365 tenant Identity Management, replacing time-consuming manual processes with consistent, scripted automation.

## Features

- **Automated Discovery**: Gathers complete tenant information including CA policies, MFA/SSPR status, authentication methods, secure score, and sign-in logs
- **Configuration Templates**: JSON-based templates for consistent policy deployment
- **Secure Authentication**: Uses Microsoft Graph API with proper permission scoping
- **Comprehensive Reporting**: Exports discovery data to JSON and generates HTML reports

## Prerequisites

- PowerShell 5.1 or later
- Microsoft.Graph PowerShell module (auto-installed)
- Global Administrator or appropriate permissions in target tenant

## Quick Start

1. Run the main script (you'll be prompted to sign in):
```powershell
.\Main.ps1
```

2. Sign in with your Microsoft 365 credentials when prompted

3. Choose from menu options:
   - Discovery Only
   - Configuration Only  
   - Both Discovery and Configuration

## Usage Examples

```powershell
# Run with interactive menu (default)
.\Main.ps1

# Run discovery only
.\Main.ps1 -Mode "Discovery"

# Run configuration only
.\Main.ps1 -Mode "Configuration"

# Run both discovery and configuration
.\Main.ps1 -Mode "Both"
```

## Files

- `Main.ps1` - Entry point script with authentication and menu
- `Discovery.ps1` - Tenant discovery and data collection
- `Configure.ps1` - Configuration application (coming soon)
- `templates/` - JSON configuration templates (coming soon)

## Required Permissions

- Policy.Read.All
- Policy.ReadWrite.ConditionalAccess
- Directory.Read.All
- Directory.ReadWrite.All
- User.ReadWrite.All
- SecurityEvents.Read.All
- AuditLog.Read.All
- Reports.Read.All

## Output

Discovery generates:
- `IDM-Discovery-YYYYMMDD-HHMMSS.json` - Complete tenant data export
- Console output with progress and results

## Development Status

- ✅ Authentication and connection testing
- ✅ Discovery module (CA policies, MFA/SSPR, auth methods, secure score, sign-in logs, branding)
- 🚧 Configuration templates
- 🚧 Configuration module
- 🚧 HTML reporting