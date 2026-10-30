# IT Support Toolkit

First-line diagnostics for Windows and Linux workstations — the checks a
desktop support engineer runs first when a user reports a problem.

The scripts **report only**. They change nothing on the machine, install
nothing, and need no admin rights for most checks (a few log reads say so
when they cannot read something).

## What's inside

| File | What it does |
|---|---|
| `linux/support-check.sh` | Bash triage for a Linux workstation: system info, CPU/memory/disk with thresholds, top processes, network (interfaces, gateway, internet, DNS resolution), service status, recent system errors, failed SSH logins |
| `windows/Support-Check.ps1` | PowerShell 5.1 triage for a Windows 10/11 workstation: same shape — resources, fixed drives, top processes, network (gateway, internet, DNS), key service status, recent System errors |
| `docs/first-line-checklist.md` | The human half: reproduce, ask what changed, simple fixes first, then resources, connectivity, logs, document and escalate |

Each run saves a timestamped plain-text report next to the script
(`reports/`), ready to attach to a ticket or hand to L2.

## Quick start

Linux:

```bash
chmod +x linux/support-check.sh
./linux/support-check.sh
```

Windows (PowerShell 5.1, Windows 10/11):

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\Support-Check.ps1
```

Sample summary output:

```
Support summary for LAPTOP-XYZ:
  CPU:    12.4%
  Memory: 58.2%
  Disk /: 63% [OK]

Full report saved to: reports/support-check-LAPTOP-XYZ-20261030-230000.txt
```

## How this differs from linux-server-health-check

That toolkit watches a *server* (service uptime, thresholds, alert-style
reporting). This one triages a *workstation* for a support call: network
connectivity step by step (gateway → internet → DNS), recent errors, and a
report written for a ticket — plus a Windows half and a triage checklist.

## Scope — what it does not do

- No fixes, no configuration changes, no remote access.
- No hardware repair or printer troubleshooting — those need hands on the
  machine.
- No ticketing-system or Active Directory integration.
