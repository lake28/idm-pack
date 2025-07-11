# Discovery script for Microsoft Identity Management Runbook
# Gets all tenant information required for assessment

function Get-ConditionalAccessPolicies {
    try {
        Write-Host "Getting Conditional Access policies..." -ForegroundColor Cyan
        $policies = Get-MgIdentityConditionalAccessPolicy -All
        
        $policyData = @()
        foreach ($policy in $policies) {
            $policyData += [PSCustomObject]@{
                Id = $policy.Id
                DisplayName = $policy.DisplayName
                State = $policy.State
                Conditions = $policy.Conditions
                GrantControls = $policy.GrantControls
                SessionControls = $policy.SessionControls
                CreatedDateTime = $policy.CreatedDateTime
                ModifiedDateTime = $policy.ModifiedDateTime
            }
        }
        
        Write-Host "✓ Found $($policies.Count) Conditional Access policies" -ForegroundColor Green
        return $policyData
    }
    catch {
        Write-Error "Failed to get Conditional Access policies: $_"
        return @()
    }
}

function Get-MfaAndSsprStatus {
    try {
        Write-Host "Checking MFA and SSPR status..." -ForegroundColor Cyan
        
        # Get MFA registration details
        $mfaRegistrations = Get-MgReportAuthenticationMethodUserRegistrationDetail -All
        
        # Get SSPR policy
        $ssprPolicy = Get-MgPolicyAuthorizationPolicy
        
        # Get legacy MFA settings
        $mfaSettings = Get-MgDirectorySetting | Where-Object { $_.DisplayName -eq "Password Rule Settings" }
        
        $statusData = [PSCustomObject]@{
            MfaRegistrations = $mfaRegistrations | Select-Object UserPrincipalName, IsMfaRegistered, IsMfaCapable, IsPasswordlessCapable
            SsprEnabled = $ssprPolicy.AllowedToUseSSPR
            SsprPolicy = $ssprPolicy
            LegacyMfaSettings = $mfaSettings
        }
        
        Write-Host "✓ MFA and SSPR status retrieved" -ForegroundColor Green
        return $statusData
    }
    catch {
        Write-Error "Failed to get MFA and SSPR status: $_"
        return $null
    }
}

function Get-AuthenticationMethods {
    try {
        Write-Host "Getting authentication methods..." -ForegroundColor Cyan
        
        $authMethodsPolicy = Get-MgPolicyAuthenticationMethodPolicy
        $authMethods = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -All
        
        $methodsData = [PSCustomObject]@{
            Policy = $authMethodsPolicy
            Methods = $authMethods | Select-Object Id, State, IncludeTargets, ExcludeTargets
        }
        
        Write-Host "✓ Authentication methods retrieved" -ForegroundColor Green
        return $methodsData
    }
    catch {
        Write-Error "Failed to get authentication methods: $_"
        return $null
    }
}

function Get-IdentitySecureScore {
    try {
        Write-Host "Getting Identity Secure Score..." -ForegroundColor Cyan
        
        $secureScores = Get-MgSecuritySecureScore -Top 1
        $scoreControlProfiles = Get-MgSecuritySecureScoreControlProfile -All
        
        $scoreData = [PSCustomObject]@{
            CurrentScore = $secureScores.CurrentScore
            MaxScore = $secureScores.MaxScore
            AverageComparativeScore = $secureScores.AverageComparativeScore
            CreatedDateTime = $secureScores.CreatedDateTime
            ControlProfiles = $scoreControlProfiles | Select-Object Id, Title, Category, Implementation, Score, Rank
        }
        
        Write-Host "✓ Identity Secure Score: $($secureScores.CurrentScore)/$($secureScores.MaxScore)" -ForegroundColor Green
        return $scoreData
    }
    catch {
        Write-Error "Failed to get Identity Secure Score: $_"
        return $null
    }
}

function Get-SignInLogs {
    try {
        Write-Host "Getting sign-in logs (last 7 days, failures only)..." -ForegroundColor Cyan
        
        $startDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $filter = "createdDateTime ge $startDate and (status/errorCode ne 0)"
        
        $signInLogs = Get-MgAuditLogSignIn -Filter $filter -All
        
        $logData = $signInLogs | Select-Object UserPrincipalName, CreatedDateTime, Status, Location, DeviceDetail, AppDisplayName, IpAddress
        
        Write-Host "✓ Found $($signInLogs.Count) failed sign-in attempts in last 7 days" -ForegroundColor Green
        return $logData
    }
    catch {
        Write-Error "Failed to get sign-in logs: $_"
        return @()
    }
}

function Get-OrganizationalBranding {
    try {
        Write-Host "Checking organizational branding..." -ForegroundColor Cyan
        
        $branding = Get-MgOrganizationBranding
        
        $brandingData = [PSCustomObject]@{
            BackgroundColor = $branding.BackgroundColor
            BackgroundImageUrl = $branding.BackgroundImageUrl
            BannerLogoUrl = $branding.BannerLogoUrl
            SignInPageText = $branding.SignInPageText
            SquareLogoUrl = $branding.SquareLogoUrl
            UsernameHintText = $branding.UsernameHintText
            Id = $branding.Id
        }
        
        Write-Host "✓ Organizational branding retrieved" -ForegroundColor Green
        return $brandingData
    }
    catch {
        Write-Error "Failed to get organizational branding: $_"
        return $null
    }
}

function Export-DiscoveryData {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Data
    )
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $fileName = "IDM-Discovery-$timestamp.json"
        
        Write-Host "Exporting discovery data to $fileName..." -ForegroundColor Cyan
        
        $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $fileName -Encoding UTF8
        
        Write-Host "✓ Discovery data exported to $fileName" -ForegroundColor Green
        return $fileName
    }
    catch {
        Write-Error "Failed to export discovery data: $_"
        return $null
    }
}

function Start-TenantDiscovery {
    Write-Host "Starting tenant discovery..." -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
    
    $discoveryData = @{
        Timestamp = Get-Date
        TenantInfo = Get-MgOrganization | Select-Object DisplayName, Id, VerifiedDomains
        ConditionalAccessPolicies = Get-ConditionalAccessPolicies
        MfaAndSsprStatus = Get-MfaAndSsprStatus
        AuthenticationMethods = Get-AuthenticationMethods
        IdentitySecureScore = Get-IdentitySecureScore
        SignInLogs = Get-SignInLogs
        OrganizationalBranding = Get-OrganizationalBranding
    }
    
    $exportFile = Export-DiscoveryData -Data $discoveryData
    
    Write-Host ""
    Write-Host "Discovery completed successfully!" -ForegroundColor Green
    Write-Host "Data exported to: $exportFile" -ForegroundColor Yellow
    
    return $discoveryData
}