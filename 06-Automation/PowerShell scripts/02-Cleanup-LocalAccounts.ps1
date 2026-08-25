# ============================================================
# LOCAL ACCOUNT CLEANUP SCRIPT
# ============================================================
#
# Purpose:
#   - Verify local Administrator is being used
#   - Remove local ITUser
#   - Remove local ITSupport
#   - Remove their Windows user profiles
#
# IMPORTANT:
#   Run this script while logged in as:
#
#       .\Administrator
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
    Write-Host "ERROR: Administrator privileges are required." `
        -ForegroundColor Red

    exit 1
}


# ============================================================
# 2. START LOGGING
# ============================================================

$LogPath = "C:\AccountCleanupLog.txt"

Start-Transcript -Path $LogPath -Append


try {

    Write-Host ""
    Write-Host "====================================================" `
        -ForegroundColor Cyan

    Write-Host " LOCAL ACCOUNT CLEANUP" `
        -ForegroundColor Cyan

    Write-Host "====================================================" `
        -ForegroundColor Cyan

    Write-Host ""


    # ========================================================
    # 3. VERIFY CURRENT USER
    # ========================================================

    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

    Write-Host "Currently logged in as:"
    Write-Host $CurrentUser
    Write-Host ""

    if ($CurrentUser -notmatch "\\Administrator$") {

        Write-Host ""
        Write-Host "ERROR: You are not logged in as the local Administrator." `
            -ForegroundColor Red

        Write-Host ""
        Write-Host "Please log in using:"
        Write-Host ""
        Write-Host "    .\Administrator"
        Write-Host ""

        throw "Local Administrator account required."
    }

    Write-Host "Local Administrator confirmed." `
        -ForegroundColor Green


    # ========================================================
    # 4. ACCOUNTS TO REMOVE
    # ========================================================

    $AccountsToRemove = @(
        "ITUser",
        "ITSupport"
    )


    # ========================================================
    # 5. REMOVE LOCAL ACCOUNTS
    # ========================================================

    Write-Host ""
    Write-Host "Removing local accounts..." `
        -ForegroundColor Yellow

    foreach ($Account in $AccountsToRemove) {

        Write-Host ""
        Write-Host "Checking local account: $Account"

        $LocalUser = Get-LocalUser `
            -Name $Account `
            -ErrorAction SilentlyContinue

        if ($null -ne $LocalUser) {

            try {

                Remove-LocalUser `
                    -Name $Account `
                    -ErrorAction Stop

                Write-Host "Successfully removed: $Account" `
                    -ForegroundColor Green

            }
            catch {

                Write-Host "ERROR removing $Account" `
                    -ForegroundColor Red

                Write-Host $_.Exception.Message `
                    -ForegroundColor Red
            }

        }
        else {

            Write-Host "Local account not found: $Account" `
                -ForegroundColor Yellow
        }
    }


    # ========================================================
    # 6. REMOVE WINDOWS USER PROFILES
    # ========================================================

    Write-Host ""
    Write-Host "Removing old Windows user profiles..." `
        -ForegroundColor Yellow

    foreach ($Account in $AccountsToRemove) {

        $ProfilePath = "C:\Users\$Account"

        Write-Host ""
        Write-Host "Checking profile:"
        Write-Host $ProfilePath

        if (Test-Path $ProfilePath) {

            $Profile = Get-CimInstance Win32_UserProfile |
                Where-Object {
                    $_.LocalPath -eq $ProfilePath
                }

            if ($null -ne $Profile) {

                if ($Profile.Loaded) {

                    Write-Host ""
                    Write-Host "WARNING: Profile is currently loaded." `
                        -ForegroundColor Yellow

                    Write-Host "Skipping profile: $ProfilePath" `
                        -ForegroundColor Yellow
                }
                else {

                    try {

                        Remove-CimInstance `
                            -InputObject $Profile `
                            -ErrorAction Stop

                        Write-Host "Windows profile removed:" `
                            -ForegroundColor Green

                        Write-Host $ProfilePath `
                            -ForegroundColor Green
                    }
                    catch {

                        Write-Host ""
                        Write-Host "ERROR removing profile:" `
                            -ForegroundColor Red

                        Write-Host $_.Exception.Message `
                            -ForegroundColor Red
                    }
                }

            }
            else {

                Write-Host "Windows profile entry not found."
                Write-Host "Removing remaining folder..."

                try {

                    Remove-Item `
                        -Path $ProfilePath `
                        -Recurse `
                        -Force `
                        -ErrorAction Stop

                    Write-Host "Profile folder removed." `
                        -ForegroundColor Green
                }
                catch {

                    Write-Host ""
                    Write-Host "ERROR removing profile folder." `
                        -ForegroundColor Red

                    Write-Host $_.Exception.Message `
                        -ForegroundColor Red
                }
            }

        }
        else {

            Write-Host "Profile does not exist."
        }
    }


    # ========================================================
    # 7. VERIFY LOCAL ACCOUNTS
    # ========================================================

    Write-Host ""
    Write-Host "====================================================" `
        -ForegroundColor Cyan

    Write-Host " REMAINING LOCAL USERS" `
        -ForegroundColor Cyan

    Write-Host "====================================================" `
        -ForegroundColor Cyan

    Get-LocalUser |
        Select-Object Name, Enabled |
        Format-Table -AutoSize


    # ========================================================
    # 8. VERIFY PROFILES
    # ========================================================

    Write-Host ""
    Write-Host "====================================================" `
        -ForegroundColor Cyan

    Write-Host " PROFILE CHECK" `
        -ForegroundColor Cyan

    Write-Host "====================================================" `
        -ForegroundColor Cyan

    foreach ($Account in $AccountsToRemove) {

        $ProfilePath = "C:\Users\$Account"

        if (Test-Path $ProfilePath) {

            Write-Host "[WARNING] Profile still exists: $ProfilePath" `
                -ForegroundColor Yellow

        }
        else {

            Write-Host "[PASS] Profile removed: $ProfilePath" `
                -ForegroundColor Green
        }
    }


    # ========================================================
    # 9. COMPLETION
    # ========================================================

    Write-Host ""
    Write-Host "====================================================" `
        -ForegroundColor Green

    Write-Host " LOCAL ACCOUNT CLEANUP COMPLETED" `
        -ForegroundColor Green

    Write-Host "====================================================" `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "Local Administrator remains available:"
    Write-Host ""
    Write-Host "    .\Administrator"
    Write-Host ""

    Write-Host "Domain accounts were NOT modified."
    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "====================================================" `
        -ForegroundColor Red

    Write-Host " CLEANUP FAILED" `
        -ForegroundColor Red

    Write-Host "====================================================" `
        -ForegroundColor Red

    Write-Host ""

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Log file:"
    Write-Host $LogPath
}


# ============================================================
# 10. STOP LOGGING
# ============================================================

Stop-Transcript