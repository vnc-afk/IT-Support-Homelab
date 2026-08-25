# Windows Server Active Directory, DNS, and Group Policy Lab

A hands-on Windows Server lab for building and managing a small organization's centralized identity, DNS, security, workstation-management, and Remote Desktop environment.

This module covers Active Directory Domain Services (AD DS), DNS, Organizational Units (OUs), Group Policy Objects (GPOs), users, security groups, Remote Desktop Services (RDP), auditing, testing, and troubleshooting.

> **Project type:** IT infrastructure / homelab  
> **Environment:** Windows Server and Windows 10/11  
> **Domain:** `lab.local`

## Objectives

- Deploy an Active Directory domain and domain controller.
- Configure internal DNS for domain discovery and name resolution.
- Organize users and computers with OUs.
- Manage access through security groups and least-privilege assignments.
- Apply workstation security and user restrictions through GPOs.
- Configure RDP access through a dedicated security group.
- Implement password, account-lockout, and selected audit policies.
- Verify applied settings and document repeatable troubleshooting procedures.

## Lab Architecture

```text
                         +----------------------+
                         |        DC01          |
                         | AD DS + DNS          |
                         | 192.168.1.100        |
                         +----------+-----------+
                                    |
              +---------------------+---------------------+
              |                     |                     |
       +------v------+       +------v------+       +------v------+
       | CLIENT01    |       | Servers     |       | Users       |
       | Windows     |       | FILESRV01   |       | IT          |
       | workstation |       | PRINT01     |       | HR          |
       +-------------+       | DHCP01      |       | Management  |
                             | WDS01       |       +-------------+
                             +-------------+
```

### Core Environment

| Component | Configuration |
|---|---|
| Domain | `lab.local` |
| NetBIOS domain | `LAB` |
| Domain controller | `DC01` |
| DC01 address | `192.168.1.100` |
| DNS server | `192.168.1.100` |
| Example client | `CLIENT01` |
| Example client address | `192.168.1.120` |
| RDP port | TCP `3389` |

DC01 is the primary AD DS and DNS server in the documented lab architecture. DHCP is documented separately in [02-DHCP](../02-DHCP/).

## Technologies and Tools

- Windows Server
- Windows 10/11
- Active Directory Domain Services
- DNS
- Group Policy and Group Policy Management
- Active Directory Users and Computers
- Remote Desktop Protocol
- Windows Defender Firewall
- PowerShell
- `gpupdate`, `gpresult`, `ipconfig`, and `nslookup`
- Event Viewer

## Active Directory Domain Services

### Domain Controller

| Property | Value |
|---|---|
| Hostname | `DC01` |
| Domain | `lab.local` |
| IP address | `192.168.1.100` |
| Preferred DNS | `127.0.0.1` |
| Installed roles and features | AD DS, DNS, Global Catalog, SYSVOL, NTDS database |

AD DS was installed through Server Manager. DC01 was promoted as the first domain controller in a new forest:

```text
lab.local
```

### DNS Configuration

DC01 provides internal DNS for the lab. Domain clients should use DC01 as their primary DNS server:

```text
DNS server: 192.168.1.100
```

Basic name resolution:

```powershell
nslookup lab.local
nslookup dc01.lab.local
```

Active Directory service discovery:

```text
nslookup
set type=SRV
_ldap._tcp.dc._msdcs.lab.local
```

Successful resolution of the AD SRV records should be confirmed before attempting a domain join.

## Organizational Units

The OU structure separates users, workstations, and servers so that GPOs can be targeted by role and department.

```text
lab.local
|
+-- Company Users
|   +-- IT
|   |   +-- Vince
|   |   +-- Admin
|   +-- HR
|   |   +-- Alice
|   |   +-- Bob
|   +-- Management
|       +-- Manager
|
+-- Company Computers
|   +-- Workstations
|       +-- CLIENT01
|       +-- CLIENT02
|       +-- CLIENT03
|
+-- Servers
    +-- File Server
    +-- Print Server
    +-- DHCP Server
    +-- WDS Server
```

OU placement controls policy targeting; it does not automatically grant administrative rights.

## Users and Security Groups

### Example Users

| User | Department | Purpose |
|---|---|---|
| Vince | IT | IT staff and lab administrator |
| Admin | IT | Secondary administrator test account |
| Alice | HR | HR test account |
| Bob | HR | HR test account |
| Manager | Management | Management test account |

