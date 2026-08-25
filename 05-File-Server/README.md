# Windows Server File Server, Shares, and Permissions Lab

A hands-on Windows Server file-services project focused on centralized storage, SMB shares, Active Directory-based access control, NTFS permissions, Access-Based Enumeration (ABE), and departmental access testing.

> **Project type:** IT infrastructure / file services / access control  
> **Environment:** Windows Server and Active Directory  
> **Domain:** `lab.local`  
> **File server:** `FILESRV01`

## Objectives

- Build centralized file storage on Windows Server.
- Create SMB shares for public and departmental data.
- Assign access through Active Directory security groups.
- Combine share permissions and NTFS permissions correctly.
- Configure inheritance and ABE where appropriate.
- Test access with representative domain accounts.
- Document permission changes and troubleshoot access failures.

## Lab Architecture

```text
                         +----------------------+
                         |        DC01          |
                         | AD DS + DNS          |
                         | 192.168.1.100        |
                         +----------+-----------+
                                    |
                         +----------v-----------+
                         |      FILESRV01       |
                         | File Server / SMB     |
                         | D:\Shares             |
                         +----------+-----------+
                                    |
             +----------------------+----------------------+
             |                      |                      |
      +------v------+       +------v------+       +------v---------+
      | IT share    |       | HR share    |       | Management     |
      | GG_IT       |       | GG_HR       |       | GG_Management  |
      +-------------+       +-------------+       +----------------+
```

The file server is joined to `lab.local` and uses Active Directory groups for authorization.

## File Server Configuration

| Property | Value |
|---|---|
| Server name | `FILESRV01` |
| Domain | `lab.local` |
| Server role | File Server |
| Protocol | SMB |
| Example IP | `192.168.1.102` |
| DNS server | `192.168.1.100` |
| Data location | `D:\Shares` |

Users should normally connect by hostname rather than IP address so that access remains independent of an address change.

## Folder and Share Layout

```text
D:\Shares
+-- Public
+-- IT
+-- HR
+-- Management
```

| Folder | Network path | Intended access |
|---|---|---|
| Public | `\\FILESRV01\Public` | General company users |
| IT | `\\FILESRV01\IT` | `LAB\GG_IT` |
| HR | `\\FILESRV01\HR` | `LAB\GG_HR` |
| Management | `\\FILESRV01\Management` | `LAB\GG_Management` |

## Active Directory Security Groups

Access is assigned to groups instead of individual users:

| Group | Intended folder |
|---|---|
| `LAB\GG_IT` | `IT` |
| `LAB\GG_HR` | `HR` |
| `LAB\GG_Management` | `Management` |

The authorization model is:

```text
User
   +-- Active Directory security group
       +-- NTFS permission
           +-- File or folder access
```

For example, adding Vince to `LAB\GG_IT` grants the access defined for the IT folder without changing the folder ACL.

## Share Permissions and NTFS Permissions

Windows evaluates both permission layers for SMB access. Effective access is the most restrictive result of the share and NTFS permissions.

### Lab share-permission model

The lab uses a simple share-level model:

| Principal | Share permission |
|---|---|
| Everyone | Full Control |

The detailed restrictions are applied through NTFS permissions. This is a common teaching model, but production environments should review whether a narrower share ACL is more appropriate.

### NTFS permissions

| Permission | Use |
|---|---|
| Full Control | Administrators and `SYSTEM` |
| Modify | Department groups and approved collaborative folders |
| Read & Execute | Read-only access |
| List Folder Contents | Folder visibility and traversal |
| Read | View file contents |
| Write | Create or update content |

Do not grant broad NTFS access such as `Everyone` or `Domain Users` to restricted departmental folders unless it is explicitly required and approved.

## Recommended NTFS Model

### Public

`D:\Shares\Public` is intended for general company documents.

| Principal | NTFS permission |
|---|---|
| `Domain Users` | Modify |
| `Administrators` | Full Control |
| `SYSTEM` | Full Control |
| `CREATOR OWNER` | Full Control |

### Department folders

| Folder | Department group | Group permission |
|---|---|---|
| `D:\Shares\IT` | `LAB\GG_IT` | Modify |
| `D:\Shares\HR` | `LAB\GG_HR` | Modify |
| `D:\Shares\Management` | `LAB\GG_Management` | Modify |

