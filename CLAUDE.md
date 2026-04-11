# CLAUDE.md — c:\apps\update

Projekt-spezifische Anweisungen für Claude Code. Ergänzt die globale Konfiguration.

## Scope

Einzel-Script-Projekt: `update.ps1` (~1600+ Zeilen) enthält die komplette Update-Logik für alle Dev-Tools. Keine Module, kein Build, keine automatisierte Test-Suite.

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

Keine automatisierte Test-Suite. Smoke-Test vor Commit:

```powershell
.\update.ps1 -DryRun
```

Plus für spezifische Sektionen gezielte Flags (z. B. `-NoScoop -NoWinget -NoTex` für schnellen Teil-Test).

## Sicherheit

- **Nie** `wsl sudo ...` — zirkulär. Immer `wsl -u root sh -c "..."`.
- Passwordless-Sudo-Setup via `Set-WslPasswordlessSudo` mit Verifikation (`sudo -n apt-get --version`)
- Keine hardcodierten Pfade zu User-Verzeichnissen
- Sektions-Skip bei fehlenden Tools, nie Fehler werfen weil ein Tool nicht installiert ist
