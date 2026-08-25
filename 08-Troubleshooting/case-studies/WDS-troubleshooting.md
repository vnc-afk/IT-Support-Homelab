# WDS Troubleshooting Guide

A staged recovery guide for Windows Deployment Services (WDS), PXE boot, Windows PE, and image deployment in the `lab.local` Windows Server lab.

## Deployment Chain

Troubleshoot from the client toward the image. Stop at the first failed stage.

```text
Client firmware
    |
Virtual/physical network
    |
DHCP or proxyDHCP response
    |
PXE boot program
    |
WDS/TFTP boot files
    |
boot.wim -> Windows PE
    |
install.wim -> Windows installation
```

A client with no DHCP address has not reached WDS. A client that downloads a boot file but cannot start Windows PE has a boot-image, firmware, or architecture problem. An operating-system image should only be investigated after Windows PE starts.

## Lab Context

| Component | Example |
| --- | --- |
| Domain | `lab.local` |
| Domain controller/DNS | `DC01` |
| WDS server | `WDS01` |
| DHCP server | `DC01` or a dedicated DHCP server |
| Client | `CLIENT01` |
| Network | Internal VirtualBox network named `labnet` |
| Remote install folder | `C:\RemoteInstall` |

Confirm the actual server names, addresses, firmware mode, and network before applying configuration. All VMs participating in PXE must be connected to the same intended network. Do not leave VirtualBox DHCP or another router DHCP service enabled accidentally alongside the lab DHCP service.

## Capture Evidence First

Record these values before changing configuration:

- PXE error code and the last visible screen
- Client firmware mode: UEFI or Legacy BIOS
- Client MAC address and VM network adapter
- Client IP address, DHCP server, gateway, and DNS server
- WDS service state and server configuration
- Boot and install image names, architecture, and indexes
- Relevant WDS and DHCP event IDs

Useful client checks:

```cmd
ipconfig /all
ping <WDS-server-ip>
nslookup wds01.lab.local
nslookup dc01.lab.local
```

## Stage 1: Network and DHCP

A PXE client must first reach the correct virtual or physical network and receive an address.

### Client checks

```cmd
ipconfig /all
```

A `169.254.x.x` address means Windows assigned APIPA because DHCP did not provide a lease. For a normal Windows client, renew the lease:

```cmd
ipconfig /release
ipconfig /renew
```

For a pre-boot PXE failure, verify the VM adapter is attached to the same Internal Network, for example:

```text
DC01       -> labnet
DHCP01     -> labnet
WDS01      -> labnet
CLIENT01   -> labnet
```

### DHCP server checks

```powershell
Get-Service DHCPServer
Get-DhcpServerv4Scope
Get-DhcpServerv4ScopeStatistics
Get-DhcpServerInDC
```

Confirm the service is running, the scope is active, addresses remain available, and the server is authorized when DHCP authorization is required. On a multi-adapter server, verify DHCP is bound to the lab-facing adapter.

If DHCP and WDS are on different subnets, configure and test the router or Layer 3 switch DHCP relay/IP helper. DHCP broadcasts do not cross routed networks by themselves.

## Stage 2: DNS and Server Reachability

DNS is required for reliable communication in an Active Directory deployment.

```cmd
nslookup dc01.lab.local
nslookup wds01.lab.local
```

On the domain controller:

```cmd
dcdiag /test:dns
```

The client should use the internal AD DNS server, not public DNS as its primary server. A successful ping by IP with a failed hostname lookup points to DNS, not WDS.

## Stage 3: WDS Service and Configuration

On WDS01:

```powershell
Get-Service WDSServer
Get-NetFirewallProfile
Get-NetFirewallRule | Where-Object DisplayName -Match 'WDS|Windows Deployment'
```

```cmd
sc query WDSServer
wdsutil /get-server /show:config
wdsutil /get-server /show:status
```

Confirm that:

- The WDS role is installed and initialized.
- `WDSServer` is running.
- The RemoteInstall directory exists on a drive with sufficient space.
- WDS is configured for the client firmware and architecture.
- Required firewall rules are enabled.

After a known configuration change, restart the service and immediately check its state:

```powershell
Restart-Service WDSServer
Get-Service WDSServer
```

If the service stops again, inspect Event Viewer before repeating the restart.

## Stage 4: PXE and Boot Program

Use the exact PXE message to identify the boundary:

| Symptom | Likely boundary | First checks |
| --- | --- | --- |
| `PXE-E51`, no DHCP/proxyDHCP offer | Network or DHCP | VM network, scope, DHCP service, relay |
| `PXE-E53`, no boot filename | PXE/WDS response | WDS response policy, DHCP/PXE design, firmware mode |
| IP and PXE response, no boot download | TFTP/firewall/WDS | WDS service, firewall, RemoteInstall, boot program |
| Boot file downloads, Windows PE fails | Boot image/firmware | `boot.wim`, architecture, UEFI/BIOS compatibility |

