# DHCP Troubleshooting Guide

A staged recovery guide for DHCP addressing, scopes, leases, options, DNS registration, and PXE dependencies in the `lab.local` Windows Server lab.

## Lab Context

| Component | Example |
| --- | --- |
| Domain | `lab.local` |
| Domain controller/DNS | `DC01` / `192.168.1.100` |
| DHCP server | `DC01` or a dedicated DHCP server |
| WDS server | `WDS01` |
| Client | `CLIENT01` |
| Network | `192.168.1.0/24` |
| DHCP client range | `192.168.1.50` - `192.168.1.200` |

The repository documents both combined and dedicated DHCP layouts. Confirm which server owns DHCP before running authorization or scope commands. Confirm the actual VirtualBox network and gateway as well.

## DHCP Dependency Chain

```text
Client adapter -> Virtual/physical network -> DHCP service
    -> Authorization -> Scope -> Address availability
    -> Options -> DNS registration -> Applications/PXE
```

Do not recreate a scope before identifying the first failed stage. A working lease means DHCP may already be healthy; continue with gateway, DNS, routing, or the application instead.

## 1. Capture the Client State

Record the exact error, time, affected client, recent changes, and whether other clients are affected.

```cmd
hostname
ipconfig /all
arp -a
```

Check:

- Adapter is enabled and connected to the intended network.
- `DHCP Enabled` is `Yes` when dynamic addressing is intended.
- IPv4 address and subnet mask are expected.
- DHCP server, gateway, DNS server, and DNS suffix are expected.

A `169.254.x.x` address is APIPA and normally means the client did not receive a DHCP lease.

## 2. Verify the Network Path

In VirtualBox, all lab VMs that need DHCP must share the same intended network, for example:

```text
DC01       -> Internal Network: labnet
DHCP01     -> Internal Network: labnet
WDS01      -> Internal Network: labnet
CLIENT01   -> Internal Network: labnet
```

Check for accidental competing DHCP services from VirtualBox, a router, or another Windows Server. Multiple DHCP servers on one subnet can produce inconsistent addresses and options.

For a routed or multi-VLAN design, DHCP broadcasts require a configured relay/IP helper. If local-subnet clients work but another subnet does not, investigate relay, routing, VLAN, and firewall configuration.

## 3. Check the DHCP Service and Role

On the DHCP server:

```powershell
Get-Service DHCPServer
Get-WindowsFeature DHCP
```

Expected service state is `Running` and the DHCP role should be installed. Start or restart the service only after recording relevant errors:

```powershell
Start-Service DHCPServer
# Or, when a restart is justified:
Restart-Service DHCPServer
Get-Service DHCPServer
```

Review **Event Viewer > Applications and Services Logs > Microsoft > Windows > DHCP-Server** and record event IDs before making major changes.

## 4. Verify Authorization

In an Active Directory environment, confirm the intended DHCP server is authorized:

```powershell
Get-DhcpServerInDC
```

If it is missing, authorize the actual server using its real DNS name and address:

```powershell
Add-DhcpServerInDC -DnsName 'DC01.lab.local' -IPAddress 192.168.1.100
```

Authorization is an AD control. It does not replace checking the service, scope, network binding, or firewall.

## 5. Verify Scope and Address Availability

```powershell
Get-DhcpServerv4Scope
Get-DhcpServerv4ScopeStatistics
```

Confirm the intended scope exists, is active, matches the client subnet, and has available addresses. In DHCP Manager, inspect **IPv4 > Scope > Address Pool**, **Address Leases**, **Reservations**, and **Statistics**.

Review leases with:

```powershell
Get-DhcpServerv4Lease -ScopeId 192.168.1.0
```

If the pool is exhausted, investigate stale leases, reservations, exclusions, lease duration, and whether the scope should be expanded. Do not delete active leases indiscriminately.

## 6. Check Bindings, Reservations, and Exclusions

On a multi-adapter DHCP server, open **DHCP > Server Properties > Advanced > Bindings** and confirm DHCP is bound to the lab-facing adapter. This matters when one adapter is NAT and another is the Internal Network.

Reservations map a client identifier/MAC address to a predictable address. Exclusions prevent addresses from being leased. Confirm that:

- The reservation uses the correct client identifier.
- Reserved addresses are inside the scope.
- Static infrastructure addresses are excluded or outside the pool.
- Exclusions do not consume the entire usable range.
- No manually assigned address overlaps the dynamic pool.

