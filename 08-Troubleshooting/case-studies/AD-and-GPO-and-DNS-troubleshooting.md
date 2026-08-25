# Active Directory, DNS, and Group Policy Troubleshooting

A layered troubleshooting guide for domain connectivity, Active Directory (AD DS), DNS, domain membership, and Group Policy (GPO) issues in the `lab.local` Windows Server lab.

## Lab Context

| Component | Example |
| --- | --- |
| Domain | `lab.local` |
| Domain controller and DNS | `DC01` / `192.168.1.100` |
| Client | `CLIENT01` |
| Client DNS | Internal AD DNS, normally `192.168.1.100` |

## Diagnostic Order

```text
Network -> IP configuration -> DNS -> AD discovery -> Time
    -> Domain membership -> Secure channel -> OU/object -> GPO -> User experience
```

Fix connectivity and DNS before AD or GPO. A GPO can be correctly linked and still fail when the client cannot locate a domain controller, authenticate, access SYSVOL, or maintain the correct time.

## 1. Capture the Baseline

Record the exact error, affected user and computer, start time, recent changes, and scope. Compare with a known-good workstation when possible.

On the client:

```cmd
hostname
whoami
whoami /user
ipconfig /all
systeminfo
```

Confirm IPv4 address, subnet mask, gateway, DNS server, DNS suffix, DHCP server, domain, and whether the issue affects user or computer policy.

## 2. Test Network and DNS

Test the domain controller by address and name:

```cmd
ping 192.168.1.100
ping dc01
ping dc01.lab.local
```

If the IP works but the hostname fails, focus on DNS. The client should use internal AD DNS rather than public DNS such as `8.8.8.8` or `1.1.1.1` as its primary server.

```cmd
nslookup lab.local
nslookup dc01.lab.local
nslookup 192.168.1.100
```

The reverse lookup is useful when a reverse zone exists, but it is not required for basic AD operation.

After a known DNS change:

```cmd
ipconfig /flushdns
ipconfig /registerdns
```

On the domain controller:

```powershell
Get-Service DNS
Get-Service NTDS
Get-Service Netlogon
dcdiag /test:dns
```

Check **DNS Manager > Forward Lookup Zones > `lab.local`** for the DC A record. For AD service discovery, verify the SRV record:

```powershell
Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.lab.local
```

If the SRV record is missing, investigate Netlogon, dynamic registration, AD-integrated DNS, and `dcdiag` results.

## 3. Test Domain Controller Discovery and Time

```cmd
nltest /dsgetdc:lab.local
w32tm /query /status
w32tm /query /source
```

Kerberos is sensitive to clock differences. A large time offset can cause domain login, secure-channel, GPO, and file-share failures. Resynchronize only after confirming the intended time source:

```cmd
w32tm /resync
```

## 4. Verify Domain Membership and Secure Channel

```powershell
Get-CimInstance Win32_ComputerSystem | Select-Object Name, Domain, PartOfDomain
Test-ComputerSecureChannel
```

Equivalent discovery and secure-channel checks:

```cmd
nltest /sc_verify:lab.local
```

Expected membership is `PartOfDomain : True` and domain `lab.local`. If the secure channel is broken, repair it with appropriate domain credentials:

```powershell
Test-ComputerSecureChannel -Repair -Credential (Get-Credential)
```

Use repair carefully and verify the result. Do not unjoin and rejoin a computer as the first response when a secure-channel repair or DNS correction can resolve the issue.

## 5. Check AD Objects and OU Placement

In **Active Directory Users and Computers**, confirm that the computer and user exist and are in the intended OU hierarchy:

```text
lab.local
+-- Company Users
|   +-- IT
|   +-- HR
|   +-- Management
+-- Company Computers
    +-- Workstations
    +-- Servers
```

OU placement controls GPO scope. A computer in the default `Computers` container will not receive a GPO linked only to a custom Workstations OU. A user's OU and computer's OU can be different, so check both.

After group membership changes, sign out and sign back in so the user receives a new security token:

```cmd
whoami /groups
```

## 6. Understand GPO Scope

GPO processing follows the general scope order:

```text
Local -> Site -> Domain -> Parent OU -> Child OU
```

Check all of the following before changing a policy:

- Correct user or computer OU
- GPO link exists on the intended site, domain, or OU
- GPO and required settings are enabled
- Security filtering includes the target
- Target has `Read` and `Apply Group Policy` permissions
- WMI filtering is not excluding the target
- Inheritance is not unexpectedly blocked
- An enforced or higher-precedence GPO is not winning
- Loopback processing is understood when configured

Computer Configuration follows the computer object. User Configuration follows the user object, unless loopback processing changes that behavior. Do not enable loopback, Block Inheritance, or Enforced without a documented design reason.

