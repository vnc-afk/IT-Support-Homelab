# Windows Deployment Services and Imaging Lab

A hands-on Windows Server lab for deploying Windows Deployment Services (WDS), configuring PXE network boot, managing Windows boot and installation images, and testing standardized operating-system deployment.

This module documents a lab workflow in which DHCP provides client network configuration and WDS provides the PXE and Windows deployment environment.

> **Project type:** IT infrastructure / homelab  
> **Environment:** Windows Server and Windows 10/11  
> **Domain:** `lab.local`  
> **Deployment server:** `WDS01`

## Objectives

- Prepare and domain-join a dedicated WDS server.
- Install and configure the WDS role and `RemoteInstall` storage.
- Add boot and install images.
- Convert `install.esd` to `install.wim` when required.
- Test PXE boot and Windows PE deployment from a client.
- Apply image naming and versioning practices.
- Troubleshoot failures by separating network, DHCP, PXE, WDS, and image layers.

## Deployment Workflow

```text
CLIENT01
   |
   +-- DHCP requests an IP configuration
   |
   +-- PXE network boot
   |
   +-- WDS01 provides Windows PE / boot image
   |
   +-- Technician selects an install image
   |
   +-- Windows installation starts
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
      | DHCP01      |       | WDS01       |       | FILESRV01   |
      | DHCP        |       | WDS         |       | File server |
      | .101        |       | .102        |       +-------------+
      +------+------+       +------+------+              
             |                     |
             +----------+----------+
                        |
                 +------v------+
                 | CLIENT01    |
                 | PXE target  |
                 +-------------+
```

The documented architecture keeps AD DS/DNS, DHCP, WDS, file-server, and print-server responsibilities separated between dedicated systems.

### Core Infrastructure

| Host | Role | Addressing |
|---|---|---|
| DC01 | AD DS and DNS | Static: `192.168.1.100` |
| DHCP01 | DHCP | Static: `192.168.1.101` |
| WDS01 | Windows Deployment Services | Static: `192.168.1.102` |
| CLIENT01 | Deployment target | DHCP |

## Technologies and Tools

- Windows Server and Windows 10/11
- Windows Deployment Services
- PXE and Windows PE
- Active Directory Domain Services and DNS
- DHCP
- Windows Imaging Format (WIM)
- Windows installation media
- DISM and PowerShell
- Server Manager and WDS Management console
- VirtualBox
- Command Prompt

## WDS Server Configuration

WDS01 uses a static address and points to DC01 for internal DNS.

| Property | Value |
|---|---|
| Hostname | `WDS01` |
| IP address | `192.168.1.102` |
| Subnet mask | `255.255.255.0` |
| Default gateway | `192.168.1.1` |
| Preferred DNS | `192.168.1.100` |
| Domain | `lab.local` |

Verify network and DNS connectivity from WDS01:

```powershell
ipconfig /all
nslookup lab.local
nslookup dc01.lab.local
ping 192.168.1.100
```

### Domain Integration

Rename the server to `WDS01`, join it to `lab.local`, and restart as required. Confirm domain membership with:

```powershell
systeminfo | findstr /B /C:"Domain"
```

Expected output includes:

```text
Domain: lab.local
```

## WDS Installation and Configuration

Install WDS through **Server Manager > Manage > Add Roles and Features > Role-based or feature-based installation > Windows Deployment Services**.

Install the following role services:

- Deployment Server
- Transport Server

Configure WDS through **Server Manager > Tools > Windows Deployment Services > Servers > WDS01 > Configure Server** with:

| Setting | Lab value |
|---|---|
| Mode | Integrated with Active Directory |
| Domain | `lab.local` |
| Remote Installation Folder | `D:\RemoteInstall` |

### RemoteInstall Storage

Use a dedicated deployment volume when possible so large images do not consume the operating-system volume.

```text
C:\                 Operating system
D:\RemoteInstall    WDS deployment resources
```

