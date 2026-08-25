# Windows Server Print Server Lab

A hands-on Windows Server project for managing shared printers, printer drivers, permissions, client connectivity, and Group Policy deployment in a small Active Directory environment.

> **Project type:** IT infrastructure / print services / endpoint management  
> **Environment:** Windows Server / Active Directory / Group Policy  
> **Domain:** `lab.local`  
> **Print server:** `PRINT01`  
> **Example printer:** `LAB-Printer01`

## Objectives

- Install and configure the Print Server role.
- Create and share a network printer.
- Assign appropriate printer permissions.
- Verify client access and print functionality.
- Deploy printers through Group Policy.
- Troubleshoot queue, driver, and spooler issues.

## Lab Architecture

```text
                         +----------------------+
                         |        DC01          |
                         | AD DS + DNS          |
                         | lab.local            |
                         +----------+-----------+
                                    |
                         +----------v-----------+
                         |       PRINT01        |
                         | Print Server         |
                         | 192.168.1.104        |
                         +----------+-----------+
                                    |
                                    | Shared printer
                                    |
                         +----------v-----------+
                         |    LAB-Printer01     |
                         | Network printer      |
                         +----------+-----------+
                                    |
                                    | Printer deployment
                                    |
                         +----------v-----------+
                         |      CLIENT01        |
                         | Domain workstation   |
                         +----------------------+
```

## Core Configuration

| Property | Value |
|---|---|
| Server name | `PRINT01` |
| Domain | `lab.local` |
| Example IP | `192.168.1.104` |
| DNS server | `DC01` |
| Role | Print and Document Services |
| Role service | Print Server |
| Shared printer | `LAB-Printer01` |
| UNC path | `\\PRINT01\LAB-Printer01` |

## Prerequisites

Before installing the role, confirm:

- Windows Server is installed and updated.
- A static IP is configured.
- The server is joined to `lab.local`.
- DNS points to `DC01`.
- The server has administrator rights.
- A domain client is available for testing.

## Install the Print Server Role

On `PRINT01`:

1. Open **Server Manager**.
2. Select **Manage > Add Roles and Features**.
3. Choose **Role-based or feature-based installation**.
4. Select the local server.
5. Expand **Server Roles**.
6. Select **Print and Document Services**.
7. Select **Print Server**.
8. Click **Install**.

## Print Management

Open:

- **Server Manager**
- **Tools**
- **Print Management**

The main structure is:

```text
Print Management
    +-- Print Servers
            +-- PRINT01
                    |-- Drivers
                    |-- Ports
                    +-- Printers
```

## Printer Setup

### Driver selection

Use a compatible driver such as:

- `Microsoft PCL6 Class Driver 2`

In production, use the manufacturer's supported driver when available.

### Add the printer

From **Print Management**:

1. Expand **Print Servers**.
2. Select `PRINT01`.
3. Open **Printers**.
4. Choose **Add Printer**.
5. Select the driver.
6. Set the printer name to `LAB-Printer01`.

### Share the printer

Open the printer properties and configure:

1. **Sharing**
2. **Share this printer**
3. Set share name to `LAB-Printer01`

UNC path:

```text
\\PRINT01\LAB-Printer01
```

### Permissions

Example model:

| Group | Permission |
|---|---|
| `Domain Users` | Print |
| `IT Support` | Print + Manage Documents |
| `Print Administrators` | Manage Printer + Manage Documents |
| `Domain Admins` | Full Control |

## Client Connection

On `CLIENT01`:

1. Press **Windows + R**.
2. Enter `\\PRINT01`.
3. Press **Enter**.
4. Double-click the shared printer.

Verify it appears in:

- **Settings > Bluetooth & devices > Printers & scanners**

Then print a test page.

## Group Policy Deployment

Group Policy can deploy shared printers automatically to workstation OUs.

Example:

```text
lab.local
+-- Company Computers
    +-- Workstations
```

Printer connection is typically:

```text
\\PRINT01\LAB-Printer01
```

On the client, run:

```powershell
gpupdate /force
```

Then verify:

```powershell
gpresult /r
```

## Queue and Spooler Troubleshooting

### Common checks

- Printer is shared
- Client can access `\\PRINT01`
- Correct GPO is applied
- Print driver is valid
- Print Spooler is running
- Queue is not stuck

### Useful commands

```powershell
Get-Service Spooler
Restart-Service Spooler
nslookup PRINT01
ping PRINT01
```

### Typical issues

- Printer does not appear
- Client cannot connect to `PRINT01`
- Print job is stuck
- Printer works on the server but not the client

## Verification Checklist

### Print Server

- [ ] `PRINT01` has a static IP
- [ ] `PRINT01` is joined to `lab.local`
- [ ] DNS is configured correctly
- [ ] Print Server role is installed
- [ ] Print Management is available

### Printer

- [ ] Driver is installed
- [ ] Printer is created
- [ ] Printer is shared
- [ ] UNC path works
- [ ] Permissions are configured
- [ ] Test page prints

### Client

- [ ] `CLIENT01` can access `PRINT01`
- [ ] Shared printer is visible
- [ ] Client test page prints
- [ ] GPO deployment is applied

## Skills Demonstrated

This project demonstrates practical experience with:

- Windows Server administration
- Print and Document Services
- Print Management
- Printer drivers and printer sharing
- Printer permissions
- Group Policy-based deployment
- DNS and SMB connectivity
- Print queue troubleshooting
- PowerShell verification

## Summary

This lab shows how a centralized Windows print server provides a consistent and manageable printing environment for a domain-based workplace. The key success factors are correct driver installation, proper sharing and permissions, reliable DNS connectivity, and verified Group Policy deployment.

