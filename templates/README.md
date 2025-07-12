# Configuration Templates

This directory contains JSON templates for standardized Microsoft 365 Identity Management configurations.

## Directory Structure

```
templates/
├── conditional-access/
│   ├── admin-mfa-policy.json      # MFA for all administrators
│   ├── user-mfa-policy.json       # MFA for all users
│   └── guest-mfa-policy.json      # MFA for all guests
├── sspr-config.json               # Self-Service Password Reset
├── branding-config.json           # Organizational branding
├── auth-methods-config.json       # Authentication methods & password protection
└── README.md                      # This file
```

## Template Descriptions

### Conditional Access Policies

**admin-mfa-policy.json**
- Requires MFA for all administrator roles
- Includes all standard Azure AD admin roles
- Applies to all applications and locations

**user-mfa-policy.json**
- Requires MFA for all users
- Excludes some Microsoft applications (Windows Sign In, Microsoft Intune Enrollment)
- Baseline security for all users

**guest-mfa-policy.json**
- Requires MFA for all guest and external users
- Ensures secure access for non-organizational accounts
- Applies to all applications

### SSPR Configuration

**sspr-config.json**
- Enables Self-Service Password Reset for all users
- Requires 2 authentication methods
- Enables mobile app notification and SMS
- Requires registration at sign-in
- Notifies users and admins on password reset

### Organizational Branding

**branding-config.json**
- Template for custom sign-in page branding
- Includes paths for logos, background images, and CSS
- Configurable text elements and links
- Supports multiple image formats and sizes

### Authentication Methods

**auth-methods-config.json**
- Enables Microsoft Authenticator with number matching
- Enables Temporary Access Pass (TAP)
- Enables FIDO2 security keys
- Configures password protection with lockout policies
- Enforces registration campaigns

## Usage

These templates are used by the configuration module (`Configure.ps1`) to apply standardized settings across Microsoft 365 tenants. The templates can be customized before deployment to match specific organizational requirements.

## Customization

Before using these templates:

1. **Review role IDs** in Conditional Access policies
2. **Update branding paths** and text in branding-config.json
3. **Adjust authentication method settings** as needed
4. **Modify SSPR settings** based on organizational policy

## Notes

- All templates follow Microsoft Graph API schema
- Templates include descriptions for documentation
- Emergency access accounts should be excluded from CA policies during configuration
- Asset files for branding should be placed in the `assets/` directory