The folder location must have enough capacity for boot images, install images, and future image versions.

### PXE Response Policy

For this controlled homelab, WDS responds to **known and unknown client computers**. This allows a new workstation to PXE boot without first prestaging its computer account.

In production, restrict unknown-client responses according to the organization's security requirements. Confirm the setting before exposing WDS to a wider network.

## DHCP and PXE Integration

DHCP and WDS have different responsibilities:

| Service | Responsibility |
|---|---|
| DHCP01 | IP address, subnet mask, gateway, and DNS configuration |
| WDS01 | PXE response, Windows PE, boot image, and install image |

Do not add DHCP options 66 and 67 by default. The correct PXE design depends on firmware mode, DHCP/WDS placement, VLANs, relay configuration, and the network equipment in use. On routed networks, DHCP relay or IP helper configuration may be required.

This lab places DHCP01, WDS01, and CLIENT01 on the same `192.168.1.0/24` deployment network:

```text
DHCP01    192.168.1.101
WDS01     192.168.1.102
CLIENT01  DHCP assigned
```

All systems must be able to communicate on the deployment network, and the client's virtual network adapter must be connected to the correct VirtualBox network.

## Boot and Install Images

### Boot Image

Windows installation media normally contains:

```text
sources\boot.wim
```

Add it in the WDS console under:

```text
WDS01
+-- Boot Images
    +-- Add Boot Image
```

The resulting image is commonly shown as **Microsoft Windows Setup**.

### Install Image

Installation media may contain either `install.wim` or `install.esd`:

```text
sources\install.wim
sources\install.esd
```

WDS can use a WIM image. If the media contains an ESD, inspect its indexes and export the required edition.

### ESD to WIM Conversion

Run from an elevated Command Prompt or PowerShell session with DISM available:

```powershell
dism /Get-WimInfo /WimFile:E:\sources\install.esd
```

Export the required index, replacing `6` with the index for the intended edition:

```powershell
dism /Export-Image `
  /SourceImageFile:E:\sources\install.esd `
  /SourceIndex:6 `
  /DestinationImageFile:C:\install.wim `
  /Compress:max `
  /CheckIntegrity
```

Verify the output before adding it to WDS. Do not assume an index number; the available editions vary by installation media.

### Install Image Groups

Organize images into meaningful groups:

```text
Install Images
+-- Windows 10
|   +-- Windows 10 Pro
+-- Windows 11
    +-- Windows 11 Pro
```

This makes it easier to select the correct edition during deployment.

## WDS and DHCP Verification

### Services

```powershell
Get-Service WDSServer
Get-Service DHCPServer
```

Expected state for both services: `Running`. Start WDS only when appropriate:

```powershell
Start-Service WDSServer
```

### Network and DNS

```powershell
nslookup lab.local
ping 192.168.1.100
ping 192.168.1.102
```

Before testing PXE, confirm that DHCP01 has an active scope such as `192.168.1.110` through `192.168.1.200`, with infrastructure addresses kept outside that pool.

## PXE Boot Test

1. Connect CLIENT01 to the same virtual network as DHCP01 and WDS01.
2. Set the client firmware to boot from the network.
3. Start the client and select PXE or network boot.
4. Confirm that DHCP assigns a valid address.
5. Confirm that WDS responds and loads Windows PE.
6. Select the expected install image, such as Windows 10 Pro.
7. Confirm that Windows installation completes successfully.

A successful test should progress through:

```text
CLIENT01
  +-- DHCP lease
  +-- PXE network boot
  +-- WDS response
  +-- Windows PE
  +-- Install image selection
  +-- Windows installation