DHCP options 60, 66, and 67 are not a universal fix. Their use depends on the WDS/PXE design, firmware, and whether proxyDHCP is available. Do not copy a boot filename from another environment. If options are used, verify them against the client firmware and WDS configuration.

## Stage 5: Boot Images and Windows PE

`boot.wim` starts the Windows PE deployment environment. It is not the installed operating system image.

In WDS, verify:

```text
Servers -> WDS01 -> Boot Images
```

The boot image should be imported from installation media, commonly:

```text
\sources\boot.wim
```

Check that the image matches the client architecture and firmware path. A capture image created from a boot image must also be added back under **Boot Images** before it can be selected for capture.

## Stage 6: Install Images

`install.wim` contains the operating system that Windows PE applies to the target disk.

| Image | Function |
| --- | --- |
| `boot.wim` | Starts Windows PE |
| `install.wim` | Contains installable Windows editions |
| `install.esd` | Compressed installation image that may need conversion |
| `capture.wim` | Captured reference workstation image |

In WDS, verify:

```text
Servers -> WDS01 -> Install Images
```

Inspect image indexes before importing or selecting an edition:

```cmd
DISM /Get-WimInfo /WimFile:C:\Images\install.wim
```

If installation media contains only `install.esd`, identify the desired index and export it to WIM:

```cmd
DISM /Get-WimInfo /WimFile:D:\sources\install.esd
DISM /Export-Image /SourceImageFile:D:\sources\install.esd /SourceIndex:6 /DestinationImageFile:C:\install.wim /Compress:max /CheckIntegrity
DISM /Get-WimInfo /WimFile:C:\install.wim
```

Replace the source index with the Windows edition required by the lab.

## Golden Image and Sysprep Checks

For a reference workstation:

```text
Install Windows -> Configure applications -> Update -> Sysprep -> Capture -> Import into WDS
```

Before capture, confirm the edition with `winver` or:

```powershell
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion
```

Run Sysprep with **OOBE**, **Generalize**, and **Shutdown** selected:

```text
C:\Windows\System32\Sysprep\sysprep.exe
```

Do not boot the generalized reference machine back into normal Windows before capture. If the VM enters setup repeatedly, disconnect the installation ISO, check boot order, and start the correct capture/PXE process.

## Logs and Diagnostics

Inspect these locations and record event IDs:

```text
Event Viewer
-> Applications and Services Logs
-> Microsoft
-> Windows
-> Deployment-Services-Diagnostics
-> Deployment-Services-Server
```

Also check DHCP-Server logs when the client does not receive an address or PXE response. Use the WDS error message and the last successful stage to avoid changing unrelated settings.

## Recovery Checklist

- [ ] Client is using the correct virtual or physical network.
- [ ] Client firmware mode is known: UEFI or Legacy BIOS.
- [ ] Client receives a DHCP address or the PXE relay is working.
- [ ] DHCP scope is active, authorized, and not exhausted.
- [ ] Client DNS points to internal AD DNS.
- [ ] DC and WDS hostnames resolve.
- [ ] `WDSServer` is running.
- [ ] WDS is initialized and RemoteInstall has free space.
- [ ] Required firewall rules are enabled.
- [ ] PXE response and boot program match the firmware mode.
- [ ] `boot.wim` is present and compatible.
- [ ] `install.wim` or the intended captured image is imported.
- [ ] Image index and Windows edition are correct.
- [ ] Error messages and Event Viewer evidence are documented.
- [ ] Deployment succeeds from PXE through Windows installation.

## Incident Template

```markdown
## Incident

Issue:
Affected device:
Date/time:
PXE error or last visible stage:

### Scope

One client, multiple clients, or all PXE clients.

### Evidence

Network, DHCP, DNS, firmware mode, WDS status, image names, and event IDs.

### Hypothesis and Testing

What failed first and how it was tested.

### Root Cause

The confirmed cause.

### Resolution

The smallest configuration or image change that fixed the issue.

### Validation

PXE response, boot file download, Windows PE, image selection, and installation result.

Status: Resolved
```

## Golden Rule

Treat WDS as a chain, not a single service:

```text
Network -> DHCP -> PXE/proxyDHCP -> WDS/TFTP -> boot.wim -> Windows PE -> install.wim
```

Troubleshoot left to right. If the client has no address, investigate DHCP. If it cannot download a boot file, investigate PXE, WDS, TFTP, or firewall. If Windows PE starts but no operating system is available, investigate the install image.
