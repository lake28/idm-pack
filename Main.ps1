param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Discovery", "Configuration", "Both")]
    [string]$Mode = "Both"
)

# Install required Microsoft.Graph modules if not present
function Install-GraphModule {
    $RequiredModules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Identity.SignIns",
        "Microsoft.Graph.Identity.DirectoryManagement",
        "Microsoft.Graph.Users",
        "Microsoft.Graph.Reports",
        "Microsoft.Graph.Security"
    )
    
    $ModulesToInstall = @()
    
    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -ListAvailable -Name $Module)) {
            $ModulesToInstall += $Module
        }
        else {
            Write-Host "$Module is already installed." -ForegroundColor Green
        }
    }
    
    if ($ModulesToInstall.Count -gt 0) {
        Write-Host "Installing required Microsoft.Graph modules..." -ForegroundColor Yellow
        foreach ($Module in $ModulesToInstall) {
            Write-Host "Installing $Module..." -ForegroundColor Cyan
            Install-Module -Name $Module -Scope CurrentUser -Force
        }
        Write-Host "All required modules installed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "All required Microsoft.Graph modules are already installed." -ForegroundColor Green
    }
}

# Connect to Microsoft Graph with required permissions
function Connect-ToGraph {
    try {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        
        # Required permissions for the runbook
        $RequiredScopes = @(
            "Policy.Read.All",
            "Policy.ReadWrite.ConditionalAccess",
            "Directory.Read.All",
            "Directory.ReadWrite.All",
            "User.ReadWrite.All",
            "SecurityEvents.Read.All",
            "AuditLog.Read.All",
            "Reports.Read.All"
        )
        
        Connect-MgGraph -Scopes $RequiredScopes
        
        # Test connection
        $context = Get-MgContext
        if ($context) {
            Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
            Write-Host "Tenant: $($context.TenantId)" -ForegroundColor Cyan
            Write-Host "Account: $($context.Account)" -ForegroundColor Cyan
            return $true
        }
        else {
            throw "Failed to establish Graph connection"
        }
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        return $false
    }
}

# Test Graph connection by reading basic tenant information
function Test-GraphConnection {
    try {
        Write-Host "Testing Graph connection..." -ForegroundColor Yellow
        
        # Test 1: Get organization info
        Write-Host "Testing organization access..." -ForegroundColor Cyan
        $org = Get-MgOrganization
        if ($org) {
            Write-Host "Organization: $($org.DisplayName)" -ForegroundColor Green
            Write-Host "Domain: $($org.VerifiedDomains[0].Name)" -ForegroundColor Green
        }
        
        # Test 2: Get user count
        Write-Host "Testing user access..." -ForegroundColor Cyan
        $userCount = (Get-MgUser -Top 1 -CountVariable count).Count
        Write-Host "User access verified (found $userCount users)" -ForegroundColor Green
        
        # Test 3: Get conditional access policies count
        Write-Host "Testing conditional access policy access..." -ForegroundColor Cyan
        $caCount = (Get-MgIdentityConditionalAccessPolicy -Top 1 -CountVariable count).Count
        Write-Host "Conditional Access policy access verified (found $caCount policies)" -ForegroundColor Green
        
        Write-Host "All connection tests passed!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Connection test failed: $_"
        return $false
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "Microsoft Identity Management Runbook Automation" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Select an option:" -ForegroundColor Cyan
    Write-Host "1. Discovery Only" -ForegroundColor White
    Write-Host "2. Configuration Only" -ForegroundColor White
    Write-Host "3. Both Discovery and Configuration" -ForegroundColor White
    Write-Host "4. Exit" -ForegroundColor White
    Write-Host ""
}

function Start-Discovery {
    try {
        Write-Host "Starting Discovery..." -ForegroundColor Green
        
        # Load and execute discovery script
        . .\Discovery.ps1
        $discoveryResults = Start-TenantDiscovery
        
        Write-Host "Discovery completed successfully." -ForegroundColor Green
        return $discoveryResults
    }
    catch {
        Write-Error "Discovery failed: $_"
        throw
    }
}

function Start-Configuration {
    try {
        Write-Host "Starting Configuration..." -ForegroundColor Green
        # Configuration script will be implemented later
        Write-Host "Configuration completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Configuration failed: $_"
        throw
    }
}

try {
    Write-Host "Microsoft Identity Management Runbook Automation" -ForegroundColor Green
    Write-Host "You will be prompted to sign in with your credentials" -ForegroundColor Yellow
    
    # Install Graph module and connect
    Install-GraphModule
    if (-not (Connect-ToGraph)) {
        throw "Failed to connect to Microsoft Graph"
    }
    
    # Test the connection
    if (-not (Test-GraphConnection)) {
        throw "Graph connection test failed"
    }
    
    if ($Mode -eq "Discovery") {
        Start-Discovery
    }
    elseif ($Mode -eq "Configuration") {
        Start-Configuration
    }
    elseif ($Mode -eq "Both") {
        if (-not $PSBoundParameters.ContainsKey('Mode')) {
            do {
                Show-Menu
                $choice = Read-Host "Enter your choice (1-4)"
                
                switch ($choice) {
                    "1" { Start-Discovery }
                    "2" { Start-Configuration }
                    "3" { 
                        Start-Discovery
                        Start-Configuration
                    }
                    "4" { 
                        Write-Host "Exiting..." -ForegroundColor Yellow
                        exit 0
                    }
                    default { 
                        Write-Host "Invalid choice. Please select 1-4." -ForegroundColor Red
                        Start-Sleep -Seconds 2
                    }
                }
            } while ($choice -ne "4" -and $choice -notin @("1", "2", "3"))
        }
        else {
            Start-Discovery
            Start-Configuration
        }
    }
    
    Write-Host "Script completed successfully." -ForegroundColor Green
}
catch {
    Write-Error "Script failed: $_"
    Write-Host "Check the logs for more details." -ForegroundColor Red
    exit 1
}