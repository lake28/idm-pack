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
        
        Write-Host "Found $($policies.Count) Conditional Access policies" -ForegroundColor Green
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
        
        # Count MFA-capable users
        $mfaCapableCount = ($mfaRegistrations | Where-Object { $_.IsMfaCapable -eq $true }).Count
        $mfaRegisteredCount = ($mfaRegistrations | Where-Object { $_.IsMfaRegistered -eq $true }).Count
        $totalUsers = $mfaRegistrations.Count
        
        $statusData = [PSCustomObject]@{
            MfaRegistrations = $mfaRegistrations | Select-Object UserPrincipalName, IsMfaRegistered, IsMfaCapable, IsPasswordlessCapable
            SsprEnabled = $ssprPolicy.AllowedToUseSSPR
            SsprPolicy = $ssprPolicy | Select-Object AllowedToUseSSPR, AllowInvitesFrom, BlockMsolPowerShell
            MfaStats = [PSCustomObject]@{
                TotalUsers = $totalUsers
                MfaCapableUsers = $mfaCapableCount
                MfaRegisteredUsers = $mfaRegisteredCount
                MfaCapablePercentage = if ($totalUsers -gt 0) { [math]::Round(($mfaCapableCount / $totalUsers) * 100, 2) } else { 0 }
                MfaRegisteredPercentage = if ($totalUsers -gt 0) { [math]::Round(($mfaRegisteredCount / $totalUsers) * 100, 2) } else { 0 }
            }
        }
        
        Write-Host "MFA and SSPR status retrieved" -ForegroundColor Green
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
        
        # Get the main authentication methods policy
        $authMethodsPolicy = Get-MgPolicyAuthenticationMethodPolicy
        
        # Get individual authentication method configurations
        $authMethods = @()
        $methodTypes = @("microsoftAuthenticator", "fido2", "temporaryAccessPass", "email", "softwareOath")
        
        foreach ($methodType in $methodTypes) {
            try {
                $method = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -AuthenticationMethodConfigurationId $methodType
                if ($method) {
                    $authMethods += $method
                }
            }
            catch {
                # Method might not exist or be accessible, continue with others
                Write-Host "  - ${methodType}: Not configured or accessible" -ForegroundColor Gray
            }
        }
        
        $methodsData = [PSCustomObject]@{
            Policy = $authMethodsPolicy | Select-Object Id, DisplayName, Description, PolicyVersion, ReconfirmationInDays
            Methods = $authMethods | Select-Object Id, State, "@odata.type"
            MethodCount = $authMethods.Count
            EnabledMethods = ($authMethods | Where-Object { $_.State -eq "enabled" }).Count
        }
        
        Write-Host "Authentication methods retrieved ($($authMethods.Count) methods found)" -ForegroundColor Green
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
        
        Write-Host "Identity Secure Score: $($secureScores.CurrentScore)/$($secureScores.MaxScore)" -ForegroundColor Green
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
        
        Write-Host "Found $($signInLogs.Count) failed sign-in attempts in last 7 days" -ForegroundColor Green
        return $logData
    }
    catch {
        Write-Error "Failed to get sign-in logs: $_"
        return @()
    }
}