```

## Golden Images and Versioning

A golden image is a tested, standardized operating-system image intended for repeatable workstation deployment. Keep images documented and versioned:

```text
Win10Pro-Golden-2026-08.wim
Win11Pro-Golden-2026-08.wim
```

Avoid ambiguous names such as `image.wim`, `new.wim`, `test.wim`, or `final.wim`. A useful name identifies the Windows version, edition, purpose, and release version. The separate [03-TEMPLATE-PC-GOLDEN-IMAGE](../03-TEMPLATE-PC-GOLDEN-IMAGE/) module documents the template-PC workflow.

## Troubleshooting

### Client does not receive an IP address

1. Check the `DHCPServer` service.
2. Confirm the DHCP scope exists and is active.
3. Check available addresses and reservations.
4. Confirm the client's virtual adapter and network are correct.
5. Test connectivity and inspect firewall or network-device rules.
6. Check for a competing or unauthorized DHCP server.

### Client receives an IP address but PXE does not start

Check:

- `WDSServer` service status
- WDS PXE response settings
- Client firmware mode and boot order
- Firewall and network connectivity
- DHCP relay or IP helper configuration when subnets differ
- Correct virtual network assignment

```powershell
Get-Service WDSServer
ping 192.168.1.102
```

### WDS starts but no Windows image appears

Confirm that both image types are present and valid:

```text
WDS01
+-- Boot Images
|   +-- boot.wim
+-- Install Images
    +-- Windows image group
        +-- Windows edition
```

Review the WDS console and verify that the source WIM was imported successfully.

### `install.wim` is missing

The media may contain `install.esd`. Run `dism /Get-WimInfo`, select the correct edition index, export it to WIM, and then import the resulting file into WDS.

### PXE worked before Sysprep but fails afterward

Do not assume the captured image is the cause. Re-test the deployment layers in order:

1. Client network adapter and virtual network
2. DHCP lease
3. WDS service
4. Boot files and PXE response
5. Firmware mode and boot order
6. WDS server connectivity
7. Captured image and Sysprep state

Test PXE with a normal client before debugging the captured image.

## Verification Checklist

- [ ] WDS01 has the expected static IP and DNS settings
- [ ] WDS01 is joined to `lab.local`
- [ ] WDS role and role services are installed
- [ ] `D:\RemoteInstall` exists and has sufficient capacity
- [ ] WDS is configured for the intended response policy
- [ ] `WDSServer` is running
- [ ] DHCP01 is operational and its scope is active
- [ ] CLIENT01 receives a valid DHCP address
- [ ] CLIENT01 can reach WDS01
- [ ] Boot image exists
- [ ] Install image exists and is valid
- [ ] Client reaches Windows Deployment Services through PXE
- [ ] Expected Windows image appears
- [ ] Test installation completes successfully
- [ ] Golden images use descriptive versioned names


## Documentation

Detailed procedures and supporting material are stored in [documentation](documentation/). Lab evidence is stored in [screenshots](screenshots/).

## Skills Demonstrated

- WDS installation and `RemoteInstall` configuration
- PXE boot and Windows PE deployment
- DHCP, DNS, AD DS, and WDS integration
- Boot-image and install-image management
- WIM, ESD, and DISM image conversion
- Golden-image versioning and standardized deployment
- PowerShell and service verification
- Layered network and PXE troubleshooting
- Infrastructure documentation and operational security

## Related Projects

- [01 - Active Directory, DNS, and Group Policy](../01-AD-DS-DNS-GPO/)
- [02 - DHCP](../02-DHCP/)
- [03 - Template-PC-Golden-Image](../03-Template-PC-Golden-Image/)
- [05 - File Server](../05-File-Server/)
- [06 - Automation](../06-Automation/)
- [07 - Print Server](../07-Print-Server/)
- [08 - Troubleshooting](../08-Troubleshooting/)

## Lab Disclaimer

This is a personal learning environment, not a production deployment infrastructure. The domain, hostnames, IP addresses, image names, firmware settings, and PXE behavior are lab examples. Adapt WDS, DHCP, relay, VLAN, firewall, and image-management settings to the organization's architecture and security requirements before production use.

**Status:** Completed / continuously improving  
**Environment:** Virtualized Windows Server lab  
**Focus:** IT support, desktop support, system administration, and OS deployment