Access is assigned through group membership rather than directly to individual users wherever practical.

### Remote Desktop Group

```text
GG-RemoteDesktop-Users
    +-- Vince
```

The dedicated group is used to grant RDP access without giving broad access to all domain users.

## Group Policy Design

Policies are separated by purpose so that they can be applied, tested, and troubleshot independently.

| GPO | Intended scope or purpose |
|---|---|
| GPO - Workstation Security | Firewall and workstation security baseline |
| GPO - Workstation Restrictions | Control Panel and Registry Editor restrictions |
| GPO - User Security | User-focused security settings |
| GPO - Company Branding | Organization identity and desktop settings |
| GPO - Network Drives | Drive mappings |
| GPO - Removable Storage | Removable-storage access control |
| GPO - Windows Update | Update management |
| GPO - Security Auditing | Selected Advanced Audit Policy settings |
| GPO - IT Users | IT user settings |
| GPO - HR Users | HR user settings |
| GPO - Management Users | Management user settings |
| GPO - Remote Desktop | RDP, NLA, group membership, and firewall settings |
| GPO - File Server Security | File server security baseline |
| GPO - Print Server Security | Print server security baseline |
| GPO - Domain Controller Security | Domain controller security baseline |

The catalog represents the documented lab design. Each GPO should be confirmed in Group Policy Management and with `gpresult` before being described as applied.

## Workstation Security

The workstation security baseline uses Windows Defender Firewall with Advanced Security:

| Profile | Firewall | Inbound | Outbound |
|---|---|---|---|
| Domain | On | Block | Allow |
| Private | On | Block | Allow |
| Public | On | Block | Allow |

Required infrastructure communication must remain available for:

```text
DC01
DNS
DHCP
FILESRV01
PRINT01
```

Test firewall changes on the intended workstation OU. Do not apply workstation-specific restrictions indiscriminately to servers or the host computer.

## Workstation Restrictions

### Control Panel

```text
User Configuration
+-- Administrative Templates
    +-- Control Panel
        +-- Prohibit access to Control Panel and PC settings
```

**Configured state:** Enabled

### Registry Editor

```text
User Configuration
+-- Administrative Templates
    +-- System
        +-- Prevent access to registry editing tools
```

**Configured state:** Enabled

The Command Prompt remains available in this learning environment to preserve troubleshooting capabilities.

## Removable Storage Security

The workstation policy is designed to deny removable-storage access:

```text
Computer Configuration
+-- Administrative Templates
    +-- System
        +-- Removable Storage Access
            +-- All Removable Storage classes: Deny all access
```

This policy is intended for the workstation OU only. Validate the scope before applying it because it can interfere with administrative and recovery workflows.

## Remote Desktop

RDP is managed centrally through Group Policy.

### RDP Policy Path

```text
Computer Configuration
+-- Administrative Templates
    +-- Windows Components
        +-- Remote Desktop Services
            +-- Remote Desktop Session Host
                +-- Connections
```

The policy **Allow users to connect remotely by using Remote Desktop Services** is enabled. Network Level Authentication is also enabled.

The RDP GPO is intended to:

- Allow RDP connections.
- Grant access through `GG-RemoteDesktop-Users`.
- Manage membership in the local `Remote Desktop Users` group.
- Enable the required Windows Firewall RDP rule.

### RDP Verification

```powershell
gpupdate /force
gpresult /r
Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections
```

Expected registry value:

```text
fDenyTSConnections : 0
```

Also verify that the user is a member of the approved security group, that NLA is enabled, and that TCP port `3389` is reachable from the authorized client.

## Password and Account Lockout Policies

These are example values for the learning environment, not production recommendations.

### Password Policy

| Setting | Lab value |
|---|---|
| Minimum password length | 8 characters |
| Password complexity | Enabled |
| Password history | 5 passwords |
| Maximum password age | 90 days |

### Account Lockout Policy

| Setting | Lab value |
|---|---|
| Lockout threshold | 5 invalid attempts |
| Lockout duration | 15 minutes |
| Reset counter after | 15 minutes |

Review these settings against the organization's security requirements before production use.

## Security Auditing

The lab uses selected Advanced Audit Policy settings rather than enabling every category and generating unnecessary event volume.