function Get-OrganizationalBranding {
    Write-Host "Checking organizational branding..." -ForegroundColor Cyan
    
    try {
        # Get organization ID first
        Write-Host "Getting organization ID..." -ForegroundColor Gray
        $org = Get-MgOrganization
        $organizationId = $org.Id
        Write-Host "Organization ID: $organizationId" -ForegroundColor Gray
        
        # Use the correct cmdlet to get branding localizations
        Write-Host "Getting branding localizations..." -ForegroundColor Gray
        $brandingLocalizations = Get-MgOrganizationBrandingLocalization -OrganizationId $organizationId
        
        $brandingData = [PSCustomObject]@{
            BackgroundColor = $null
            BackgroundImageUrl = $null
            BannerLogoUrl = $null
            SignInPageText = $null
            SquareLogoUrl = $null
            UsernameHintText = $null
            Id = $null
            LocaleId = $null
            HasBranding = $false
            RawData = $null
            LocalizationsCount = 0
            Localizations = @()
        }
        
        if ($brandingLocalizations -and $brandingLocalizations.Count -gt 0) {
            Write-Host "SUCCESS: Found $($brandingLocalizations.Count) branding localizations!" -ForegroundColor Green
            
            $brandingData.LocalizationsCount = $brandingLocalizations.Count
            $brandingData.Localizations = $brandingLocalizations
            
            # Use the first localization (usually default with ID "0")
            $defaultBranding = $brandingLocalizations[0]
            
            # Check if we have actual branding data - use correct property names (camelCase)
            $hasBrandingData = $false
            if ($defaultBranding.backgroundColor -or 
                $defaultBranding.backgroundImageRelativeUrl -or 
                $defaultBranding.bannerLogoRelativeUrl -or 
                $defaultBranding.signInPageText -or 
                $defaultBranding.squareLogoRelativeUrl -or 
                $defaultBranding.usernameHintText) {
                $hasBrandingData = $true
            }
            
            $brandingData.BackgroundColor = $defaultBranding.backgroundColor
            $brandingData.BackgroundImageUrl = $defaultBranding.backgroundImageRelativeUrl
            $brandingData.BannerLogoUrl = $defaultBranding.bannerLogoRelativeUrl
            $brandingData.SignInPageText = $defaultBranding.signInPageText
            $brandingData.SquareLogoUrl = $defaultBranding.squareLogoRelativeUrl
            $brandingData.UsernameHintText = $defaultBranding.usernameHintText
            $brandingData.Id = $defaultBranding.Id
            $brandingData.LocaleId = $defaultBranding.Id  # The ID field contains the locale
            $brandingData.HasBranding = $hasBrandingData
            $brandingData.RawData = $defaultBranding
            
            # Show detailed results
            Write-Host "=== BRANDING LOCALIZATIONS FOUND ===" -ForegroundColor Cyan
            Write-Host "Total Localizations: $($brandingLocalizations.Count)" -ForegroundColor White
            
            foreach ($localization in $brandingLocalizations) {
                Write-Host "--- Localization ID: $($localization.Id) ---" -ForegroundColor Yellow
                Write-Host "  Background Color: '$($localization.backgroundColor)'" -ForegroundColor White
                Write-Host "  Background Image: '$($localization.backgroundImageRelativeUrl)'" -ForegroundColor White
                Write-Host "  Sign-in Page Text: '$($localization.signInPageText)'" -ForegroundColor White
                Write-Host "  Banner Logo: '$($localization.bannerLogoRelativeUrl)'" -ForegroundColor White
                Write-Host "  Square Logo: '$($localization.squareLogoRelativeUrl)'" -ForegroundColor White
                Write-Host "  Username Hint: '$($localization.usernameHintText)'" -ForegroundColor White
            }
            
            Write-Host "Using Default Localization: $($defaultBranding.Id)" -ForegroundColor Green
            Write-Host "Has Branding Data: $hasBrandingData" -ForegroundColor Green
            Write-Host "=================================" -ForegroundColor Cyan
        }
        else {
            Write-Host "No branding localizations found" -ForegroundColor Yellow
        }
        
        return $brandingData
    }
    catch {
        Write-Host "Error accessing branding API: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "This may be due to insufficient permissions or no branding configured" -ForegroundColor Yellow
        
        return [PSCustomObject]@{
            BackgroundColor = $null
            BackgroundImageUrl = $null
            BannerLogoUrl = $null
            SignInPageText = $null
            SquareLogoUrl = $null
            UsernameHintText = $null
            Id = $null
            LocaleId = $null
            HasBranding = $false
            Error = $_.Exception.Message
            RawData = $null
            LocalizationsCount = 0
            Localizations = @()
        }
    }
}

function Export-DiscoveryData {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Data
    )
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $jsonFileName = "IDM-Discovery-$timestamp.json"
        $htmlFileName = "IDM-Discovery-$timestamp.html"
        
        Write-Host "Exporting discovery data to JSON and HTML..." -ForegroundColor Cyan
        
        # Export JSON
        $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFileName -Encoding UTF8
        
        # Export HTML
        $htmlContent = Generate-HtmlReport -Data $Data -Timestamp $timestamp
        $htmlContent | Out-File -FilePath $htmlFileName -Encoding UTF8
        
        Write-Host "Discovery data exported to $jsonFileName and $htmlFileName" -ForegroundColor Green
        return @{
            JsonFile = $jsonFileName
            HtmlFile = $htmlFileName
        }
    }
    catch {
        Write-Error "Failed to export discovery data: $_"
        return $null
    }
}

