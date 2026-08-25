# Windows Automation and Deployment Lab

This section focuses on automating the workstation deployment and post-configuration process in a Windows lab environment. The goal is to reduce manual setup time, standardize configuration, and validate that the newly deployed machine is ready for Active Directory and domain-based operations.

> Project type: Windows automation / imaging / workstation provisioning  
> Environment: Windows 10, WDS, Active Directory, PowerShell  
> Domain: `lab.local`

## Objectives

- Deploy a Windows 10 workstation using Windows Deployment Services (WDS).
- Apply unattended installation settings through XML answer files.
- Configure a post-deployment workstation automatically with PowerShell.
- Remove temporary local accounts used during lab setup.
- Verify AD membership, DNS, networking, and workstation readiness.
- Record results in log files for troubleshooting and documentation.

## Lab Automation Flow

```text
WDS client boot / image installation
        ↓
WDSClientUnattend.xml
        ↓
OSunattend.xml
        ↓
01-Configure-Workstation.ps1
        ↓
02-Cleanup-LocalAccounts.ps1
        ↓
03-Verify-Workstation.ps1
        ↓
Workstation ready for domain use
```

This sequence creates a repeatable deployment pattern for lab workstations, especially in a homelab or classroom environment where machines need to be re-imaged quickly.

## Automation Components

### 1. WDS Unattend XML Files

The folder `WDS unattend_xml` contains unattended installation files used for Windows deployment.

#### `WDSClientUnattend.xml`

This XML file is used during the WDS client installation flow. It provides:

- Domain credentials for the image deployment process
- The install image name and image group
- Disk partitioning instructions
- Windows PE setup configuration

Key values in this lab include:

- Domain: `lab.local`
- Username: `ADMINISTRATOR`
- Image group: `GoldenImages`
- Install image: `Windows 10 Pro Golden Image v1`

This file is used to automate the actual OS install onto the target workstation.

#### `OSunattend.xml`

This file is applied after installation and configures the Windows operating system during the OOBE/specialize process. It includes:

- Local administrator account creation
- Local account `ITSupport`
- Automatic sign-in after first boot
- Time zone configuration
- OOBE settings such as skipping setup screens

This is useful when the lab wants to create a local IT support account for initial setup tasks before the machine joins the domain.

> Note: The XML examples in this lab are intentionally simple and meant for a test environment. In production, credentials should be managed securely using more controlled deployment methods and not embedded directly in XML files.

## PowerShell Scripts

### 01-Configure-Workstation.ps1.ps1

This script performs the main post-deployment workstation configuration.

It can:

- Verify that the script is running with Administrator rights.
- Enable the local built-in Administrator account.
- Set a local Administrator password.
- Rename the computer to a standardized name, such as `DESKTOP-XXXXX`.
- Configure Windows Time synchronization.
- Enable Remote Desktop.
- Disable sleep on AC power.
- Remove unnecessary apps.
- Install available Windows updates.
- Test connectivity to Active Directory.
- Join the machine to the `lab.local` domain.
- Create a log file at `C:\SetupLog.txt`.

This is the main script used once the base image finishes installation.

### 02-Cleanup-LocalAccounts.ps1

This script removes temporary local accounts that were created for a lab or build process.

It specifically checks for and removes:

- `ITUser`
- `ITSupport`

It also removes their corresponding Windows profile folders from `C:\Users\` when safe to do so.

The script validates that the current user is the local Administrator before removing accounts, which helps avoid destructive mistakes.

### 03-Verify-Workstation.ps1

This script validates the workstation after configuration.

It checks:

- Computer name and OS information
- Domain membership
- Logged-in account type
- IPv4 connectivity and gateway
- DNS server configuration
- DNS resolution for the domain
- Domain Controller discovery
- SMB access readiness
- Active Directory connectivity
- Summary of pass/fail results

The output is saved in `C:\WorkstationVerification.txt` and helps IT staff quickly confirm whether a machine is ready for production lab use.

## Recommended Execution Order

1. Build the workstation with WDS using the unattended answer files.
2. Log in using the local IT support account or the built-in local Administrator.
3. Run `01-Configure-Workstation.ps1` as Administrator.
4. Reboot if the computer rename or domain join requires it.
5. Run `02-Cleanup-LocalAccounts.ps1` to remove temporary lab accounts.
6. Run `03-Verify-Workstation.ps1` to validate the final state.
7. Confirm the machine is joined to the domain and can resolve domain services.

## Example Deployment Timeline

```text
09:00  WDS image deploy begins
09:10  Windows installation completes
09:15  Local admin and default lab accounts created
09:20  Workstation script runs and renames the PC
09:30  Domain join completes
09:35  Cleanup script removes temporary accounts
09:40  Verification script confirms the configuration
09:45  Workstation ready for user testing
```

## Common Operational Notes

- Run all PowerShell scripts as Administrator.
- If a workstation does not join the domain, validate DNS first.
- If the account cleanup script fails because a profile is in use, sign out the user and retry.
- Confirm the correct OU path if you are joining workstations to a specific AD container.
- Review logs if a script fails during rename, time sync, or domain join steps.

## Security Considerations

This lab is intentionally simple and designed for learning. In a real production environment:

- Do not store passwords in plain text in XML files.
- Use secure deployment automation and secret management.
- Restrict domain join credentials to approved administrators.
- Validate OU placement before joining workstations to Active Directory.
- Review local account creation and automatic sign-in settings before production use.

## Summary

This automation section demonstrates a practical lab workflow for standardizing Windows workstation setup with WDS, unattend files, PowerShell, and verification checks. The combination of scripted automation and validation reduces manual work and creates a repeatable process for deploying domain-ready lab machines.