| Category | Subcategory | Audit |
|---|---|---|
| Account Logon | Audit Credential Validation | Success and failure |
| Account Management | Audit User Account Management | Success and failure |
| Logon/Logoff | Audit Logon | Success and failure |
| Policy Change | Audit Audit Policy Change | Success and failure |

After applying audit policy, verify the effective settings and review the relevant Security event log entries.

## Testing and Verification

Run these checks after implementation or a significant policy change.

### AD DS

```powershell
Get-Service NTDS
Get-ADDomain
```

### DNS

```powershell
Get-Service DNS
nslookup lab.local
nslookup dc01.lab.local
```

### Network

```powershell
ipconfig /all
ping 192.168.1.100
```

### Group Policy

```powershell
gpupdate /force
gpresult /r
gpresult /h C:\gpresult.html
```

The resulting report identifies applied and denied GPOs, computer and user policies, security filtering, and OU targeting.

## Troubleshooting Workflows

### Group Policy

1. Confirm the user or computer is in the intended OU.
2. Confirm the GPO is linked and enabled.
3. Confirm security filtering and permissions.
4. Run `gpupdate /force`.
5. Review `gpresult /r` or an HTML report.
6. Check inheritance, enforced links, conflicts, and loopback processing.
7. Review Group Policy and System event logs.
8. Test the actual setting on the workstation.

### DNS and Domain Join

1. Check the client IP address, subnet mask, and gateway.
2. Confirm the client uses `192.168.1.100` for DNS.
3. Test DC01 by IP address.
4. Test `dc01.lab.local` and `lab.local`.
5. Test `_ldap._tcp.dc._msdcs.lab.local`.
6. Confirm the required AD DS and DNS services are running.
7. Attempt the domain join only after DNS and connectivity succeed.

Useful commands:

```powershell
ipconfig /all
ping 192.168.1.100
nslookup lab.local
nslookup dc01.lab.local
```

## Final Verification Checklist

### AD DS and DNS

- [ ] Domain `lab.local` created
- [ ] DC01 is operational
- [ ] AD DS and DNS services are running
- [ ] DNS resolves `lab.local` and `dc01.lab.local`
- [ ] AD SRV records resolve
- [ ] Domain authentication works

### Active Directory

- [ ] Users created in the intended OUs
- [ ] Security groups created and populated
- [ ] Computers placed in the intended OUs
- [ ] CLIENT01 joined to the domain
- [ ] Administrative access assigned through groups

### Group Policy

- [ ] Workstation security applied to the intended OU
- [ ] User policies applied to the intended users
- [ ] Restrictions tested
- [ ] Removable-storage scope verified
- [ ] RDP policy applied
- [ ] Security auditing configured and producing expected events

### Remote Desktop

- [ ] RDP enabled
- [ ] NLA enabled
- [ ] `GG-RemoteDesktop-Users` configured
- [ ] Local RDP group membership correct
- [ ] Firewall rule enabled
- [ ] Authorized remote connection tested


## Documentation

The module's detailed procedures and supporting material are stored in [documentation](documentation/). Screenshots for lab evidence are stored in [screenshots](screenshots/).

## Skills Demonstrated

- Windows Server role installation and configuration
- AD DS forest and domain controller deployment
- DNS administration and AD service discovery
- OU design, user management, and security groups
- GPO creation, linking, filtering, and verification
- Workstation security, RDP, and Windows Firewall management
- Password, account-lockout, and audit policy configuration
- PowerShell-based verification and systematic troubleshooting
- Internal IT SOP and knowledge-base documentation

## Related Projects

- [02 - DHCP](../02-DHCP/)
- [03 - Template-PC-Golden-Image](../03-Template-PC-Golden-Image/)
- [04 - Windows Deployment Services](../04-WDS-Imaging/)
- [05 - File Server](../04-File-Server/)
- [06 - Automation](../06-Automation/)
- [07 - Print Server](../05-Print-Server/)
- [08 - Troubleshooting](../07-Troubleshooting/)

## Lab Disclaimer

This is a personal learning environment, not a production enterprise network. The domain, hostnames, IP addresses, policy values, and account names are lab examples. Review all security, authentication, DNS, and remote-access settings against the organization's requirements before production use.

**Status:** Completed / continuously improving  
**Environment:** Virtualized Windows Server lab  
**Focus:** IT support, system administration, and Windows infrastructure
