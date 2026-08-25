# Template PC and Golden Image Preparation

A hands-on Windows workstation imaging project focused on preparing a standardized Template PC, generalizing it with Sysprep, capturing it as a Windows Imaging Format (WIM) image, and preparing the resulting Golden Image for deployment through Windows Deployment Services (WDS).

This module documents how an IT administrator creates a consistent workstation baseline that can be deployed to multiple computers instead of manually configuring each workstation.

> **Project type:** IT infrastructure / endpoint deployment / imaging  
> **Environment:** Windows 10 Pro, Windows Server, and WDS  
> **Domain:** `lab.local`  
> **Template PC:** `TEMPLATE01`

## Objectives

- Build a standardized Template PC.
- Install the approved base operating system and required drivers.
- Add baseline applications and workstation configuration.
- Verify the image does not contain user-specific or temporary data.
- Generalize the installation with Sysprep.
- Capture the image through WDS.
- Version and document the Golden Image.
- Test deployment before accepting the image for broader rollout.

## Workflow

```text
Template PC
   |
   +-- Windows installation
   |
   +-- Windows Updates
   |
   +-- Standard applications
   |
   +-- Drivers and baseline configuration
   |
   +-- Verification and cleanup
   |
   +-- Sysprep generalization
   |
   +-- PXE/WDS capture
   |
   +-- Golden Image (.WIM)
   |
   +-- Test deployment
   |
   +-- Production deployment
```

## Lab Architecture

```text
                         +----------------------+
                         |        DC01          |
                         | AD DS + DNS          |
                         | 192.168.1.100        |
                         +----------+-----------+
                                    |
             +----------------------+----------------------+
             |                      |                      |
      +------v------+       +------v------+       +------v------+
      | DHCP01      |       | WDS01       |       | TEMPLATE01  |
      | DHCP        |       | WDS         |       | Template PC |
      | 192.168.1.101 |     | 192.168.1.102 |     | Workgroup   |
      +------+------+       +------+------+       +-------------+
             |                     |
             |                     |
             |            +--------v--------+
             |            | WDS capture     |
             |            | Golden image    |
             |            +-----------------+
             |
      +------v------+
      | CLIENT01    |
      | Deployed    |
      | workstation |
      +-------------+
```

## Template PC Configuration

| Property | Value |
|---|---|
| Computer name | `TEMPLATE01` |
| Operating system | Windows 10 Pro |
| Memory | 4 GB or more |
| CPU | 2 cores or more |
| Storage | 40-60 GB or more |
| Network | `labnet` / internal network |
| Domain state | `WORKGROUP` |
| IP | DHCP |

The Template PC should remain in `WORKGROUP` before Sysprep and image capture. It should not be joined to the domain before distribution and generalization.

## Prerequisites

Before preparing the Template PC, the following infrastructure should be available:

| Component | Requirement |
|---|---|
| Active Directory | Required |
| DNS | Required |
| DHCP | Required for PXE deployment |
| WDS | Required |
| Windows installation media | Required |
| Network connectivity | Required |
| Windows Pro/Enterprise | Recommended |
| WDS storage | Required |

## Creating the Template PC

Create a clean workstation or VM with the approved hardware profile.

Example configuration:

- OS: Windows 10 Pro
- RAM: 4 GB
- CPU: 2 cores
- Disk: 40-60 GB
- Network: `labnet`

Ensure the Template PC can reach the WDS server and the rest of the deployment infrastructure.

## Windows Installation

Install the approved Windows edition from official installation media.

Basic sequence:

```text
Windows installation media
   |
   +-- Boot Template PC
   |
   +-- Select Windows edition
   |
   +-- Partition disk
   |
   +-- Install Windows
   |
   +-- Local administrator account
```

The machine remains in `WORKGROUP` during the imaging workflow.

## Windows Updates

Before capture, install all required updates and confirm that the workstation meets the approved image baseline.

```text
Settings
   +-- Update & Security
      +-- Windows Update
         +-- Check for updates
         +-- Install updates
         +-- Restart if required
```

Do not capture the image until the operating system is stable and the approved patch baseline is in place.

## Standard Applications

Install only approved, organization-standard applications.

Examples:

- Microsoft Edge
- Google Chrome
- 7-Zip
- PDF reader
- Microsoft Office
- Approved utilities
- Required runtime components
- Approved security software

Avoid:

- Personal applications
- Temporary troubleshooting tools
- Unapproved software
- Employee-specific applications
- User-specific settings

Department-specific software can be deployed later through IT processes, software packages, and Group Policy rather than embedded in the base image.

## Driver Installation

Install the appropriate drivers for the target workstation hardware.

At minimum:

- Network adapter
- Storage controller
- Chipset
- Graphics
- Audio
- Organization-required hardware drivers

