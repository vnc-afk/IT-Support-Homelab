# ============================================================
# WINDOWS 10 POST-DEPLOYMENT CONFIGURATION SCRIPT
# ============================================================
#
# Purpose:
#   - Check administrator privileges
#   - Enable built-in local Administrator
#   - Set local Administrator password
#   - Rename computer to DESKTOP-XXXXX
#   - Configure Windows Time
#   - Enable Remote Desktop
#   - Disable sleep on AC power
#   - Remove selected unnecessary apps
#   - Install Windows Updates
#   - Test Active Directory connectivity
#   - Join Active Directory domain
#   - Create deployment log
#
# Designed for:
#   Windows 10
#   WDS / MDT deployment
#   Active Directory lab
#
# ============================================================


# ============================================================
# 1. CHECK ADMINISTRATOR PRIVILEGES
# ============================================================

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {

    Write-Host ""
    Write-Host "====================================================" `
        -ForegroundColor Red

    Write-Host "ERROR: Administrator privileges are required." `
        -ForegroundColor Red

    Write-Host "====================================================" `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Run PowerShell as Administrator and execute the script again."
    Write-Host ""

    exit 1
}


# ============================================================
# 2. VARIABLES
# ============================================================

$Domain = "lab.local"

# If you have a dedicated workstation OU, use something like:
#
# $OUPath = "OU=Workstations,DC=lab,DC=local"
#
# If you don't have one, leave this as $null.

$OUPath = $null

$LogPath = "C:\SetupLog.txt"


# ============================================================
# 3. START LOGGING
# ============================================================

Start-Transcript -Path $LogPath -Append


try {

    Write-Host ""
    Write-Host "====================================================" `
        -ForegroundColor Cyan

    Write-Host " WINDOWS 10 POST-DEPLOYMENT CONFIGURATION" `
        -ForegroundColor Cyan

    Write-Host "====================================================" `
        -ForegroundColor Cyan

    Write-Host ""


    # ========================================================
    # 3A. CONFIGURE BUILT-IN LOCAL ADMINISTRATOR
    # ========================================================

    Write-Host ""
    Write-Host "Configuring built-in local Administrator account..." `
        -ForegroundColor Yellow

    try {

        # Get built-in Administrator
        $LocalAdministrator = Get-LocalUser `
            -Name "Administrator" `
            -ErrorAction Stop

        # Enable Administrator if disabled
        if (-not $LocalAdministrator.Enabled) {

            Enable-LocalUser `
                -Name "Administrator"

            Write-Host ""
            Write-Host "Built-in Administrator account enabled." `
                -ForegroundColor Green
        }
        else {

            Write-Host ""
            Write-Host "Built-in Administrator account is already enabled." `
                -ForegroundColor Green
        }

        # Ask for local Administrator password
        Write-Host ""
        Write-Host "===================================================="
        Write-Host " LOCAL ADMINISTRATOR PASSWORD"
        Write-Host "===================================================="
        Write-Host ""
        Write-Host "Set the password for the LOCAL Administrator."
        Write-Host ""
        Write-Host "This is NOT the domain Administrator password."
        Write-Host ""

        $LocalAdminPassword = Read-Host `
            "Enter local Administrator password" `
            -AsSecureString

        # Set password
        Set-LocalUser `
            -Name "Administrator" `
            -Password $LocalAdminPassword `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "Local Administrator password configured successfully." `
            -ForegroundColor Green

        Write-Host ""
        Write-Host "Local Administrator login:"
        Write-Host "    .\Administrator"
        Write-Host ""

    }
    catch {

        Write-Host ""
        Write-Host "ERROR: Could not configure local Administrator." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red

        throw
    }


    # ========================================================
    # 4. COMPUTER INFORMATION
    # ========================================================

    $CurrentName = $env:COMPUTERNAME

    Write-Host "Current computer name: $CurrentName"

    # Generate random 5-digit number
    $RandomNumber = Get-Random `
        -Minimum 10000 `
        -Maximum 99999

    $NewName = "DESKTOP-$RandomNumber"

    Write-Host "New computer name: $NewName"


    # ========================================================
    # 5. RENAME COMPUTER
    # ========================================================

    Write-Host ""
    Write-Host "[1/8] Renaming computer..." `
        -ForegroundColor Yellow

    try {

        Rename-Computer `
            -NewName $NewName `
            -Force `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "Computer successfully renamed to:" `
            -ForegroundColor Green

        Write-Host $NewName `
            -ForegroundColor Green

    }
    catch {

        Write-Host ""
        Write-Host "ERROR: Computer rename failed." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red

        throw
    }


    # ========================================================
    # 6. WINDOWS TIME
    # ========================================================

    Write-Host ""
    Write-Host "[2/8] Configuring Windows Time..." `
        -ForegroundColor Yellow

    try {

        Set-Service `
            -Name W32Time `
            -StartupType Automatic `
            -ErrorAction Stop

        $TimeService = Get-Service `
            -Name W32Time

        if ($TimeService.Status -ne "Running") {

            Start-Service `
                -Name W32Time `
                -ErrorAction Stop
        }

        Write-Host "Windows Time service is running." `
            -ForegroundColor Green

        Write-Host "Attempting time synchronization..."

        $TimeResult = w32tm /resync 2>&1

        Write-Host $TimeResult

        Write-Host "Time synchronization step completed." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "WARNING: Time synchronization failed." `
            -ForegroundColor Yellow

        Write-Host $_.Exception.Message `
            -ForegroundColor Yellow

        Write-Host "Continuing deployment..." `
            -ForegroundColor Yellow
    }


    # ========================================================
    # 7. ENABLE REMOTE DESKTOP
    # ========================================================

    Write-Host ""
    Write-Host "[3/8] Enabling Remote Desktop..." `
        -ForegroundColor Yellow

    try {

        Set-ItemProperty `
            -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
            -Name "fDenyTSConnections" `
            -Value 0 `
            -ErrorAction Stop

        Enable-NetFirewallRule `
            -DisplayGroup "Remote Desktop" `
            -ErrorAction Stop

        Write-Host "Remote Desktop enabled." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "ERROR: Could not enable Remote Desktop." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message `
            -ForegroundColor Red

        throw
    }


    # ========================================================
    # 8. POWER PLAN
    # ========================================================

    Write-Host ""
    Write-Host "[4/8] Configuring power settings..." `
        -ForegroundColor Yellow

    try {

        # Prevent sleep on AC power
        powercfg /change standby-timeout-ac 0

        # Prevent monitor from turning off on AC
        powercfg /change monitor-timeout-ac 0

        # Prevent hibernation timeout on AC
        powercfg /change hibernate-timeout-ac 0

        Write-Host "AC power sleep timeout disabled." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "WARNING: Power configuration failed." `
            -ForegroundColor Yellow

        Write-Host $_.Exception.Message `
            -ForegroundColor Yellow

        Write-Host "Continuing deployment..." `
            -ForegroundColor Yellow
    }


    # ========================================================
    # 9. REMOVE SELECTED UNNECESSARY APPS
    # ========================================================

    Write-Host ""
    Write-Host "[5/8] Removing selected unnecessary apps..." `
        -ForegroundColor Yellow

    $AppsToRemove = @(
        "*Microsoft.BingNews*",
        "*Microsoft.BingWeather*",
        "*Microsoft.GetHelp*",
        "*Microsoft.Getstarted*",
        "*Microsoft.MicrosoftSolitaireCollection*"
    )

    foreach ($App in $AppsToRemove) {

        try {

            $Packages = Get-AppxPackage `
                -AllUsers `
                -Name $App `
                -ErrorAction SilentlyContinue

            if ($Packages) {

                foreach ($Package in $Packages) {

                    Write-Host ""
                    Write-Host "Attempting to remove:"
                    Write-Host $Package.Name

                    try {

                        Remove-AppxPackage `
                            -Package $Package.PackageFullName `
                            -AllUsers `
                            -ErrorAction Stop

                        Write-Host "Removed: $($Package.Name)" `
                            -ForegroundColor Green
                    }
                    catch {

                        Write-Host ""
                        Write-Host "WARNING: Could not remove:" `
                            -ForegroundColor Yellow

                        Write-Host $Package.Name `
                            -ForegroundColor Yellow

                        Write-Host "Reason:" `
                            -ForegroundColor Yellow

                        Write-Host $_.Exception.Message `
                            -ForegroundColor Yellow

                        Write-Host "Continuing..." `
                            -ForegroundColor Yellow
                    }
                }

            }
            else {

                Write-Host "Package not found: $App"
            }

        }
        catch {

            Write-Host ""
            Write-Host "WARNING: Error processing $App" `
                -ForegroundColor Yellow

            Write-Host $_.Exception.Message `
                -ForegroundColor Yellow

            Write-Host "Continuing..." `
                -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "App cleanup completed." `
        -ForegroundColor Green


    # ========================================================
    # 10. WINDOWS UPDATE
    # ========================================================

    Write-Host ""
    Write-Host "[6/8] Installing Windows Updates..." `
        -ForegroundColor Yellow

    try {

        # Check if PSWindowsUpdate exists
        $PSWindowsUpdate = Get-Module `
            -ListAvailable `
            -Name PSWindowsUpdate

        if (-not $PSWindowsUpdate) {

            Write-Host ""
            Write-Host "PSWindowsUpdate module not found."
            Write-Host "Installing required module..."

            # Install NuGet provider
            Install-PackageProvider `
                -Name NuGet `
                -MinimumVersion 2.8.5.201 `
                -Force `
                -ErrorAction Stop

            # Install PSWindowsUpdate
            Install-Module `
                -Name PSWindowsUpdate `
                -Force `
                -Confirm:$false `
                -ErrorAction Stop

            Write-Host "PSWindowsUpdate installed." `
                -ForegroundColor Green
        }

        Import-Module `
            PSWindowsUpdate `
            -Force `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "Searching for Windows Updates..."

        Get-WindowsUpdate `
            -Install `
            -AcceptAll `
            -IgnoreReboot `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "Windows Update completed." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "WARNING: Windows Update failed." `
            -ForegroundColor Yellow

        Write-Host $_.Exception.Message `
            -ForegroundColor Yellow

        Write-Host "Continuing to domain join..." `
            -ForegroundColor Yellow
    }


    # ========================================================
    # 11. TEST DOMAIN CONNECTIVITY
    # ========================================================

    Write-Host ""
    Write-Host "Testing Active Directory connectivity..." `
        -ForegroundColor Yellow

    try {

        $DomainTest = Resolve-DnsName `
            $Domain `
            -ErrorAction Stop

        Write-Host ""
        Write-Host "DNS successfully resolved $Domain." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "WARNING: Could not resolve $Domain." `
            -ForegroundColor Yellow

        Write-Host "Make sure the client's DNS points to your domain controller." `
            -ForegroundColor Yellow

        Write-Host ""
        Write-Host "Example:"
        Write-Host "DNS Server: 192.168.1.100"
        Write-Host ""

        Write-Host "Continuing to domain join..." `
            -ForegroundColor Yellow
    }


    # ========================================================
    # 12. DOMAIN JOIN
    # ========================================================

    Write-Host ""
    Write-Host "[7/8] Joining domain: $Domain" `
        -ForegroundColor Yellow

    Write-Host ""
    Write-Host "Enter an account that has permission to join"
    Write-Host "this computer to $Domain."
    Write-Host ""

    $Credential = Get-Credential


    try {

        if ($null -eq $OUPath) {

            Add-Computer `
                -DomainName $Domain `
                -Credential $Credential `
                -Force `
                -ErrorAction Stop
        }
        else {

            Add-Computer `
                -DomainName $Domain `
                -Credential $Credential `
                -OUPath $OUPath `
                -Force `
                -ErrorAction Stop
        }

        Write-Host ""
        Write-Host "Computer successfully joined to $Domain." `
            -ForegroundColor Green
    }
    catch {

        Write-Host ""
        Write-Host "ERROR: Domain join failed." `
            -ForegroundColor Red

        Write-Host ""
        Write-Host $_.Exception.Message `
            -ForegroundColor Red

        Write-Host ""
        Write-Host "Check:"
        Write-Host "1. DNS points to the domain controller"
        Write-Host "2. DC01 is reachable"
        Write-Host "3. lab.local resolves correctly"
        Write-Host "4. Domain credentials are correct"
        Write-Host "5. The domain controller is running"

        throw
    }


    # ========================================================
    # 13. COMPLETION
    # ========================================================

    Write-Host ""
    Write-Host "[8/8] Deployment configuration completed." `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "====================================================" `
        -ForegroundColor Cyan

    Write-Host " DEPLOYMENT COMPLETE" `
        -ForegroundColor Cyan

    Write-Host "====================================================" `
        -ForegroundColor Cyan

    Write-Host ""
    Write-Host "New Computer Name : $NewName"
    Write-Host "Domain            : $Domain"
    Write-Host "Log File          : $LogPath"

    Write-Host ""
    Write-Host "The computer needs to restart."
    Write-Host ""
    Write-Host "After restart you can use:"
    Write-Host ""
    Write-Host "LOCAL ADMINISTRATOR:"
    Write-Host "    .\Administrator"
    Write-Host ""
    Write-Host "DOMAIN ACCOUNT:"
    Write-Host "    LAB\Username"
    Write-Host ""

}
catch {

    # ========================================================
    # GLOBAL ERROR
    # ========================================================

    Write-Host ""
    Write-Host "====================================================" `
        -ForegroundColor Red

    Write-Host " DEPLOYMENT STOPPED BECAUSE OF AN ERROR" `
        -ForegroundColor Red

    Write-Host "====================================================" `
        -ForegroundColor Red

    Write-Host ""

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Check the deployment log:"
    Write-Host $LogPath

    Write-Host ""
}


# ============================================================
# 14. STOP TRANSCRIPT
# ============================================================

Stop-Transcript


# ============================================================
# 15. RESTART
# ============================================================

Write-Host ""
Write-Host "Restarting computer in 30 seconds..." `
    -ForegroundColor Cyan

Start-Sleep -Seconds 30

Restart-Computer -Force