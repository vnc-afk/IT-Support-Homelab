# IT Support Troubleshooting Knowledge Base

A practical knowledge base for diagnosing Windows infrastructure and workstation incidents across the `lab.local` environment. The guides are written for repeatable L1/L2 support: collect evidence, isolate the failing layer, test one hypothesis, apply the smallest fix, and verify the original symptom.

## Case Studies

| Guide | Primary failure area | Typical symptoms |
| --- | --- | --- |
| [AD, GPO & DNS Troubleshooting](case-studies/AD-and-GPO-and-DNS-troubleshooting.md) | Active Directory, DNS, domain join, and Group Policy | Cannot join the domain, cannot find a domain controller, or policy does not apply |
| [DHCP Troubleshooting](case-studies/DHCP-troubleshooting.md) | DHCP scopes, leases, authorization, and options | `169.254.x.x`, missing gateway, incorrect DNS, or no lease |
| [Golden Image Troubleshooting](case-studies/Golden-Image-troubleshooting.md) | Template preparation and Sysprep | Image capture fails, duplicate identity, or deployment is inconsistent |
| [WDS Troubleshooting](case-studies/WDS-troubleshooting.md) | PXE, TFTP, boot images, and install images | PXE client receives no boot file or Windows PE cannot start |

## Lab Context

```text
                         Internal lab network
                              lab.local
                                  |
       +--------------------------+--------------------------+
       |                          |                          |
   +---v---+                  +---v----+                 +---v----+
   | DC01  |                  | DHCP01  |                 | WDS01  |
   | AD DS |                  | DHCP    |                 | PXE    |
   | DNS   |                  |         |                 | Images |
   +---+---+                  +--------+                 +---+----+
       |                                                     |
       +----------------------+------------------------------+
                              |
                  +-----------+-----------+
                  |                       |
              +---v----+              +---v----+
              |FILESRV01|              | PRINT01|
              | SMB     |              | Print  |
              +---+----+              +--------+
                  |
             +----v-----+
             | CLIENT01 |
             | Windows  |
             +----------+
```

| Host | Role | Example address |
| --- | --- | --- |
| `DC01` | AD DS and DNS | `192.168.1.100` |
| `DHCP01` | DHCP | `192.168.1.101` |
| `WDS01` | WDS, PXE, and images | `192.168.1.102` |
| `FILESRV01` | SMB file shares | `192.168.1.103` |
| `PRINT01` | Print services | `192.168.1.104` |
| `CLIENT01` | Domain-joined workstation and test client | DHCP |

> These are documented lab values. Confirm the actual VirtualBox network, gateway, DNS server, and host addresses before applying commands.

## Dependency Order

Troubleshoot from the foundation upward. A failure earlier in the chain can make every later service appear broken.

```text
Network link
    |
IP address and gateway
    |
DNS resolution
    |
Active Directory discovery and time
    |
Domain membership and secure channel
    |
Group Policy
    |
Applications and user experience
```

For WDS and PXE, use this order:

```text
Network -> DHCP lease -> PXE response -> WDS/TFTP -> boot.wim -> Windows PE -> install.wim
```

Do not investigate missing WDS images until the client can obtain an IP address and PXE configuration.

## First Response Checklist

Record the following before changing configuration:

- Affected user, computer, service, and exact error message
- Start time, recent changes, and whether the issue is reproducible
- Whether the issue affects one user, one computer, several computers, or the whole lab
- Hostname, logged-in identity, IP address, gateway, DNS server, and domain
- Relevant Event Viewer entries and service status

Useful initial commands on a Windows client:

```cmd
hostname
whoami
ipconfig /all
ping <gateway-or-server-ip>
nslookup <hostname>
gpresult /r
```

## Command Reference