For multiple hardware models, consider maintaining drivers separately rather than permanently embedding every driver into the image.

## Baseline Workstation Configuration

The Template PC should contain only the baseline workstation config that should be consistent across most machines.

Examples:

- Power configuration
- Standard Windows settings
- Approved applications
- Basic desktop configuration
- Approved utilities
- Basic troubleshooting tools

This keeps the Golden Image focused on the reusable workstation baseline rather than every organizational policy change.

## Template Image vs Group Policy

A key design principle is to separate the Golden Image from centralized domain policies.

### Template Image contains

- Windows installation
- Applications
- Drivers
- Baseline workstation settings

### Group Policy controls

- Password policy
- Security policy
- USB restrictions
- Control Panel restrictions
- Windows Update policy
- Desktop policy
- Network drive mappings
- Printer deployment
- User and computer restrictions

This means centralized policy changes do not require rebuilding the Golden Image every time.

## Template PC Verification

Before Sysprep, verify the Template PC thoroughly.

### Operating system

Confirm:

- Correct Windows edition
- Windows activation status
- Windows Updates completed
- No obvious system errors

### Applications

Open each standard application and confirm it launches and functions correctly.

### Networking

```powershell
ipconfig /all
```

Confirm the template is connected and the device can reach the WDS server and domain resources as required.

### Domain state

The Template PC must remain outside the domain before Sysprep.

```powershell
systeminfo | findstr /B /C:"Domain"
```

Expected output:

```text
Domain: WORKGROUP
```

## Cleanup Before Capture

Before capturing the image, remove temporary or user-specific content.

Remove:

- Temporary files
- Installation files
- Downloaded installers
- Temporary user data
- Test files
- Test accounts
- Troubleshooting artifacts

Also empty the Recycle Bin and confirm that the workstation does not contain user-specific or sensitive content. Do not manually delete system directories or default profile content unless you are following a documented standard.

## Pre-Sysprep Checklist

Before running Sysprep, confirm:

- [ ] Windows installation complete
- [ ] Windows Updates complete
- [ ] Standard applications installed
- [ ] Drivers installed
- [ ] Baseline configuration complete
- [ ] Temporary files removed
- [ ] Test accounts removed
- [ ] Computer remains in `WORKGROUP`
- [ ] Correct network connected
- [ ] WDS server reachable
- [ ] Image storage available
- [ ] Important data removed
- [ ] Template configuration documented

## Sysprep

Sysprep prepares Windows for redeployment to other computers. Launch it from:

```text
C:\Windows\System32\Sysprep
```

Run:

```powershell
sysprep.exe
```

Recommended settings:

- System Cleanup Action: Enter System Out-of-Box Experience (OOBE)
- Generalize: Enabled
- Shutdown Options: Shutdown

> Important: After Sysprep completes, do not boot the Template PC back into Windows before capturing the image. Leave the machine powered off and proceed to the WDS/PXE capture process.

## PXE Boot and Image Capture

After Sysprep shuts down the Template PC, boot it through the network/PXE interface.

Depending on the environment, this may require:

- `F12`
- `Esc`
- The firmware boot menu

The intended flow is:

```text
Template PC
   +-- DHCP lease
   +-- PXE boot
   +-- WDS01
   +-- Windows PE
```

From the WDS capture environment:

1. Select the appropriate Windows installation image.
2. Choose the Windows partition.
3. Enter the image name.
4. Enter the image description.
5. Select the destination for the WIM capture.
6. Start capture.

Example image name:

```text
Windows10-Pro-Standard-v1.0.wim
```

Example description:

```text
Windows 10 Pro standard workstation image. Updated August 2026.
```

## Golden Image

The captured WIM becomes the organization's Golden Image.

Example:

```text
WDS01
+-- Images
   +-- Windows10
      +-- Windows10-Pro-Standard-v1.0.wim
```

This captured image becomes the standardized deployment source for test and production workstations.

## Image Version Management

Each image should have a documented version.

| Field | Example |
|---|---|
| Image name | `Windows10-Pro-Standard` |
| Version | `1.0` |
| Created | August 2026 |
| Operating system | Windows 10 Pro |
| Applications | Standard workstation apps |
| Updates | Current at creation |
| Created by | IT deployment |
| Status | Approved |
| WDS server | `WDS01` |

Examples:

- `1.0` = initial Golden Image
- `1.1` = updated browser or approved software
- `1.2` = additional approved utility
- `2.0` = major baseline change

When the image is modified, the version must be incremented.

## Importing the Image to WDS

On `WDS01`:

```text
Windows Deployment Services
   +-- Servers
      +-- WDS01
         +-- Install Images
            +-- Create or select image group
            +-- Import captured WIM
```

Example group:

```text
Install Images
+-- Windows 10
   +-- Windows 10 Pro - Standard Workstation
```