Administrative access remains available to `Administrators` and `SYSTEM` with Full Control. The exact ACL should be confirmed in Advanced Security Settings after inheritance is configured.

## Inheritance and Restricted Folders

A restricted folder may inherit broad permissions from `D:\Shares`. If those inherited permissions are not appropriate, use the following controlled procedure:

1. Open the department folder properties.
2. Select **Security > Advanced**.
3. Disable inheritance.
4. Convert inherited permissions to explicit permissions when appropriate.
5. Remove broad entries such as `BUILTIN\Users` only when they are not required.
6. Add the department security group with the required permission.
7. Keep administrative and system access intact.
8. Apply the change and test with a representative user.

Do not remove permissions blindly. Document the resulting ACL and confirm that administrators, backup processes, and system services retain required access.

## Access-Based Enumeration

ABE can hide folders that a user cannot access. For example, under a departmental share an HR user may see only the HR folder while an IT user sees only IT.

ABE improves usability and reduces unnecessary exposure of folder names, but it is not a security boundary. NTFS and share permissions remain the actual access controls.

### Share settings

| Setting | Lab configuration |
|---|---|
| Access-Based Enumeration | Enabled where appropriate |
| Allow caching of share | Disabled |
| Encrypt data access | Disabled initially |

Review caching, SMB encryption, auditing, and offline-file requirements before using this model in production.

## Creating an SMB Share

Use **Server Manager > File and Storage Services > Shares > Tasks > New Share > SMB Share - Quick**.

1. Select the file server.
2. Select the folder, such as `D:\Shares\IT`.
3. Enter the share name, such as `IT`.
4. Configure advanced settings and ABE.
5. Review the permissions and create the share.
6. Confirm the resulting UNC path: `\\FILESRV01\IT`.

## User Access Procedure

### For IT support

1. Confirm the employee's department and business need.
2. Confirm the requested share.
3. Obtain the required authorization.
4. Add the user to the appropriate AD security group.
5. Allow replication time when required.
6. Have the user sign out and sign back in if the group token is stale.
7. Test access and document the result.

### For end users

Users open File Explorer, select the address bar, and enter the UNC path provided by IT:

```text
\\FILESRV01\Public
\\FILESRV01\IT
```

Users should not modify company-folder permissions. They should contact IT Support when access is denied.

## Network Drive Mapping

Frequently used shares may be mapped as drives:

| Drive | Location | Example label |
|---|---|---|
| `I:` | `\\FILESRV01\IT` | IT Department Files |

Drive mappings can be deployed manually or through Group Policy. Mapping does not replace the underlying share and NTFS permissions.

## Permission Testing

Test with actual domain accounts or representative test accounts, not only an administrator account. Administrator access can mask incorrect departmental permissions.

| Test user | Public | IT | HR |  Management |
|---|---:|---:|---:|---:|---:|
| IT user | Allow | Allow | Deny |  Deny |
| HR user | Allow | Deny | Allow |  Deny |
| Management user | Allow | Deny |  Deny | Allow |
| Administrator | Allow | Allow | Allow |  Allow |

Record both successful and denied tests. Confirm access through the UNC path and, where relevant, through a mapped drive.

## Troubleshooting

Use a layered approach:

```text
Client
   +-- Network
       +-- DNS
           +-- File server
               +-- SMB share
                   +-- Share permissions
                       +-- NTFS permissions
                           +-- AD group membership
                               +-- User access
```

### Cannot access the server

```powershell
ping FILESRV01
nslookup FILESRV01
```

If the hostname does not resolve, verify that the client uses the organization's internal AD DNS server. Test the server and share separately:

```text
\\FILESRV01
\\FILESRV01\IT
```

### IP works but hostname does not

For example, if `\\192.168.1.102\IT` works but `\\FILESRV01\IT` fails, investigate DNS and name resolution. Confirm the hostname resolves to the correct address and that the DNS record is current.

### User sees a folder but cannot open it

Check, in order:

1. Share permissions.
2. NTFS permissions.
3. AD group membership.
4. Folder inheritance and explicit permissions.
5. Explicit Deny entries.
6. Group Policy or drive-mapping behavior.
7. The user's current logon token.

