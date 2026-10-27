# Unattended runs, scheduling and notifications

[Back to README](../README.md)

## Quick setup: nightly run

```powershell
# in an elevated PowerShell, as the user whose tools should be updated
update -Schedule On                                   # daily 03:00
update -RegisterSchedule -ScheduleTime 22:30 -ScheduleFrequency Weekly   # custom time
update -Schedule Status                               # state, last/next run
update -Schedule Off                                  # pause (keeps the configuration)
update -UnregisterSchedule                            # delete it
```

The task runs `update.ps1 -Unattended -NoSelfUpdate` elevated as you (S4U logon — no password
stored, runs whether you're logged on or not). Results go to `logs/update.log`; with
`-Unattended` failures are also written to the Windows Event Log (source `UpdateScript`).

Push results to your phone instead:

```powershell
update -Unattended -NotifyWebhook https://ntfy.sh/<your-topic> -NotifyOn Always
```

## Unattended / Scheduled Operation

| Parameter | Description |
|-----------|-------------|
| `-Unattended` | Composite: implies `-Quiet`, `-NotifyEventLog`, `CmdTimeoutSec=600`; silences all interactive prompts globally |
| `-Quiet` | Suppress banner, section headers, and non-error terminal output |
| `-NoLock` | Skip lock-file guard (allows parallel runs; useful when called from a wrapper) |
| `-CmdTimeoutSec <n>` | Per-command hard timeout in seconds (0 = disabled, default 600 under `-Unattended`) |
| `-SkipNetworkCheck` | Skip the network reachability pre-check |
| `-AutoReboot` | Trigger `shutdown /r /t 60` if a pending reboot is detected after updates |
| `-Schedule On\|Off\|Status` | Manage the nightly Scheduled Task (`UpdateScript-Daily`) and exit: `On` registers it (or re-enables a disabled one), `Off` disables it but keeps its configuration, `Status` shows state, run-as account, last and next run. `On`/`Off` need an elevated shell. The task runs elevated as the registering user (S4U — no stored password) with `-Unattended -NoSelfUpdate` |
| `-RegisterSchedule` | Register (or re-register with new time/frequency) the Scheduled Task and exit |
| `-UnregisterSchedule` | Delete the Scheduled Task completely and exit |
| `-ScheduleTime <HH:mm>` | Trigger time when registering (default: `"03:00"`) |
| `-ScheduleFrequency <Daily/Weekly>` | Recurrence when registering (default: `Daily`; Weekly = Mondays) |
| `-NotifyToast` | Send a Windows toast notification after completion (requires BurntToast) |
| `-NotifyWebhook <url>` | POST a JSON summary to this URL after completion (ntfy.sh compatible) |
| `-NotifyEventLog` | Write a Windows Application Event Log entry after completion |
| `-NotifyOn <Always/Failure/Never>` | Control when notifications fire (default: `Failure`) |
