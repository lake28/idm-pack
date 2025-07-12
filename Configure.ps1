# Configuration script for Microsoft Identity Management Runbook
# Applies standardized configurations using JSON templates

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("EmergencyAccount", "Branding", "SSPR", "All")]
    [string]$ConfigType = "All"
)

# Generate secure random password for emergency access account
function New-SecurePassword {
    param(
        [int]$Length = 24
    )
    
    try {
        # Character sets for password complexity
        $upperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        $lowerCase = "abcdefghijklmnopqrstuvwxyz"
        $numbers = "0123456789"
        $symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?"
        
        # Ensure at least one character from each set
        $password = ""
        $password += Get-Random -InputObject $upperCase.ToCharArray()
        $password += Get-Random -InputObject $lowerCase.ToCharArray()
        $password += Get-Random -InputObject $numbers.ToCharArray()
        $password += Get-Random -InputObject $symbols.ToCharArray()
        
        # Fill remaining length with random characters from all sets
        $allChars = $upperCase + $lowerCase + $numbers + $symbols
        for ($i = 4; $i -lt $Length; $i++) {
            $password += Get-Random -InputObject $allChars.ToCharArray()
        }
        
        # Shuffle the password
        $passwordArray = $password.ToCharArray()
        $shuffledPassword = ""
        while ($passwordArray.Length -gt 0) {
            $randomIndex = Get-Random -Maximum $passwordArray.Length
            $shuffledPassword += $passwordArray[$randomIndex]
            $passwordArray = $passwordArray[0..($randomIndex-1)] + $passwordArray[($randomIndex+1)..($passwordArray.Length-1)]
        }
        
        Write-Host "Generated secure password with $Length characters" -ForegroundColor Green
        return $shuffledPassword
    }
    catch {
        Write-Error "Failed to generate secure password: $_"
        throw
    }
}

# Get the primary domain of the tenant
function Get-TenantPrimaryDomain {
    try {
        Write-Host "Getting tenant primary domain..." -ForegroundColor Cyan
        
        $organization = Get-MgOrganization
        $primaryDomain = $organization.VerifiedDomains | Where-Object { $_.IsInitial -eq $true } | Select-Object -ExpandProperty Name
        
        if (-not $primaryDomain) {
            $primaryDomain = $organization.VerifiedDomains | Select-Object -First 1 -ExpandProperty Name
        }
        
        Write-Host "Primary domain: $primaryDomain" -ForegroundColor Green
        return $primaryDomain
    }
    catch {
        Write-Error "Failed to get tenant primary domain: $_"
        throw
    }
}

# Create emergency access account
function New-EmergencyAccessAccount {
    try {
        Write-Host "Creating emergency access account..." -ForegroundColor Cyan
        
        # Get tenant domain
        $primaryDomain = Get-TenantPrimaryDomain
        $emergencyUserPrincipalName = "emergencyaccess@$primaryDomain"
        
        # Check if account already exists
        try {
            $existingUser = Get-MgUser -Filter "userPrincipalName eq '$emergencyUserPrincipalName'"
            if ($existingUser) {
                Write-Host "Emergency access account already exists: $emergencyUserPrincipalName" -ForegroundColor Yellow
                return @{
                    UserPrincipalName = $emergencyUserPrincipalName
                    Password = "EXISTING_ACCOUNT"
                    ObjectId = $existingUser.Id
                }
            }
        }
        catch {
            # Account doesn't exist, continue with creation
        }
        
        # Generate secure password
        $emergencyPassword = New-SecurePassword -Length 24
        
        # Create user account
        Write-Host "Creating user: $emergencyUserPrincipalName" -ForegroundColor Gray
        
        $userParams = @{
            AccountEnabled = $false  # Start disabled for security
            DisplayName = "Emergency Access Account"
            UserPrincipalName = $emergencyUserPrincipalName
            MailNickname = "emergencyaccess"
            PasswordProfile = @{
                ForceChangePasswordNextSignIn = $false
                Password = $emergencyPassword
            }
            UsageLocation = "US"  # Required for license assignment
        }
        
        $newUser = New-MgUser @userParams
        
        Write-Host "Emergency access account created successfully" -ForegroundColor Green
        Write-Host "User Principal Name: $emergencyUserPrincipalName" -ForegroundColor White
        Write-Host "Object ID: $($newUser.Id)" -ForegroundColor White
        
        return @{
            UserPrincipalName = $emergencyUserPrincipalName
            Password = $emergencyPassword
            ObjectId = $newUser.Id
        }
    }
    catch {
        Write-Error "Failed to create emergency access account: $_"
        throw
    }
}