### User sees a restricted department folder

Check for `BUILTIN\Users`, `Domain Users`, unrelated groups, inherited permissions, and ABE configuration. Remember that ABE hides folders but does not deny access.

### Permission changes do not appear

The user's logon token may not include recent group membership changes:

```powershell
whoami /groups
```

Have the user sign out and sign back in, then retest. Confirm the group membership and allow for AD replication where applicable.

## Security and Change Management

- Follow least privilege and grant access through security groups.
- Avoid individual user permissions where a group can represent the role.
- Keep restricted department folders free of unnecessary broad NTFS permissions.
- Review sensitive access for HR, and Management regularly.
- Consider SMB encryption, auditing, backups, and ransomware protections based on requirements.
- Document every permission change with the requestor, affected user, department, share, old access, new access, approver, implementer, date, and reason.
- Preserve a known-good permission configuration before major changes.

Example change record:

| Field | Example |
|---|---|
| User | Employee Name |
| Department | IT |
| Share | `\\FILESRV01\IT` |
| Group added | `LAB\GG_IT` |
| Permission | Modify |
| Reason | Employee joined IT |
| Approved by | IT Manager |
| Implemented by | IT Administrator |
| Date | `YYYY-MM-DD` |

## Administrator Checklist

- [ ] `FILESRV01` joined to `lab.local`
- [ ] Static IP and AD DNS configured
- [ ] File Server role installed
- [ ] `D:\Shares` created
- [ ] Public and department folders created
- [ ] AD security groups created
- [ ] SMB shares created
- [ ] Share permissions configured
- [ ] NTFS permissions configured
- [ ] Inheritance reviewed and documented
- [ ] Unnecessary broad permissions removed from restricted folders
- [ ] ABE enabled where appropriate
- [ ] Caching and SMB encryption settings reviewed
- [ ] Representative user accounts tested
- [ ] Exceptions documented
- [ ] Permissions scheduled for periodic review

## End-User Quick Guide

1. Open File Explorer.
2. Select the address bar.
3. Enter the UNC path provided by IT.

Examples:

```text
\\FILESRV01\Public
\\FILESRV01\IT
\\FILESRV01\HR
\\FILESRV01\Management
```

If access is denied, do not change permissions. Contact IT Support with your username, the share or folder, the error message, and the action you were attempting.

## Verification Checklist

- [ ] Server resolves by hostname
- [ ] File Server role is installed and operational
- [ ] SMB shares exist with expected names
- [ ] Public access works as designed
- [ ] Department users can access their own share
- [ ] Department users are denied unauthorized shares
- [ ] Administrators retain required access
- [ ] ABE hides unauthorized folders where enabled
- [ ] `whoami /groups` confirms expected group membership
- [ ] Network drive mapping works where configured
- [ ] Permission changes are documented


## Documentation

Detailed procedures are stored in [documentation](documentation/). Lab evidence is stored in [screenshots](screenshots/).

## Skills Demonstrated

- Windows Server File Services and SMB administration
- Active Directory security groups and role-based access
- Share permissions and NTFS permissions
- Permission inheritance and explicit ACL management
- Access-Based Enumeration
- UNC paths and network drive mapping
- DNS, connectivity, and SMB troubleshooting
- Least privilege, access reviews, and change management
- User access validation and technical documentation

## Related Projects

- [01 - Active Directory, DNS, and Group Policy](../01-AD-DS-DNS-GPO/)
- [02 - DHCP](../02-DHCP/)
- [03 - Template-PC-Golden-Image](../03-Template-PC-Golden-Image/)
- [04 - WDS Imaging](../04-WDS-Imaging/)
- [06 - Automation](../06-Automation/)
- [07 - Print Server](../07-Print-Server/)
- [08 - Troubleshooting](../08-Troubleshooting/)

## Lab Disclaimer

This is a personal learning environment, not a production file-server deployment. The server name, IP addresses, domain, folder paths, permission model, and security settings are lab examples. Adapt storage, backups, auditing, SMB security, encryption, and access-control policies to the organization's requirements before production use.

**Status:** Completed / continuously improving  
**Environment:** Virtualized Windows Server lab  
**Focus:** IT support, system administration, Windows file services, SMB, NTFS, and access control