| Area | Command | Purpose |
| --- | --- | --- |
| Network | `ipconfig /all` | Review address, gateway, DNS, and DHCP details |
| Network | `ipconfig /release` and `ipconfig /renew` | Rebuild a DHCP lease |
| DNS | `ipconfig /flushdns` | Clear the local resolver cache |
| DNS | `Resolve-DnsName dc01.lab.local` | Test name resolution with PowerShell |
| AD DNS | `Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.lab.local` | Test domain-controller discovery records |
| AD | `nltest /dsgetdc:lab.local` | Locate a domain controller |
| AD | `nltest /sc_verify:lab.local` | Verify the workstation secure channel |
| AD | `Test-ComputerSecureChannel` | Test the secure channel in PowerShell |
| AD | `dcdiag /test:dns` | Run DNS diagnostics on a domain controller |
| GPO | `gpupdate /force` | Refresh computer and user policy |
| GPO | `gpresult /h C:\Temp\gpresult.html` | Create a detailed policy report |
| DHCP | `Get-DhcpServerv4ScopeStatistics` | Check scope utilization |
| DHCP | `Get-DhcpServerv4Lease -ScopeId 192.168.1.0` | Review active leases |
| DHCP | `Get-DhcpServerInDC` | List authorized DHCP servers |
| WDS | `Get-Service WDSServer` | Check the WDS service |
| WDS | `wdsutil /get-server /show:status` | Review WDS status |

`repadmin /replsummary` and `repadmin /showrepl` are useful when the environment has multiple domain controllers. They are not normally needed for a single-DC lab.

## Quick Decision Paths

### Client Has No IP Address

```text
ipconfig /all
    |
169.254.x.x or no address?
    |
Check VirtualBox network and link
    |
Check DHCPServer service
    |
Check scope state and available addresses
    |
Check DHCP authorization and scope options
    |
Run ipconfig /renew and verify gateway/DNS
```

### Client Has an IP but Cannot Reach the Domain

```text
Ping DC01 by IP
    |
Fails -> network, firewall, or routing
    |
Works -> nslookup dc01.lab.local
    |
Fails -> DNS server or DNS record
    |
Works -> nltest /dsgetdc:lab.local
    |
Fails -> AD discovery, time, or domain connectivity
```

### Domain-Joined Client Does Not Receive a GPO

```text
Confirm the user/computer OU
    |
Confirm the GPO is linked and enabled
    |
Check security and WMI filtering
    |
Check inheritance and precedence
    |
Run gpupdate /force
    |
Review gpresult /r or the HTML report
    |
Verify the actual setting, not only the report
```

### Client Cannot PXE Boot

```text
Client starts PXE
    |
No IP -> network or DHCP
    |
IP but no PXE response -> DHCP/PXE/WDS configuration
    |
PXE response but no boot file -> WDS/TFTP/firewall
    |
Windows PE fails -> boot image
    |
Install image missing -> WDS install image configuration
```

## Incident Template

Use this template for new case studies or support notes:

```markdown
## Incident

Issue:
Affected device:
Affected user:
Date/time:

### Symptoms

Exact error message and observed behavior.

### Scope

One user, one computer, multiple computers, service-wide, or network-wide.

### Initial Checks

Commands, configuration, logs, and results.

### Hypothesis and Testing

What was suspected and how it was tested.

### Root Cause

The confirmed cause.

### Resolution

The smallest change that fixed the issue.

### Validation

How the original symptom and related functionality were verified.

### Preventive Action

Documentation, monitoring, configuration, or training change.

Status: Resolved
```

## Troubleshooting Principles

- Capture the exact error instead of summarizing it as “not working.”
- Change one relevant variable at a time whenever practical.
- Compare behavior with a known-good user or workstation.
- Check both configuration and service state before restarting anything.
- Treat DNS, time synchronization, and OU placement as domain-join fundamentals.
- Validate the user-facing behavior after the technical check passes.
- Document the evidence that proved the root cause, not only the final fix.

## Related Modules

- [01 - AD DS, DNS & GPO](../01-AD-DS-DNS-GPO/README.md)
- [02 - DHCP](../02-DHCP/README.md)
- [03 - Golden Image](../03-Template-PC-Golden-Image/README.md)
- [04 - WDS Imaging](../04-WDS-Imaging/README.md)
- [05 - File Server](../05-File-Server/README.md)
- [06 - Automation](../06-Automation/README.md)
- [07 - Print Server](../07-Print-Server/README.md)

The goal is to answer, with evidence: **what failed, why it failed, how it was fixed, and how the fix was verified.**