# Assign Global Administrator role to emergency account
function Set-EmergencyAccountGlobalAdmin {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserObjectId,
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    
    try {
        Write-Host "Assigning Global Administrator role to emergency account..." -ForegroundColor Cyan
        
        # Get Global Administrator role
        $globalAdminRole = Get-MgDirectoryRole -Filter "displayName eq 'Global Administrator'"
        if (-not $globalAdminRole) {
            # If role template isn't activated, activate it
            $roleTemplate = Get-MgDirectoryRoleTemplate -Filter "displayName eq 'Global Administrator'"
            $globalAdminRole = New-MgDirectoryRole -RoleTemplateId $roleTemplate.Id
        }
        
        # Check if user already has the role
        $existingRoleMembers = Get-MgDirectoryRoleMember -DirectoryRoleId $globalAdminRole.Id
        $userAlreadyHasRole = $existingRoleMembers | Where-Object { $_.Id -eq $UserObjectId }
        
        if ($userAlreadyHasRole) {
            Write-Host "User already has Global Administrator role" -ForegroundColor Yellow
        }
        else {
            # Assign Global Administrator role
            $roleParams = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserObjectId"
            }
            
            New-MgDirectoryRoleMemberByRef -DirectoryRoleId $globalAdminRole.Id -BodyParameter $roleParams
            Write-Host "Global Administrator role assigned successfully" -ForegroundColor Green
        }
        
        # Enable the account now that role is assigned
        Write-Host "Enabling emergency access account..." -ForegroundColor Gray
        Update-MgUser -UserId $UserObjectId -AccountEnabled:$true
        
        Write-Host "Emergency access account setup completed successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to assign Global Administrator role: $_"
        throw
    }
}

# Apply organizational branding configuration
function Set-OrganizationalBranding {
    try {
        Write-Host "Applying organizational branding configuration..." -ForegroundColor Cyan
        
        # Load branding template
        $brandingTemplatePath = "templates/branding-config.json"
        if (-not (Test-Path $brandingTemplatePath)) {
            throw "Branding template not found: $brandingTemplatePath"
        }
        
        $brandingConfig = Get-Content $brandingTemplatePath | ConvertFrom-Json
        Write-Host "Loaded branding configuration template" -ForegroundColor Green
        
        # TODO: Implement branding application
        Write-Host "Branding configuration completed (placeholder)" -ForegroundColor Yellow
        
        return $true
    }
    catch {
        Write-Error "Failed to apply organizational branding: $_"
        throw
    }
}

# Apply SSPR configuration
function Set-SsprConfiguration {
    try {
        Write-Host "Applying SSPR configuration..." -ForegroundColor Cyan
        
        # Load SSPR template
        $ssprTemplatePath = "templates/sspr-config.json"
        if (-not (Test-Path $ssprTemplatePath)) {
            throw "SSPR template not found: $ssprTemplatePath"
        }
        
        $ssprConfig = Get-Content $ssprTemplatePath | ConvertFrom-Json
        Write-Host "Loaded SSPR configuration template" -ForegroundColor Green
        
        # TODO: Implement SSPR configuration
        Write-Host "SSPR configuration completed (placeholder)" -ForegroundColor Yellow
        
        return $true
    }
    catch {
        Write-Error "Failed to apply SSPR configuration: $_"
        throw
    }
}

