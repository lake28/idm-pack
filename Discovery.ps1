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
        
        $authMethodsPolicy = Get-MgPolicyAuthenticationMethodPolicy
        $authMethods = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration -All
        
        $methodsData = [PSCustomObject]@{
            Policy = $authMethodsPolicy
            Methods = $authMethods | Select-Object Id, State, IncludeTargets, ExcludeTargets
        }
        
        Write-Host "Authentication methods retrieved" -ForegroundColor Green
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
        
        Write-Host "Organizational branding retrieved" -ForegroundColor Green
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
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            position: relative;
            overflow: hidden;
        }
        .header::before {
            content: '';
            position: absolute;
            top: -50%;
            left: -50%;
            width: 200%;
            height: 200%;
            background: repeating-linear-gradient(
                45deg,
                transparent,
                transparent 10px,
                rgba(255,255,255,0.1) 10px,
                rgba(255,255,255,0.1) 20px
            );
            animation: slide 20s linear infinite;
        }
        @keyframes slide {
            0% { transform: translateX(-50px); }
            100% { transform: translateX(50px); }
        }
        .logo {
            position: absolute;
            top: 20px;
            left: 20px;
            font-size: 24px;
            font-weight: bold;
            background: white;
            color: #667eea;
            padding: 10px 20px;
            border-radius: 5px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header-content {
            position: relative;
            z-index: 1;
            margin-left: 160px;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
            font-weight: 300;
        }
        .header p {
            margin: 10px 0 0 0;
            font-size: 16px;
            opacity: 0.9;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .section {
            background: white;
            padding: 25px;
            margin-bottom: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            border-left: 4px solid #667eea;
        }
        .section h2 {
            color: #667eea;
            margin-top: 0;
            margin-bottom: 20px;
            font-size: 22px;
            border-bottom: 2px solid #f0f0f0;
            padding-bottom: 10px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .info-item {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            border-left: 3px solid #667eea;
        }
        .info-item strong {
            color: #667eea;
            display: block;
            margin-bottom: 5px;
        }
        .table-container {
            overflow-x: auto;
            margin-top: 20px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            font-weight: 600;
        }
        tr:hover {
            background-color: #f8f9fa;
        }
        .status-enabled {
            color: #28a745;
            font-weight: bold;
        }
        .status-disabled {
            color: #dc3545;
            font-weight: bold;
        }
        .score-container {
            display: flex;
            align-items: center;
            gap: 20px;
            margin: 20px 0;
        }
        .score-circle {
            width: 120px;
            height: 120px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            font-size: 24px;
            font-weight: bold;
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">PAX8</div>
            <div class="header-content">
                <h1>Microsoft Identity Management Discovery Report</h1>
                <p>Generated on $(Get-Date -Format "MMMM dd, yyyy 'at' hh:mm tt")</p>
            </div>
        </div>
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
                    $($score.CurrentScore)/$($score.MaxScore)
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
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Method ID</th>
                            <th>State</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($method in $authMethods.Methods) {
            $statusClass = if ($method.State -eq "enabled") { "status-enabled" } else { "status-disabled" }
            $html += @"
                        <tr>
                            <td>$($method.Id)</td>
                            <td><span class="$statusClass">$($method.State)</span></td>
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
        $html += @"
        <div class="section">
            <h2>Failed Sign-in Attempts (Last 7 Days)</h2>
            <p>Found $($Data.SignInLogs.Count) failed sign-in attempts</p>
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

    # Footer
    $html += @"
        <div class="footer">
            <p>Microsoft Identity Management Discovery Report - Generated by PAX8 IDM Pack</p>
            <p>This report contains sensitive information and should be handled according to your organization's security policies.</p>
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