A duplicate address can be investigated with `arp -a` and a targeted `ping`, but do not assume a responding host is proof of a duplicate without checking its MAC and configuration.

## 7. Verify Scope Options

```powershell
Get-DhcpServerv4OptionValue -ScopeId 192.168.1.0
```

| Option | Purpose | Example |
| --- | --- | --- |
| 003 | Default gateway | `192.168.1.1` |
| 006 | DNS server | `192.168.1.100` |
| 015 | DNS suffix | `lab.local` |
| 060/066/067 | PXE-related settings when the design requires them | Confirm against WDS and firmware |

In an AD environment, clients should normally receive the internal AD DNS server. Public DNS cannot resolve the private AD zone.

After correcting an option, renew and verify the complete client configuration:

```cmd
ipconfig /release
ipconfig /renew
ipconfig /all
```

## 8. Verify DNS Registration

DHCP supplies the configuration that lets a client reach DNS and AD; it does not provide AD authentication itself. If dynamic DNS updates are used, inspect **DHCP > IPv4 > Scope > Properties > DNS** and confirm the intended update behavior.

After renewal:

```cmd
nslookup client01.lab.local
```

If the hostname is missing or stale, investigate the client suffix, DHCP DNS options, dynamic update settings, DNS permissions, and old records. Avoid deleting records blindly while the client may still be using them.

## 9. PXE/WDS Boundary

PXE depends on DHCP, but DHCP success does not prove WDS is healthy:

```text
Client -> DHCP lease -> PXE/proxyDHCP -> WDS -> boot image
```

If the client has no IP, remain in the network/DHCP stages. If it has an IP but no boot filename or boot file, continue with PXE/WDS troubleshooting. DHCP options 60, 66, and 67 are design-dependent and should not be copied blindly from another environment.

## Common Failure Patterns

| Symptom | First proof | Next checks |
| --- | --- | --- |
| `169.254.x.x` | `ipconfig /all` | Adapter, network, service, scope, authorization |
| Renewal fails | `ipconfig /renew` error | Network path, DHCP logs, bindings, firewall |
| Existing clients work, new clients fail | Scope statistics | Pool exhaustion, exclusions, reservations |
| Wrong gateway | `ipconfig /all` | Option 003 and client renewal |
| Wrong DNS server | `ipconfig /all` | Option 006, adapter overrides, renewal |
| Hostname does not resolve | `nslookup` | Suffix, dynamic updates, DNS record |
| PXE gets no IP | PXE screen and lease list | Network and DHCP before WDS |
| DHCP works on server, not client | Client adapter/network | Virtual network, relay, bindings, firewall |
| Intermittent or inconsistent leases | Lease/server review | Competing DHCP services |

## Recovery Checklist

- [ ] Exact error, affected client, scope, and recent changes recorded.
- [ ] Client adapter is connected to the correct network.
- [ ] Competing DHCP services are disabled or intentionally designed.
- [ ] DHCP role is installed and `DHCPServer` is running.
- [ ] Intended DHCP server is authorized when required.
- [ ] Correct scope exists and is active.
- [ ] Scope has available addresses.
- [ ] DHCP is bound to the correct adapter.
- [ ] Reservations and exclusions are correct.
- [ ] Options 003, 006, and 015 are correct.
- [ ] Client lease was renewed after changes.
- [ ] Client receives the expected IP, gateway, DNS, and suffix.
- [ ] DNS registration was checked when applicable.
- [ ] PXE/WDS was investigated only after DHCP was proven.
- [ ] Event IDs and final validation are documented.

## Incident Template

```markdown
## Incident

Issue:
Affected device:
Date/time:

### Symptoms and Scope

Exact error, IP state, and whether one or multiple clients are affected.

### Evidence

Network, adapter, DHCP service, authorization, scope statistics, lease, options, DNS, and event IDs.

### Hypothesis and Testing

What was suspected and how it was tested.

### Root Cause

The confirmed cause.

### Resolution

The smallest change that fixed the issue.

### Validation

Renewed lease, expected IP/gateway/DNS, connectivity, DNS lookup, and application/PXE test.

Status: Resolved
```

## Key Principle

Start with one question: **did the client receive a valid DHCP lease?** If not, troubleshoot `network -> service -> authorization -> scope -> lease`. If yes, move on to `gateway -> DNS -> routing -> application`. For PXE, DHCP is the foundation, not the entire deployment service.