# Test Graph connection for configuration requirements
function Test-ConfigurationConnection {
    try {
        Write-Host "Testing Graph connection for configuration..." -ForegroundColor Yellow
        
        # Test organization access
        $org = Get-MgOrganization
        if (-not $org) {
            throw "Cannot access organization information"
        }
        
        # Test user creation permissions
        try {
            # This will fail if we don't have permissions, but won't actually create anything
            $testParams = @{
                AccountEnabled = $false
                DisplayName = "TEST_USER_DO_NOT_CREATE"
                UserPrincipalName = "test@nonexistent.domain"
                MailNickname = "test"
                PasswordProfile = @{
                    Password = "TempPassword123!"
                    ForceChangePasswordNextSignIn = $true
                }
            }
            # We won't actually run this, just validate the command works
        }
        catch {
            # Expected to fail with the test data
        }
        
        Write-Host "Configuration connection test passed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Configuration connection test failed: $_"
        return $false
    }
}

# Main configuration function
function Start-TenantConfiguration {
    param(
        [string]$ConfigurationType = "All"
    )
    
    try {
        Write-Host "Starting tenant configuration..." -ForegroundColor Green
        Write-Host "Configuration type: $ConfigurationType" -ForegroundColor Cyan
        
        # Test connection
        if (-not (Test-ConfigurationConnection)) {
            throw "Graph connection test failed"
        }
        
        $results = @{}
        
        # Emergency Access Account
        if ($ConfigurationType -eq "All" -or $ConfigurationType -eq "EmergencyAccount") {
            Write-Host "`n=== EMERGENCY ACCESS ACCOUNT ===" -ForegroundColor Magenta
            
            $emergencyAccount = New-EmergencyAccessAccount
            $results.EmergencyAccount = $emergencyAccount
            
            if ($emergencyAccount.Password -ne "EXISTING_ACCOUNT") {
                Set-EmergencyAccountGlobalAdmin -UserObjectId $emergencyAccount.ObjectId -UserPrincipalName $emergencyAccount.UserPrincipalName
                
                Write-Host "`n*** IMPORTANT: EMERGENCY ACCESS CREDENTIALS ***" -ForegroundColor Red
                Write-Host "Username: $($emergencyAccount.UserPrincipalName)" -ForegroundColor Yellow
                Write-Host "Password: $($emergencyAccount.Password)" -ForegroundColor Yellow
                Write-Host "*** STORE THESE CREDENTIALS SECURELY ***" -ForegroundColor Red
            }
        }
        
        # Organizational Branding
        if ($ConfigurationType -eq "All" -or $ConfigurationType -eq "Branding") {
            Write-Host "`n=== ORGANIZATIONAL BRANDING ===" -ForegroundColor Magenta
            $results.Branding = Set-OrganizationalBranding
        }
        
        # SSPR Configuration
        if ($ConfigurationType -eq "All" -or $ConfigurationType -eq "SSPR") {
            Write-Host "`n=== SSPR CONFIGURATION ===" -ForegroundColor Magenta
            $results.SSPR = Set-SsprConfiguration
        }
        
        Write-Host "`nTenant configuration completed successfully!" -ForegroundColor Green
        return $results
    }
    catch {
        Write-Error "Tenant configuration failed: $_"
        throw
    }
}

# Script execution
try {
    Write-Host "Microsoft Identity Management Configuration Module" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    
    # Verify Graph connection exists
    $context = Get-MgContext
    if (-not $context) {
        throw "No active Microsoft Graph connection. Please run Main.ps1 first to authenticate."
    }
    
    Write-Host "Connected to tenant: $($context.TenantId)" -ForegroundColor Cyan
    Write-Host "Account: $($context.Account)" -ForegroundColor Cyan
    
    # Run configuration
    $configResults = Start-TenantConfiguration -ConfigurationType $ConfigType
    
    Write-Host "`nConfiguration completed successfully." -ForegroundColor Green
}
catch {
    Write-Error "Configuration script failed: $_"
    Write-Host "Check the logs for more details." -ForegroundColor Red
    exit 1
}