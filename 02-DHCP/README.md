# Windows Server DHCP Lab

A hands-on Windows Server lab for deploying, configuring, testing, and troubleshooting Dynamic Host Configuration Protocol (DHCP) in a small Active Directory environment.

This module documents how DHCP works with Active Directory Domain Services (AD DS), DNS, Windows clients, and network infrastructure to provide consistent IP configuration.

> **Project type:** IT infrastructure / homelab  
> **Environment:** Windows Server and Windows 10/11  
> **Network:** `192.168.1.0/24`  
> **Domain:** `lab.local`

## Objectives

- Install and authorize the Windows Server DHCP role.
- Create and activate a scope with appropriate address ranges and options.
- Configure reservations for devices that need predictable addresses.
- Verify client leases, DNS settings, gateway configuration, and connectivity.
- Troubleshoot failed leases, incorrect DNS settings, and DHCP service issues.
- Document security practices and repeatable verification procedures.

## Lab Architecture

```text
                         +----------------------+
                         |        DC01          |
                         | AD DS + DNS          |
                         | 192.168.1.100        |
                         +----------+-----------+
                                    |
                         +----------v-----------+
                         |       DHCP01         |
                         | DHCP                 |
                         | 192.168.1.101        |
                         +----------+-----------+
                                    |
                 +------------------+------------------+
                 |                  |                  |
          +------v------+    +------v------+    +------v------+
          | CLIENT01    |    | CLIENT02    |    | Printer01   |
          | DHCP client |    | DHCP client |    | Reservation |
          +-------------+    +-------------+    +-------------+
```

DHCP is intentionally separated from the domain controller. The documented roles are:

| Host | Role | Addressing |
|---|---|---|
| Router | Default gateway | `192.168.1.1` |
| DC01 | AD DS and DNS | Static: `192.168.1.100` |
| DHCP01 | DHCP | Static: `192.168.1.101` |
| WDS01 | Windows Deployment Services | Static: `192.168.1.102` |
| CLIENT01/CLIENT02 | Windows workstations | DHCP |
| Printer01 | Network printer | DHCP reservation |

WDS/PXE configuration is documented separately in [03-WDS-Imaging](../03-WDS-Imaging/).

## Network Plan

| Setting | Value |
|---|---|
| Network | `192.168.1.0/24` |
| Subnet mask | `255.255.255.0` |
| Default gateway | `192.168.1.1` |
| Infrastructure range | `192.168.1.100` - `192.168.1.109` |
| DHCP client range | `192.168.1.110` - `192.168.1.200` |
| DNS server | `192.168.1.100` |
| DNS suffix | `lab.local` |

The infrastructure addresses are outside the DHCP pool, so they do not need to be excluded from the scope. Confirm the gateway and address plan against the actual network before applying this configuration elsewhere.

## DHCP Server Configuration

DHCP01 uses a static address because a server should not depend on the service it provides for its own network configuration.

| Property | Value |
|---|---|
| Hostname | `DHCP01` |
| IP address | `192.168.1.101` |
| Subnet mask | `255.255.255.0` |
| Gateway | `192.168.1.1` |
| DNS server | `192.168.1.100` |
| Domain | `lab.local` |

### Role Installation

The DHCP Server role is installed through **Server Manager > Manage > Add Roles and Features > Role-based or feature-based installation > DHCP Server**. After installation, complete the DHCP post-installation configuration and authorize the server in Active Directory when the server is domain-joined.

### Scope

| Property | Value |
|---|---|
| Scope name | `LAB-NETWORK` |
| Network | `192.168.1.0/24` |
| Start address | `192.168.1.110` |
| End address | `192.168.1.200` |
| Subnet mask | `255.255.255.0` |
| Lease duration | 8 days |
| State | Active |

### Scope Options

| Option | Setting | Purpose |
|---|---|---|
| 003 | `192.168.1.1` | Default gateway |
| 006 | `192.168.1.100` | Internal AD-integrated DNS server |
| 015 | `lab.local` | DNS domain suffix |

Domain clients should use the internal DNS server rather than public resolvers such as `8.8.8.8` or `1.1.1.1`. Public DNS can be configured as a forwarder on the internal DNS server when required.

### Reservations

A reservation keeps a device on DHCP while assigning it a predictable address based on its MAC address.

| Device | MAC address | Reserved address |
|---|---|---|
| Printer01 | `AA-BB-CC-DD-EE-FF` | `192.168.1.120` |

Reservations are useful for printers, network appliances, cameras, and other devices that need stable addressing. Replace the example MAC address with the device's actual hardware address.

## Verification

Run these checks after installation and after significant configuration changes.

### DHCP Server

