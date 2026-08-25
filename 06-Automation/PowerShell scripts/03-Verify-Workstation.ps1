# ============================================================
# 03-Verify-Workstation.ps1
# Workstation / Domain Verification Script
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

# =========================
# START LOGGING
# =========================
$logPath = "C:\WorkstationVerification.txt"

Start-Transcript -Path $logPath -Append

try {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "        WORKSTATION VERIFICATION"
    Write-Host "============================================================"
    Write-Host ""

    # ========================================================
    # VARIABLES
    # ========================================================

    $computerName = $env:COMPUTERNAME

    $computerSystem = Get-CimInstance Win32_ComputerSystem

    $os = Get-CimInstance Win32_OperatingSystem

    $networkAdapters = Get-NetAdapter |
        Where-Object {
            $_.Status -eq "Up" -and
            $_.Virtual -eq $false
        }

    # ========================================================
    # RESULT COUNTERS
    # ========================================================

    $pass = 0
    $fail = 0
    $warning = 0

    # ========================================================
    # FUNCTION - TEST RESULT
    # ========================================================

    function Show-Result {
        param (
            [string]$Test,
            [bool]$Success,
            [string]$Details
        )

        if ($Success) {
            Write-Host "[PASS] $Test : $Details"
            $script:pass++
        }
        else {
            Write-Host "[FAIL] $Test : $Details"
            $script:fail++
        }
    }

    function Show-Warning {
        param (
            [string]$Test,
            [string]$Details
        )

        Write-Host "[WARN] $Test : $Details"
        $script:warning++
    }

    # ========================================================
    # 1. COMPUTER INFORMATION
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "1. COMPUTER INFORMATION"
    Write-Host "------------------------------------------------------------"

    Write-Host "Computer Name : $computerName"
    Write-Host "Windows       : $($os.Caption)"
    Write-Host "Version       : $($os.Version)"
    Write-Host "Build         : $($os.BuildNumber)"
    Write-Host "Manufacturer  : $($computerSystem.Manufacturer)"
    Write-Host "Model         : $($computerSystem.Model)"
    Write-Host ""

    # ========================================================
    # 2. DOMAIN MEMBERSHIP
    # ========================================================

    Write-Host "------------------------------------------------------------"
    Write-Host "2. DOMAIN MEMBERSHIP"
    Write-Host "------------------------------------------------------------"

    $domainName = $computerSystem.Domain
    $partOfDomain = $computerSystem.PartOfDomain

    Write-Host "Domain : $domainName"

    Show-Result `
        -Test "Domain Membership" `
        -Success $partOfDomain `
        -Details $(if ($partOfDomain) {
            "Joined to $domainName"
        } else {
            "Computer is NOT joined to a domain"
        })

    # ========================================================
    # 3. CURRENT USER
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "3. CURRENT USER"
    Write-Host "------------------------------------------------------------"

    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

    Write-Host "Logged-in User : $currentUser"

    # Determine whether local or domain account
    if ($currentUser -match "\\") {

        $userDomain = $currentUser.Split("\")[0]

        if ($userDomain -eq $computerName) {

            Write-Host "Account Type   : LOCAL"

        }
        else {

            Write-Host "Account Type   : DOMAIN"
        }
    }

    # ========================================================
    # 4. IP CONFIGURATION
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "4. NETWORK CONFIGURATION"
    Write-Host "------------------------------------------------------------"

    foreach ($adapter in $networkAdapters) {

        Write-Host ""
        Write-Host "Adapter : $($adapter.Name)"

        $ipInfo = Get-NetIPConfiguration `
            -InterfaceIndex $adapter.ifIndex

        Write-Host "IPv4    : $($ipInfo.IPv4Address.IPAddress)"
        Write-Host "Gateway : $($ipInfo.IPv4DefaultGateway.NextHop)"
        Write-Host "DNS     : $($ipInfo.DnsServer.ServerAddresses -join ', ')"
    }

    # ========================================================
    # 5. DNS CONFIGURATION
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "5. DNS CONFIGURATION"
    Write-Host "------------------------------------------------------------"

    $dnsServers = Get-DnsClientServerAddress `
        -AddressFamily IPv4 |
        Where-Object {
            $_.ServerAddresses.Count -gt 0
        }

    foreach ($dns in $dnsServers) {

        Write-Host "$($dns.InterfaceAlias) : $($dns.ServerAddresses -join ', ')"
    }

    # ========================================================
    # 6. DNS RESOLUTION
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "6. DNS RESOLUTION"
    Write-Host "------------------------------------------------------------"

    if ($partOfDomain) {

        try {

            $dnsTest = Resolve-DnsName `
                -Name $domainName `
                -ErrorAction Stop

            Show-Result `
                -Test "DNS Resolution" `
                -Success $true `
                -Details "$domainName resolved successfully"

        }
        catch {

            Show-Result `
                -Test "DNS Resolution" `
                -Success $false `
                -Details "Unable to resolve $domainName"
        }

    }
    else {

        Show-Warning `
            -Test "DNS Resolution" `
            -Details "Computer is not domain joined"
    }

    # ========================================================
    # 7. DOMAIN CONTROLLER DISCOVERY
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "7. DOMAIN CONTROLLER"
    Write-Host "------------------------------------------------------------"

    if ($partOfDomain) {

        try {

            $dcResult = nltest /dsgetdc:$domainName 2>&1

            if ($LASTEXITCODE -eq 0) {

                Write-Host $dcResult

                Show-Result `
                    -Test "Domain Controller Discovery" `
                    -Success $true `
                    -Details "Domain Controller found"

            }
            else {

                Show-Result `
                    -Test "Domain Controller Discovery" `
                    -Success $false `
                    -Details "Unable to locate Domain Controller"
            }

        }
        catch {

            Show-Result `
                -Test "Domain Controller Discovery" `
                -Success $false `
                -Details "Domain Controller test failed"
        }

    }
    else {

        Show-Warning `
            -Test "Domain Controller Discovery" `
            -Details "Computer is not domain joined"
    }

    # ========================================================
    # 8. DOMAIN TRUST
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "8. DOMAIN TRUST"
    Write-Host "------------------------------------------------------------"

    if ($partOfDomain) {

        try {

            $trustResult = nltest /sc_verify:$domainName 2>&1

            Write-Host $trustResult

            if ($LASTEXITCODE -eq 0) {

                Show-Result `
                    -Test "Domain Trust" `
                    -Success $true `
                    -Details "Secure channel is working"

            }
            else {

                Show-Result `
                    -Test "Domain Trust" `
                    -Success $false `
                    -Details "Secure channel verification failed"
            }

        }
        catch {

            Show-Result `
                -Test "Domain Trust" `
                -Success $false `
                -Details "Domain trust test failed"
        }

    }
    else {

        Show-Warning `
            -Test "Domain Trust" `
            -Details "Computer is not domain joined"
    }

    # ========================================================
    # 9. TIME SYNCHRONIZATION
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "9. TIME SYNCHRONIZATION"
    Write-Host "------------------------------------------------------------"

    $timeStatus = w32tm /query /status 2>&1

    Write-Host $timeStatus

    $timeSource = w32tm /query /source 2>&1

    Write-Host ""
    Write-Host "Time Source: $timeSource"

    if ($timeSource -notmatch "Local CMOS Clock") {

        Show-Result `
            -Test "Time Synchronization" `
            -Success $true `
            -Details "Time service has a configured source"

    }
    else {

        Show-Warning `
            -Test "Time Synchronization" `
            -Details "Using Local CMOS Clock"
    }

    # ========================================================
    # 10. NETWORK CONNECTIVITY TO DOMAIN CONTROLLER
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "10. DOMAIN CONTROLLER CONNECTIVITY"
    Write-Host "------------------------------------------------------------"

    if ($partOfDomain) {

        try {

            $dcInfo = nltest /dsgetdc:$domainName 2>&1

            $dcLine = $dcInfo |
                Where-Object {
                    $_ -match "\\\\"
                } |
                Select-Object -First 1

            if ($dcLine) {

                $dcName = $dcLine.Trim()

                Write-Host "Detected DC: $dcName"

                $pingResult = Test-Connection `
                    -ComputerName $dcName `
                    -Count 2 `
                    -Quiet

                Show-Result `
                    -Test "Domain Controller Ping" `
                    -Success $pingResult `
                    -Details $(if ($pingResult) {
                        "Domain Controller is reachable"
                    } else {
                        "Domain Controller is unreachable"
                    })
            }
            else {

                Show-Result `
                    -Test "Domain Controller Ping" `
                    -Success $false `
                    -Details "Could not determine Domain Controller"
            }

        }
        catch {

            Show-Result `
                -Test "Domain Controller Ping" `
                -Success $false `
                -Details "Connection test failed"
        }

    }
    else {

        Show-Warning `
            -Test "Domain Controller Ping" `
            -Details "Computer is not domain joined"
    }

    # ========================================================
    # 11. REQUIRED AD PORTS
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "11. ACTIVE DIRECTORY PORTS"
    Write-Host "------------------------------------------------------------"

    if ($partOfDomain -and $dcName) {

        $ports = @(
            @{Name="DNS";       Port=53},
            @{Name="Kerberos";  Port=88},
            @{Name="LDAP";      Port=389},
            @{Name="SMB";       Port=445},
            @{Name="RPC";       Port=135}
        )

        foreach ($item in $ports) {

            $portTest = Test-NetConnection `
                -ComputerName $dcName `
                -Port $item.Port `
                -WarningAction SilentlyContinue

            Show-Result `
                -Test "$($item.Name) Port $($item.Port)" `
                -Success $portTest.TcpTestSucceeded `
                -Details $(if ($portTest.TcpTestSucceeded) {
                    "OPEN"
                } else {
                    "CLOSED / BLOCKED"
                })
        }

    }
    else {

        Show-Warning `
            -Test "Active Directory Ports" `
            -Details "Domain Controller unavailable"
    }

    # ========================================================
    # 12. GROUP POLICY
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "12. GROUP POLICY"
    Write-Host "------------------------------------------------------------"

    Write-Host "Running Group Policy Result check..."

    $gpResult = gpresult /r 2>&1

    Write-Host $gpResult

    # Check whether computer GPO information exists
    $computerPolicy = $gpResult |
        Select-String "Applied Group Policy Objects"

    if ($computerPolicy) {

        Show-Result `
            -Test "Group Policy" `
            -Success $true `
            -Details "Group Policy information detected"

    }
    else {

        Show-Warning `
            -Test "Group Policy" `
            -Details "Could not confirm applied GPOs from basic output"
    }

    # ========================================================
    # 13. FIREWALL
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "13. WINDOWS FIREWALL"
    Write-Host "------------------------------------------------------------"

    $firewallProfiles = Get-NetFirewallProfile

    foreach ($profile in $firewallProfiles) {

        Write-Host "$($profile.Name): Enabled = $($profile.Enabled)"

    }

    $allFirewallEnabled = (
        $firewallProfiles.Enabled -notcontains $false
    )

    Show-Result `
        -Test "Windows Firewall" `
        -Success $allFirewallEnabled `
        -Details $(if ($allFirewallEnabled) {
            "All firewall profiles enabled"
        } else {
            "One or more firewall profiles disabled"
        })

    # ========================================================
    # 14. REMOTE DESKTOP
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "14. REMOTE DESKTOP"
    Write-Host "------------------------------------------------------------"

    $rdpValue = Get-ItemProperty `
        -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
        -Name "fDenyTSConnections" `
        -ErrorAction SilentlyContinue

    if ($null -ne $rdpValue) {

        $rdpEnabled = ($rdpValue.fDenyTSConnections -eq 0)

        Show-Result `
            -Test "Remote Desktop" `
            -Success $rdpEnabled `
            -Details $(if ($rdpEnabled) {
                "Enabled"
            } else {
                "Disabled"
            })

    }
    else {

        Show-Warning `
            -Test "Remote Desktop" `
            -Details "Unable to determine RDP status"
    }

    # ========================================================
    # 15. WINRM
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "15. WINRM"
    Write-Host "------------------------------------------------------------"

    $winrmService = Get-Service `
        -Name WinRM `
        -ErrorAction SilentlyContinue

    if ($null -ne $winrmService) {

        Show-Result `
            -Test "WinRM Service" `
            -Success ($winrmService.Status -eq "Running") `
            -Details "Status: $($winrmService.Status)"

    }
    else {

        Show-Warning `
            -Test "WinRM Service" `
            -Details "WinRM service not found"
    }

    # ========================================================
    # 16. LOCAL ADMINISTRATOR
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "16. LOCAL ADMINISTRATOR"
    Write-Host "------------------------------------------------------------"

    $localAdmin = Get-LocalUser `
        -Name "Administrator" `
        -ErrorAction SilentlyContinue

    if ($null -ne $localAdmin) {

        Show-Result `
            -Test "Local Administrator" `
            -Success ($localAdmin.Enabled) `
            -Details $(if ($localAdmin.Enabled) {
                "Enabled"
            } else {
                "Disabled"
            })

    }
    else {

        Show-Result `
            -Test "Local Administrator" `
            -Success $false `
            -Details "Administrator account not found"
    }

    # ========================================================
    # 17. LOCAL ACCOUNTS
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "17. LOCAL ACCOUNT CHECK"
    Write-Host "------------------------------------------------------------"

    $oldAccounts = @(
        "ITUser",
        "ITSupport"
    )

    foreach ($account in $oldAccounts) {

        $exists = Get-LocalUser `
            -Name $account `
            -ErrorAction SilentlyContinue

        if ($null -eq $exists) {

            Show-Result `
                -Test "Local Account $account" `
                -Success $true `
                -Details "Account does not exist"

        }
        else {

            Show-Warning `
                -Test "Local Account $account" `
                -Details "Account still exists"
        }
    }

    # ========================================================
    # 18. USER PROFILES
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "18. OLD USER PROFILES"
    Write-Host "------------------------------------------------------------"

    foreach ($profileName in $oldAccounts) {

        $profilePath = "C:\Users\$profileName"

        if (Test-Path $profilePath) {

            Show-Warning `
                -Test "Profile $profileName" `
                -Details "$profilePath still exists"

        }
        else {

            Show-Result `
                -Test "Profile $profileName" `
                -Success $true `
                -Details "Profile removed"
        }
    }

    # ========================================================
    # 19. DISK SPACE
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "19. DISK SPACE"
    Write-Host "------------------------------------------------------------"

    $disk = Get-CimInstance Win32_LogicalDisk `
        -Filter "DeviceID='C:'"

    $freeGB = [math]::Round(
        $disk.FreeSpace / 1GB,
        2
    )

    $totalGB = [math]::Round(
        $disk.Size / 1GB,
        2
    )

    Write-Host "C: Total : $totalGB GB"
    Write-Host "C: Free  : $freeGB GB"

    if ($freeGB -ge 10) {

        Show-Result `
            -Test "Disk Space" `
            -Success $true `
            -Details "$freeGB GB free"

    }
    else {

        Show-Warning `
            -Test "Disk Space" `
            -Details "Less than 10 GB free"
    }

    # ========================================================
    # 20. WINDOWS UPDATE SERVICE
    # ========================================================

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "20. WINDOWS UPDATE"
    Write-Host "------------------------------------------------------------"

    $wuauserv = Get-Service `
        -Name wuauserv `
        -ErrorAction SilentlyContinue

    if ($null -ne $wuauserv) {

        Write-Host "Windows Update Service: $($wuauserv.Status)"

        Show-Result `
            -Test "Windows Update Service" `
            -Success ($wuauserv.Status -ne "Disabled") `
            -Details "Service status: $($wuauserv.Status)"

    }

    # ========================================================
    # FINAL SUMMARY
    # ========================================================

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "                    FINAL RESULT"
    Write-Host "============================================================"
    Write-Host ""

    Write-Host "PASS    : $pass"
    Write-Host "WARNING : $warning"
    Write-Host "FAIL    : $fail"

    Write-Host ""

    if ($fail -eq 0) {

        if ($warning -eq 0) {

            Write-Host "OVERALL STATUS: PASS"
            Write-Host "The workstation passed all verification checks."

        }
        else {

            Write-Host "OVERALL STATUS: PASS WITH WARNINGS"
            Write-Host "Review the warnings above."

        }

    }
    else {

        Write-Host "OVERALL STATUS: FAILED"
        Write-Host "One or more important checks failed."
        Write-Host "Review the errors above."

    }

    Write-Host ""
    Write-Host "Verification log:"
    Write-Host $logPath
    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "VERIFICATION SCRIPT ERROR"
    Write-Host "============================================================"
    Write-Host $_
    Write-Host ""

}
finally {

    Stop-Transcript
}