## 7. Prove What Applied

Refresh policy, then inspect computer and user results separately:

```cmd
gpupdate /force
gpresult /scope computer /r
gpresult /scope user /r
md C:\Temp 2>$null
gpresult /h C:\Temp\gpresult.html
```

Review **Applied Group Policy Objects** and **Denied Group Policy Objects**, including the listed denial reason. An applied GPO does not mean every setting inside it won; identify the winning policy when settings conflict. Confirm the actual user-facing or computer setting after the report.

For processing errors, inspect:

```text
Event Viewer
-> Applications and Services Logs
-> Microsoft
-> Windows
-> GroupPolicy
-> Operational
```

Also check the `gpsvc` and `Netlogon` services:

```powershell
Get-Service gpsvc
Get-Service Netlogon
```

## 8. Verify SYSVOL and NETLOGON

GPOs have an AD component and a SYSVOL file component. A GPO can appear in Group Policy Management while SYSVOL or replication is unhealthy.

From a domain client:

```text
\\lab.local\SYSVOL
\\lab.local\NETLOGON
```

On the domain controller:

```cmd
net share
```

Both `SYSVOL` and `NETLOGON` should be present. If they are unavailable, investigate DNS, SMB, Netlogon, firewall, SYSVOL state, and replication. For multi-DC environments:

```cmd
repadmin /replsummary
repadmin /showrepl
```

Replication checks do not apply to a single-domain-controller lab.

## Common Failure Patterns

| Symptom | First proof | Likely next area |
| --- | --- | --- |
| Domain name cannot be found | `nslookup lab.local` | Client DNS, DNS service, zone |
| DC hostname does not resolve | `nslookup dc01.lab.local` | A record, DNS server, network |
| DC cannot be discovered | `nltest /dsgetdc:lab.local` | SRV records, Netlogon, time, firewall |
| Domain join fails | `ipconfig /all`, DNS, time | DNS, DC reachability, credentials |
| Login or share access fails | `w32tm`, secure channel | Time, Netlogon, trust, permissions |
| Computer GPO missing | `gpresult /scope computer /r` | Computer OU, link, filtering |
| User GPO missing | `gpresult /scope user /r` | User OU, token, link, filtering |
| GPO appears but setting loses | HTML GPO report | Precedence, conflicts, restart/logoff |
| SYSVOL unavailable | `\\lab.local\SYSVOL` | DNS, SMB, Netlogon, replication |

## End-to-End Verification Flow

```text
ipconfig /all
    |
Can the client reach DC01?
    +-- No -> network, firewall, or routing
    |
nslookup dc01.lab.local and lab.local
    +-- No -> DNS server, zone, or records
    |
nltest /dsgetdc:lab.local
    +-- No -> SRV, Netlogon, time, or AD connectivity
    |
Confirm domain membership and Test-ComputerSecureChannel
    +-- No -> membership or secure-channel repair
    |
Check user/computer OU, link, filtering, inheritance, and precedence
    |
gpupdate /force -> gpresult -> Event Viewer -> actual setting
```

## Recovery Checklist

- [ ] Client has the expected IP address, gateway, DNS server, and suffix.
- [ ] `lab.local`, `dc01.lab.local`, and the AD SRV record resolve.
- [ ] DNS, NTDS, and Netlogon services are running where applicable.
- [ ] Domain controller discovery succeeds.
- [ ] Client time is synchronized with the domain.
- [ ] Client is domain joined and the secure channel is healthy.
- [ ] User and computer objects exist in the intended OUs.
- [ ] GPO is linked, enabled, and permitted by filtering and delegation.
- [ ] Inheritance, precedence, and loopback behavior are understood.
- [ ] `gpupdate` and `gpresult` confirm the expected policy result.
- [ ] SYSVOL and NETLOGON are accessible.
- [ ] The actual user-facing or computer setting was verified.

## Incident Template

```markdown
## Incident

Issue:
Affected device:
Affected user:
Date/time:

### Symptoms and Scope

Exact error, observed behavior, and whether one or multiple users/computers are affected.

### Evidence

Network, DNS, DC discovery, time, domain membership, secure channel, OU, GPO results, and event IDs.

### Hypothesis and Testing

What was suspected and how it was tested.

### Root Cause

The confirmed cause.

### Resolution

The smallest change that fixed the issue.

### Validation

Commands and user-facing behavior used to confirm the fix.

Status: Resolved
```

## Core Principle

Use evidence to move from `IP -> DNS -> DC -> time -> domain membership -> OU -> GPO -> gpresult -> event logs -> actual behavior`. Do not troubleshoot GPO first when DNS or domain connectivity is failing, and do not consider a policy fixed until the original behavior has been verified.