## Golden Image Testing

A new Golden Image should not be deployed broadly without validation. First deploy it to a test workstation, for example `CLIENT-TEST01`.

Verify:

- Windows boots correctly
- Applications work
- Network connectivity works
- Activation and licensing behave as expected
- Computer can join the domain
- Group Policy applies
- DNS works
- DHCP works
- Required printers and network resources work
- Standard users can log in
- Security policies work

## Domain Join After Deployment

The Template PC remains in `WORKGROUP`. After deployment, the resulting workstation joins `lab.local` and receives the organization's centralized policies.

This deployment model is preferred for the lab:

```text
Golden Image
   +-- CLIENT01
   +-- Join lab.local
   +-- Active Directory
   +-- Group Policy
   +-- Workstation security and restrictions
```

This keeps the image focused on the workstation baseline while domain policy handles centralized settings.

## Troubleshooting

### WDS does not appear during PXE boot

Check:

- DHCP service
- Network connectivity
- PXE state
- WDS service
- Virtual machine network adapter and switch
- Client boot order and firmware mode

### Sysprep fails

Check logs in:

```text
C:\Windows\System32\Sysprep\Panther
```

Review:

- `setupact.log`
- `setuperr.log`

Common causes include:

- Unsupported application state
- Windows Store or UWP application problems
- Previous Sysprep attempts
- Corrupted Windows installation
- Incorrect system configuration

Do not repeatedly rerun Sysprep without identifying the underlying issue.

### Template PC boots into Windows after Sysprep

If the machine is booted back into Windows after generalization, pause and evaluate the image state. Do not assume the image is safe to use without investigation.

### DHCP works but WDS does not start

If the client receives an IP address but PXE/WDS does not work, separate the layers:

- PXE configuration
- WDS service
- Network boot configuration
- Firewall rules
- DHCP/WDS integration
- BIOS/UEFI boot mode

This keeps DHCP and WDS issues distinct.

## Golden Image Best Practices

- Keep the image minimal and standardized.
- Use Group Policy for centralized policy changes.
- Maintain versioning for every approved image.
- Test each new image before production rollout.
- Document what changed and why.
- Keep a known-good previous image until validation is complete.

## Final Acceptance Checklist

### Template PC

- [ ] Correct Windows edition installed
- [ ] Windows Updates completed
- [ ] Required drivers installed
- [ ] Standard applications installed
- [ ] Baseline workstation configuration completed
- [ ] Temporary files removed
- [ ] Test accounts removed
- [ ] Computer remains in `WORKGROUP`
- [ ] No user-specific information remains
- [ ] Network connectivity verified
- [ ] WDS connectivity verified

### Sysprep

- [ ] Sysprep completed successfully
- [ ] Generalize selected
- [ ] OOBE selected
- [ ] Shutdown selected
- [ ] Template PC powered off and not booted into Windows after Sysprep

### Image Capture

- [ ] Template PC PXE booted successfully
- [ ] Windows PE loaded
- [ ] Correct partition selected
- [ ] WIM capture completed
- [ ] Image stored on WDS
- [ ] Image imported into WDS
- [ ] Image version documented

### Testing

- [ ] Test client deployed
- [ ] Windows boots successfully
- [ ] Applications work
- [ ] Network works
- [ ] Domain join works
- [ ] DNS works
- [ ] GPOs apply
- [ ] User logon works
- [ ] Printers and network resources work
- [ ] Image approved for deployment

## Documentation

The detailed procedures are stored in [documentation](documentation/). Lab evidence and screenshots are stored in [screenshots](screenshots/).

## Skills Demonstrated

- Windows workstation preparation and standardization
- Golden image creation and WIM capture
- Sysprep generalization and OOBE workflow
- PXE boot and Windows PE deployment
- WDS capture and import workflows
- Image versioning and change control
- Driver and application baseline management
- Domain join and Group Policy integration
- Deployment troubleshooting and validation

## Related Projects

- [01 - Active Directory, DNS, and Group Policy](../01-AD-DS-DNS-GPO/)
- [02 - DHCP](../02-DHCP/)
- [04 - WDS Imaging](../04-WDS-Imaging/)
- [05 - File Server](../05-File-Server/)
- [06 - Automation](../06-Automation/)
- [07 - Print Server](../07-Print-Server/)
- [08 - Troubleshooting](../08-Troubleshooting/)

## Lab Disclaimer

This is a personal learning environment, not a production enterprise deployment system. The computer name, operating system, domain, network, and image names are lab examples. Review all deployment, licensing, and security processes against the organization's standards before production use.

**Status:** Completed / continuously improving  
**Environment:** Virtualized Windows Server lab  
**Focus:** IT support, desktop support, system administration, and Windows imaging
