# CLAUDE.md — c:\apps\update

Projekt-spezifische Anweisungen für Claude Code. Ergänzt die globale Konfiguration.

## Scope

Zwei Dateien, kein Build:
- `update.ps1` — die komplette Update-Orchestrierung (alle Tool-Sektionen, Terminal-Output, Lock/Elevation/Notifications/Scheduling). Läuft weiterhin als einzelnes ausführbares Skript.
- `update.functions.ps1` — reine, seiteneffektfreie Helper (Winget-Output-Parser, Format-Helper, `-Only`-Matching, Pending-Git-Update-Record-Aufbau). Wird von `update.ps1` per Dot-Source geladen (`. (Join-Path $PSScriptRoot 'update.functions.ps1')`), existiert **nur** damit Pester-Tests diese Funktionen isoliert laden können, ohne den ganzen Update-Lauf auszulösen.

**Kein volles PowerShell-Modul** (kein `.psm1`/`.psd1`, kein Export-Modelling) — bewusst kleine, gezielte Trennung, keine Modularisierung des restlichen Skripts. Neue reine Logik-Funktionen (keine Seiteneffekte, keine Abhängigkeit von `$updatedItems`/`$failedItems`/Terminal-Output) gehören nach `update.functions.ps1`; alles mit Seiteneffekten bleibt in `update.ps1`.

## Sprache & Runtime

- **PowerShell 5.1+ (Windows PowerShell)** und **7+ (Core)** — muss auf beiden laufen
- Parallele Pre-Checks und VS Code Extension-Updates nutzen `ForEach-Object -Parallel` → **nur PS7+**, sequentieller Fallback für PS5

## Konventionen für neue Sektionen

- **Immer** via `Update-Section "Name" ($NoX -or $OnlyWsl -or $OnlyWslPackages) { Get-Command tool } { ... }` kapseln
- Externe Kommandos **immer** über `Invoke-WithRetry -Action { ... } -ActionName "..."` — Ausnahme: TeX Live nutzt `Invoke-TlMgrUpdate` (Job mit Timeout)
- Neue Sektions-Keys in `$sectionKeys` eintragen, sonst crashed die Summary
- Sektion in die passende **logische Gruppe** einsortieren (Package Managers → Shell/Terminal → System → JavaScript → Python → Other Languages → Cloud/DevOps → Dev Tooling → Typesetting), nicht am Ende anhängen
- Neuen `[switch]$NoX`-Parameter in der Parameter-Liste ergänzen, mit kurzem Kommentar
- Dokumentieren in `README.md`: Tool-Tabelle + Parameter-Tabelle

## Logging-Regel (wichtig!)

`Write-Log -Level "WARN"` ruft intern `Write-Status` auf. Wenn vorher bereits `Write-Status` aufgerufen wurde:

```powershell
Write-Status "msg" -Type Error
Write-Log "msg" -Level "INFO"   # ← INFO, NICHT WARN (sonst Doppelausgabe im Terminal)
```

## Terminal-Output

- `Write-GroupHeader "Gruppe"` — primary (Doppel-Linie + ▪, Yellow)
- `Write-SectionHeader "Sektion"` — secondary (▶, Cyan), wird von `Update-Section` selbst gesetzt
- `Write-Status "msg" -Type Action|Success|Error|Warning|Skip|Info`

## Versionierung

Bei jeder funktionalen Änderung:

1. Script-Header-Version in `update.ps1` erhöhen
2. README.md Version History Eintrag ergänzen
3. Commit-Message-Format: `vX.Y: <kurz-summary>`

## Tests

**Pester-Tests** (`tests/update.functions.Tests.ps1`) für alles in `update.functions.ps1` —
Pflicht bei jeder Änderung dort, neue Testfälle für neue Bugs/Edge-Cases ergänzen (nicht nur
manuell verifizieren und vergessen — genau das hat vor der Pester-Einführung mehrfach echte Bugs
unentdeckt gelassen, z.B. ein PowerShell-Gotcha bei `[Parameter(Mandatory)]` auf Array-Parametern
mit leeren Elementen, eine kaputte `\b`-Regex nach einer literalen Klammer).

```powershell
Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser
Invoke-Pester -Path .\tests -Output Detailed
```

Läuft automatisch in CI (`.github/workflows/lint.yml`, Job `test`) bei jedem Push.

Für `update.ps1` selbst weiterhin kein automatisierter Test — Smoke-Test vor Commit:

```powershell
.\update.ps1 -DryRun
```

Plus für spezifische Sektionen gezielte Flags (z. B. `-NoScoop -NoWinget -NoTex` für schnellen Teil-Test).

**Kritisch:** PS7-only-Syntax (Ternary `?:`, `??`, Pipeline-Chains `&&`/`||`) bricht das Parsen unter PS5.1 komplett — nicht nur zur Laufzeit. Vor jedem Commit gegen **beide** Hosts prüfen:

```powershell
$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile('update.ps1',[ref]$null,[ref]$e); $e
```

einmal mit `powershell.exe`, einmal mit `pwsh`.

`-DryRun` allein reicht bei Output-/Elevation-Änderungen nicht (überspringt Self-Update-Relaunch, echte Tool-Aufrufe). Für solche Änderungen echten Lauf testen, elevation-auslösende Sektionen aber ausschließen (`-NoWinget -NoWsl`) — ein UAC-Prompt in einer nicht-interaktiven Session hängt, `consent.exe` lässt sich nicht per `Stop-Process` beenden.

CI (`.github/workflows/lint.yml`) prüft das automatisch bei jedem Push: PS5.1+PS7-Parse-Check + PSScriptAnalyzer.

## Sicherheit

- **Nie** `wsl sudo ...` — zirkulär. Immer `wsl -u root sh -c "..."`.
- Passwordless-Sudo-Setup via `Set-WslPasswordlessSudo` mit Verifikation (`sudo -n apt-get --version`)
- Keine hardcodierten Pfade zu User-Verzeichnissen
- Sektions-Skip bei fehlenden Tools, nie Fehler werfen weil ein Tool nicht installiert ist
- Direkter Push auf `main` ist für dieses Solo-Repo etablierte Praxis (kein PR-Workflow) — überschreibt die globale "nie direkt auf main"-Regel für dieses Projekt

## Issue-Tracking

GitHub Issues aktiv genutzt (`.github/ISSUE_TEMPLATE/`). Bekannte Lücken/Follow-ups als Issue anlegen (`gh issue create`), nicht nur im Chat erwähnen und vergessen.