```powershell
Get-Service DHCPServer
Get-DhcpServerv4Scope
Get-DhcpServerv4Lease -ScopeId 192.168.1.0
Get-DhcpServerv4OptionValue -ScopeId 192.168.1.0
```

Expected service state: `Running`. The scope should be active and show the expected address pool and options.

### Windows Client

Configure the client adapter to obtain an IP address and DNS server automatically, then run:

```powershell
ipconfig /release
ipconfig /renew
ipconfig /all
```

Verify the following values:

| Check | Expected example |
|---|---|
| IPv4 address | `192.168.1.110` or another address in the pool |
| DHCP server | `192.168.1.101` |
| DNS server | `192.168.1.100` |
| DNS suffix | `lab.local` |
| Default gateway | `192.168.1.1` |

### Connectivity and DNS

```powershell
ping 192.168.1.101
ping 192.168.1.100
ping 192.168.1.1
nslookup lab.local
nslookup dc01.lab.local
```

For domain discovery, verify the AD service record as well:

```text
nslookup
set type=SRV
_ldap._tcp.dc._msdcs.lab.local
```

The DNS responses should come from the internal DNS server on DC01.

## Troubleshooting

### Client receives a `169.254.x.x` address

An Automatic Private IP Addressing (APIPA) address usually means the client did not receive a DHCP lease.

1. Confirm the `DHCPServer` service is running.
2. Confirm the `LAB-NETWORK` scope exists and is active.
3. Check that the scope has available addresses.
4. Confirm the client is connected to the correct network or virtual switch.
5. Test connectivity to DHCP01 and check firewall or network-device rules.
6. Check for an unauthorized or competing DHCP server.
7. Renew the client lease with `ipconfig /release` and `ipconfig /renew`.
8. Review DHCP and System event logs for errors.

### Client has Internet access but domain operations fail

Run `ipconfig /all` and confirm the client uses `192.168.1.100` for DNS. Then test `lab.local`, `dc01.lab.local`, and the AD SRV record. A client can reach the Internet through the gateway while still failing domain authentication when it uses an external DNS server.

### DHCP service is stopped

```powershell
Get-Service DHCPServer
Restart-Service DHCPServer
```

Use the restart command only after checking the impact on active clients. Review **Event Viewer > Applications and Services Logs > Microsoft > Windows > DHCP-Server** and **Windows Logs > System** for the cause.

## Security and Operations

- Keep DHCP servers on static addresses and restrict administrative access.
- Authorize DHCP in Active Directory and monitor for unauthorized DHCP services.
- Keep infrastructure addresses outside the dynamic pool.
- Use meaningful scope and reservation names.
- Monitor leases and DHCP event logs.
- Back up the DHCP configuration before major changes.
- Keep Windows Server patched and limit DHCP exposure to trusted network segments.
- Do not upload passwords, credentials, license keys, or production network details in screenshots.

## Verification Checklist

### DHCP Server

- [ ] DHCP Server role installed
- [ ] DHCP01 has a static IP address
- [ ] DHCP server authorized
- [ ] DHCP service running
- [ ] `LAB-NETWORK` scope created and active
- [ ] Address pool and lease duration correct
- [ ] Gateway, DNS server, and DNS suffix configured
- [ ] Leases are being issued

### Client and Domain Integration

- [ ] Client uses automatic IPv4 and DNS configuration
- [ ] Client receives an address from the expected pool
- [ ] DHCP server and DNS server are correct
- [ ] Gateway and domain controller are reachable
- [ ] `lab.local` and `dc01.lab.local` resolve
- [ ] AD SRV records resolve

## Skills Demonstrated

- Windows Server DHCP role installation and administration
- IPv4 addressing, subnetting, scopes, leases, and reservations
- DHCP integration with AD DS and DNS
- Client network configuration and verification
- PowerShell, `ipconfig`, `ping`, and `nslookup`
- Event log analysis and systematic troubleshooting
- Infrastructure documentation and operational security

## Related Projects

- [01 - Active Directory, DNS & Group Policy](../01-AD-DS-DNS-GPO/)
- [03 - Template-PC-Golden-Image](../03-Template-PC-Golden-Image/)
- [04 - Windows Deployment Services](../04-WDS-Imaging/)
- [05 - File Server](../04-File-Server/)
- [07 - Print Server](../05-Print-Server/)
- [08 - Troubleshooting](../07-Troubleshooting/)

## Lab Disclaimer

This is a personal learning environment, not a production enterprise network. The domain, hostnames, IP addresses, lease duration, and policy values are lab examples. Review any DHCP design against the organization's addressing plan, security requirements, and operational procedures before production use.

**Status:** Completed / continuously improving  
**Focus:** IT support, system administration, and Windows infrastructure