function Generate-HtmlReport {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Data,
        [Parameter(Mandatory = $true)]
        [string]$Timestamp
    )
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Microsoft Identity Management Discovery Report</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;600&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Poppins', sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #000000;
            color: #ffffff;
            line-height: 1.6;
        }
        .header {
            background: linear-gradient(135deg, #2E5BFF 0%, #00D4AA 25%, #8B5CF6 50%, #EC4899 75%, #F59E0B 100%);
            color: white;
            padding: 40px;
            border-radius: 15px;
            margin-bottom: 30px;
            position: relative;
            overflow: hidden;
        }
        .header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.1);
            backdrop-filter: blur(10px);
        }
        .logo {
            position: absolute;
            top: 20px;
            left: 20px;
            font-size: 32px;
            font-weight: 600;
            font-family: 'Poppins', sans-serif;
            color: white;
            text-transform: lowercase;
            z-index: 2;
        }
        .header-content {
            position: relative;
            z-index: 1;
            margin-left: 120px;
        }
        .header h1 {
            margin: 0;
            font-size: 32px;
            font-weight: 600;
            font-family: 'Poppins', sans-serif;
        }
        .header p {
            margin: 10px 0 0 0;
            font-size: 16px;
            opacity: 0.9;
            font-weight: 400;
        }
        .version-tag {
            position: absolute;
            top: 20px;
            right: 20px;
            background: rgba(255,255,255,0.2);
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: 400;
            backdrop-filter: blur(10px);
            z-index: 2;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .section {
            background: rgba(255,255,255,0.05);
            padding: 30px;
            margin-bottom: 25px;
            border-radius: 15px;
            border: 1px solid rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
        }
        .section h2 {
            color: #2E5BFF;
            margin-top: 0;
            margin-bottom: 25px;
            font-size: 24px;
            font-weight: 600;
            font-family: 'Poppins', sans-serif;
            border-bottom: 2px solid rgba(46,91,255,0.3);
            padding-bottom: 10px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .info-item {
            background: rgba(255,255,255,0.03);
            padding: 20px;
            border-radius: 10px;
            border-left: 4px solid #00D4AA;
            backdrop-filter: blur(5px);
        }
        .info-item strong {
            color: #00D4AA;
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
        }
        .table-container {
            overflow-x: auto;
            margin-top: 20px;
            border-radius: 10px;
            border: 1px solid rgba(255,255,255,0.1);
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 15px;
            text-align: left;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        th {
            background: linear-gradient(135deg, #2E5BFF 0%, #8B5CF6 100%);
            color: white;
            font-weight: 600;
            font-family: 'Poppins', sans-serif;
        }
        tr:hover {
            background-color: rgba(255,255,255,0.05);
        }
        .status-enabled {
            color: #00D4AA;
            font-weight: 600;
        }
        .status-disabled {
            color: #EC4899;
            font-weight: 600;
        }
        .score-container {
            display: flex;
            align-items: center;
            gap: 30px;
            margin: 20px 0;
        }
        .score-circle {
            width: 140px;
            height: 140px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #2E5BFF 0%, #00D4AA 50%, #8B5CF6 100%);
            color: white;
            font-size: 24px;
            font-weight: 600;
            box-shadow: 0 8px 25px rgba(46,91,255,0.3);
            position: relative;
        }
        .score-circle::before {
            content: '';
            position: absolute;
            inset: 3px;
            border-radius: 50%;
            background: #000000;
            z-index: 1;
        }
        .score-circle span {
            position: relative;
            z-index: 2;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 30px;
            color: rgba(255,255,255,0.7);
            font-size: 14px;
            border-top: 1px solid rgba(255,255,255,0.1);
        }
        .gradient-bar {
            height: 4px;
            background: linear-gradient(90deg, #2E5BFF 0%, #00D4AA 25%, #8B5CF6 50%, #EC4899 75%, #F59E0B 100%);
            border-radius: 2px;
            margin: 20px 0;
        }
        .charts-container {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 30px;
            margin: 30px 0;
        }
        .chart-section {
            background: rgba(255,255,255,0.03);
            padding: 20px;
            border-radius: 10px;
            border: 1px solid rgba(255,255,255,0.1);
        }
        .chart-section h3 {
            color: #00D4AA;
            margin: 0 0 20px 0;
            font-size: 18px;
            font-weight: 600;
        }
        .chart-bars {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        .chart-bar {
            display: flex;
            flex-direction: column;
            gap: 5px;
        }
        .bar-label {
            font-size: 14px;
            color: rgba(255,255,255,0.8);
            font-weight: 500;
        }
        .bar-container {
            position: relative;
            height: 30px;
            background: rgba(255,255,255,0.1);
            border-radius: 15px;
            overflow: hidden;
        }
        .bar-fill {
            height: 100%;
            background: linear-gradient(90deg, #2E5BFF 0%, #00D4AA 100%);
            border-radius: 15px;
            transition: width 0.3s ease;
        }
        .bar-value {
            position: absolute;
            right: 10px;
            top: 50%;
            transform: translateY(-50%);
            color: white;
            font-weight: 600;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">pax8</div>
            <div class="version-tag">Identity Management // v.01</div>
            <div class="header-content">
                <h1>Microsoft Identity Management Discovery Report</h1>
                <p>Generated on $(Get-Date -Format "MMMM dd, yyyy 'at' hh:mm tt")</p>
            </div>
        </div>
        <div class="gradient-bar"></div>
"@

    # Tenant Information Section
    $tenantInfo = $Data.TenantInfo
    $html += @"
        <div class="section">
            <h2>Tenant Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <strong>Organization Name</strong>
                    $($tenantInfo.DisplayName)
                </div>
                <div class="info-item">
                    <strong>Tenant ID</strong>
                    $($tenantInfo.Id)
                </div>
                <div class="info-item">
                    <strong>Primary Domain</strong>
                    $($tenantInfo.VerifiedDomains[0].Name)
                </div>
                <div class="info-item">
                    <strong>Report Generated</strong>
                    $($Data.Timestamp.ToString("yyyy-MM-dd HH:mm:ss"))
                </div>
            </div>
        </div>
"@

    # Identity Secure Score Section
    if ($Data.IdentitySecureScore) {
        $score = $Data.IdentitySecureScore
        $html += @"
        <div class="section">
            <h2>Identity Secure Score</h2>
            <div class="score-container">
                <div class="score-circle">
                    <span>$($score.CurrentScore)/$($score.MaxScore)</span>
                </div>
                <div>
                    <p><strong>Current Score:</strong> $($score.CurrentScore) out of $($score.MaxScore)</p>
                    <p><strong>Average Comparative Score:</strong> $($score.AverageComparativeScore)</p>
                    <p><strong>Last Updated:</strong> $($score.CreatedDateTime)</p>
                </div>
            </div>
        </div>
"@
    }

    # Conditional Access Policies Section
    if ($Data.ConditionalAccessPolicies) {
        $html += @"
        <div class="section">
            <h2>Conditional Access Policies</h2>
            <p>Found $($Data.ConditionalAccessPolicies.Count) Conditional Access policies</p>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Policy Name</th>
                            <th>State</th>
                            <th>Created</th>
                            <th>Modified</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($policy in $Data.ConditionalAccessPolicies) {
            $statusClass = if ($policy.State -eq "enabled") { "status-enabled" } else { "status-disabled" }
            $html += @"
                        <tr>
                            <td>$($policy.DisplayName)</td>
                            <td><span class="$statusClass">$($policy.State)</span></td>
                            <td>$($policy.CreatedDateTime)</td>
                            <td>$($policy.ModifiedDateTime)</td>
                        </tr>
"@
        }
        $html += @"
                    </tbody>
                </table>
            </div>
        </div>
"@
    }

    # MFA and SSPR Status Section
    if ($Data.MfaAndSsprStatus) {
        $mfaStatus = $Data.MfaAndSsprStatus
        $html += @"
        <div class="section">
            <h2>MFA and SSPR Status</h2>
            <div class="info-grid">
                <div class="info-item">
                    <strong>SSPR Enabled</strong>
                    $($mfaStatus.SsprEnabled)
                </div>
                <div class="info-item">
                    <strong>Total Users</strong>
                    $($mfaStatus.MfaStats.TotalUsers)
                </div>
                <div class="info-item">
                    <strong>MFA Capable Users</strong>
                    $($mfaStatus.MfaStats.MfaCapableUsers) ($($mfaStatus.MfaStats.MfaCapablePercentage)%)
                </div>
                <div class="info-item">
                    <strong>MFA Registered Users</strong>
                    $($mfaStatus.MfaStats.MfaRegisteredUsers) ($($mfaStatus.MfaStats.MfaRegisteredPercentage)%)
                </div>
            </div>
        </div>
"@
    }

    # Authentication Methods Section
    if ($Data.AuthenticationMethods) {
        $authMethods = $Data.AuthenticationMethods
        $html += @"
        <div class="section">
            <h2>Authentication Methods</h2>
            <div class="info-grid">
                <div class="info-item">
                    <strong>Total Methods</strong>
                    $($authMethods.MethodCount)
                </div>
                <div class="info-item">
                    <strong>Enabled Methods</strong>
                    $($authMethods.EnabledMethods)
                </div>
                <div class="info-item">
                    <strong>Policy Version</strong>
                    $($authMethods.Policy.PolicyVersion)
                </div>
                <div class="info-item">
                    <strong>Reconfirmation Days</strong>
                    $($authMethods.Policy.ReconfirmationInDays)
                </div>
            </div>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Method Type</th>
                            <th>State</th>
                            <th>Configuration Type</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($method in $authMethods.Methods) {
            $statusClass = if ($method.State -eq "enabled") { "status-enabled" } else { "status-disabled" }
            $methodType = $method."@odata.type" -replace "#microsoft.graph.", ""
            $html += @"
                        <tr>
                            <td>$($method.Id)</td>
                            <td><span class="$statusClass">$($method.State)</span></td>
                            <td>$methodType</td>
                        </tr>
"@
        }
        $html += @"
                    </tbody>
                </table>
            </div>
        </div>
"@
    }

    # Sign-in Logs Section
    if ($Data.SignInLogs) {
        # Calculate statistics
        $totalFailures = $Data.SignInLogs.Count
        $uniqueUsers = ($Data.SignInLogs | Select-Object -Unique UserPrincipalName).Count
        $uniqueIPs = ($Data.SignInLogs | Select-Object -Unique IpAddress).Count
        $uniqueApps = ($Data.SignInLogs | Select-Object -Unique AppDisplayName).Count
        
        # Top failures by user
        $topUsers = $Data.SignInLogs | Group-Object UserPrincipalName | Sort-Object Count -Descending | Select-Object -First 5
        
        # Top failures by IP
        $topIPs = $Data.SignInLogs | Group-Object IpAddress | Sort-Object Count -Descending | Select-Object -First 5
        
        # Top failures by app
        $topApps = $Data.SignInLogs | Group-Object AppDisplayName | Sort-Object Count -Descending | Select-Object -First 5
        
        $html += @"
        <div class="section">
            <h2>Failed Sign-in Attempts (Last 7 Days)</h2>
            
            <!-- Summary Statistics -->
            <div class="info-grid">
                <div class="info-item">
                    <strong>Total Failed Attempts</strong>
                    $totalFailures
                </div>
                <div class="info-item">
                    <strong>Unique Users Affected</strong>
                    $uniqueUsers
                </div>
                <div class="info-item">
                    <strong>Unique IP Addresses</strong>
                    $uniqueIPs
                </div>
                <div class="info-item">
                    <strong>Unique Applications</strong>
                    $uniqueApps
                </div>
            </div>
            
            <!-- Visual Charts -->
            <div class="charts-container">
                <div class="chart-section">
                    <h3>Top 5 Users by Failed Attempts</h3>
                    <div class="chart-bars">
"@
        foreach ($user in $topUsers) {
            $percentage = [math]::Round(($user.Count / $totalFailures) * 100, 1)
            $html += @"
                        <div class="chart-bar">
                            <div class="bar-label">$($user.Name)</div>
                            <div class="bar-container">
                                <div class="bar-fill" style="width: $($percentage)%"></div>
                                <div class="bar-value">$($user.Count)</div>
                            </div>
                        </div>
"@
        }
        $html += @"
                    </div>
                </div>
                
                <div class="chart-section">
                    <h3>Top 5 IP Addresses by Failed Attempts</h3>
                    <div class="chart-bars">
"@
        foreach ($ip in $topIPs) {
            $percentage = [math]::Round(($ip.Count / $totalFailures) * 100, 1)
            $html += @"
                        <div class="chart-bar">
                            <div class="bar-label">$($ip.Name)</div>
                            <div class="bar-container">
                                <div class="bar-fill" style="width: $($percentage)%"></div>
                                <div class="bar-value">$($ip.Count)</div>
                            </div>
                        </div>
"@
        }
        $html += @"
                    </div>
                </div>
                
                <div class="chart-section">
                    <h3>Top 5 Applications by Failed Attempts</h3>
                    <div class="chart-bars">
"@
        foreach ($app in $topApps) {
            $percentage = [math]::Round(($app.Count / $totalFailures) * 100, 1)
            $html += @"
                        <div class="chart-bar">
                            <div class="bar-label">$($app.Name)</div>
                            <div class="bar-container">
                                <div class="bar-fill" style="width: $($percentage)%"></div>
                                <div class="bar-value">$($app.Count)</div>
                            </div>
                        </div>
"@
        }
        $html += @"
                    </div>
                </div>
            </div>
            
            <!-- Detailed Table -->
            <h3>Recent Failed Attempts (Last 50)</h3>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>User</th>
                            <th>Date/Time</th>
                            <th>Application</th>
                            <th>IP Address</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($log in $Data.SignInLogs | Select-Object -First 50) {
            $html += @"
                        <tr>
                            <td>$($log.UserPrincipalName)</td>
                            <td>$($log.CreatedDateTime)</td>
                            <td>$($log.AppDisplayName)</td>
                            <td>$($log.IpAddress)</td>
                        </tr>
"@
        }
        $html += @"
                    </tbody>
                </table>
            </div>
        </div>
"@
    }

    # Organizational Branding Section
    if ($Data.OrganizationalBranding) {
        $branding = $Data.OrganizationalBranding
        $html += @"
        <div class="section">
            <h2>Organizational Branding</h2>
            <div class="info-grid">
                <div class="info-item">
                    <strong>Branding Configured</strong>
                    $(if ($branding.HasBranding) { "Yes" } else { "No" })
                </div>
                <div class="info-item">
                    <strong>Background Color</strong>
                    $(if ($branding.BackgroundColor) { $branding.BackgroundColor } else { "Not configured" })
                </div>
                <div class="info-item">
                    <strong>Banner Logo</strong>
                    $(if ($branding.BannerLogoUrl) { "Configured" } else { "Not configured" })
                </div>
                <div class="info-item">
                    <strong>Square Logo</strong>
                    $(if ($branding.SquareLogoUrl) { "Configured" } else { "Not configured" })
                </div>
                <div class="info-item">
                    <strong>Background Image</strong>
                    $(if ($branding.BackgroundImageUrl) { "Configured" } else { "Not configured" })
                </div>
                <div class="info-item">
                    <strong>Custom Sign-in Text</strong>
                    $(if ($branding.SignInPageText) { "Configured" } else { "Not configured" })
                </div>
                <div class="info-item">
                    <strong>Username Hint</strong>
                    $(if ($branding.UsernameHintText) { $branding.UsernameHintText } else { "Not configured" })
                </div>
                <div class="info-item">
                    <strong>Branding ID</strong>
                    $(if ($branding.Id) { $branding.Id } else { "N/A" })
                </div>
            </div>
            $(if ($branding.SignInPageText) { 
                "<div class='info-item' style='margin-top: 20px; grid-column: 1 / -1;'>
                    <strong>Sign-in Page Text</strong><br>
                    $($branding.SignInPageText)
                </div>" 
            } else { "" })
        </div>
"@
    }

    # Footer
    $html += @"
        <div class="gradient-bar"></div>
        <div class="footer">
            <p><strong>Microsoft Identity Management Discovery Report</strong></p>
            <p>This report contains sensitive information and should be handled according to your organization's security policies.</p>
            <p>Copyright ©2025 Pax8 | All rights reserved</p>
        </div>
    </div>
</body>
</html>
"@

    return $html
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
    
    $exportFiles = Export-DiscoveryData -Data $discoveryData
    
    Write-Host ""
    Write-Host "Discovery completed successfully!" -ForegroundColor Green
    Write-Host "Data exported to: $($exportFiles.JsonFile)" -ForegroundColor Yellow
    Write-Host "HTML report: $($exportFiles.HtmlFile)" -ForegroundColor Yellow
    
    return $discoveryData
}