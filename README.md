# rt3engine-windows

Windows-side companion for [rt3engine](https://github.com/diegoami/rt3engine).

## Purpose

Own tasks that need a native Windows session rather than the Linux/Wine
development environment:

- AutoHotkey v2 window/input automation for Railroad Tycoon 3;
- native screen/window capture;
- controlled original save generation and read-only export;
- future Windows-only diagnostics needed by rt3engine.

This is an oracle/tooling project, not a second engine implementation.

## Environment boundary

- Use a **disposable copy** of RT3 for oracle runs. The owner's original GOG
  installation remains read-only.
- A native session may report missing hardware-accelerated DirectX 8.1 while
  remaining playable after the warning is dismissed. Record and dismiss that
  warning with OK, then verify the actual game window. Stop only if no playable
  window follows. Do not bypass or alter the game's device check.
- Original assets and save bytes never enter Git. `.gmc`/`.gms`/`.sav`,
  captures and generated outputs are ignored.
- Exported saves are copied to rt3engine's gitignored `review-tmp/saves/`
  area **only when a private transfer is actually possible and requested**.
  A pure Windows installation uses its own private output directory named by
  `RT3_PRIVATE_OUT`; no WSL path or shared filesystem is assumed.
- Derived JSON evidence may be committed by rt3engine after independent review.
- If a workflow also drives a Linux emulator/display, honor rt3engine's shared
  capture lock in `tools/oracle/capture_lock.py`.

## Initial diagnostic

`Probe-RT3.ahk` is an AutoHotkey v2 diagnostic that starts RT3 from a supplied
`RT3_HOME`, waits for its window, records client dimensions, and captures any
`Program Error` text. It does not claim save automation yet.

Example (PowerShell):

```powershell
$env:RT3_HOME = 'D:\RT3-oracle'  # disposable copy, not the original install
$env:RT3_PRIVATE_OUT = Join-Path $env:LOCALAPPDATA 'RT3Engine-private'
New-Item -ItemType Directory -Force $env:RT3_PRIVATE_OUT | Out-Null
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' .\scripts\Probe-RT3.ahk (Join-Path $env:RT3_PRIVATE_OUT 'probe.txt')
```

## Controlled-save building blocks

The input/capture techniques encapsulated by these helpers were used
successfully on 2026-11-24. The current scripts add window/size guards and have
passed their missing-window negative-path checks; their positive-path rerun
awaits verified save-path isolation. They are building blocks, **not an
untested claim of one-shot start-to-save orchestration**:

- All input helpers bind one HWND whose exact title is `Railroad Tycoon 3`
  and whose process is `RT3.exe`; they refuse other or ambiguous windows.
- `Invoke-RT3Click.ahk` restores/activates that HWND, refuses any client size
  other than 800×600 and rejects coordinates outside the client before moving
  the pointer.
- `Invoke-RT3Key.ahk` and `Invoke-RT3Text.ahk` verify that the same HWND is
  active immediately before sending keyboard input or literal text.
- `Capture-RT3Window.ps1` targets the unique RT3 window with `PrintWindow`; it
  never samples a screen rectangle and throws if window capture fails. DirectX
  output can still be blank, so every image must be checked for the expected
  game content. Captures go to the requested private output path.

PowerShell 5.1 does not automatically stop on a nonzero native exit code.
Check `$LASTEXITCODE` after every helper. This example uses the same short name
for input and destination checks, requires explicit inspection confirmations,
and refuses an existing destination both before input and immediately before
saving:

```powershell
$ErrorActionPreference = 'Stop'
if (-not $env:RT3_SAVE_DIR) { throw 'RT3_SAVE_DIR is unset' }
$saveDir = (Resolve-Path -LiteralPath $env:RT3_SAVE_DIR).Path
$name = 'rt3a' + (Get-Date -Format 'HHmmss')
$savePath = Join-Path $saveDir "$name.gms"
if (Test-Path -LiteralPath $savePath) { throw "Refusing to overwrite $savePath" }
$ahk = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$title = 'Railroad Tycoon 3'
$log = Join-Path $env:RT3_PRIVATE_OUT 'input.log'
& $ahk .\scripts\Invoke-RT3Click.ahk 438 138 $title $log 1
if ($LASTEXITCODE) { throw 'Save click failed' }
& .\scripts\Capture-RT3Window.ps1 -OutputPath (Join-Path $env:RT3_PRIVATE_OUT 'save-dialog.png')
if ((Read-Host 'Inspect save-dialog.png; type YES to continue') -ne 'YES') { throw 'Save dialog not verified' }
& $ahk .\scripts\Invoke-RT3Click.ahk 390 348 $title $log 1
if ($LASTEXITCODE) { throw 'Filename-field click failed' }
& $ahk .\scripts\Invoke-RT3Text.ahk $name $title $log
if ($LASTEXITCODE) { throw 'Filename input failed' }
& .\scripts\Capture-RT3Window.ps1 -OutputPath (Join-Path $env:RT3_PRIVATE_OUT 'save-name.png')
if ((Read-Host 'Inspect save-name.png; type YES to continue') -ne 'YES') { throw 'Save name not verified' }
if (Test-Path -LiteralPath $savePath) { throw "Refusing to overwrite $savePath" }
& $ahk .\scripts\Invoke-RT3Key.ahk '{Enter}' $title $log
if ($LASTEXITCODE) { throw 'Save confirmation failed' }
Start-Sleep -Seconds 3
if (-not (Test-Path -LiteralPath $savePath)) { throw "Save was not created at $savePath" }
Get-Item -LiteralPath $savePath | Select-Object FullName,Length,LastWriteTime
Get-FileHash -Algorithm SHA256 -LiteralPath $savePath
```

The successful scenario route was Single Player `(365,235)`, New Scenario
`(365,293)`, Start British Isles `(370,445)`, then `Return` for the briefing.
The company prompt required a double-click at `(500,442)`, and its default OK
required a double-click at `(330,456)`. Capture and verify after each state
transition rather than replaying the sequence blindly.

From active gameplay, `Escape` opened the system menu. Save's **center** is
`(438,138)`; clicking its left edge did nothing. In the Save dialog, click the
filename field at `(390,348)`, enter a short unique name, and press `Return`.
The game truncated one long requested name to 25 characters, so use a short
name and check for an existing file before saving. A saved file and its hash,
not a screenshot alone, are the proof of success.

### Native save-path isolation requirement

A disposable copy at `RT3_HOME` is not enough. This GOG installation reads
`HKLM\SOFTWARE\WOW6432Node\GOG.com\Games\1445251062`, including `PATH` and
`SAVEGAMEFOLDER`; if they still name the original installation, RT3 writes
saves, screenshots and logs there. Never weaken file or registry permissions
to work around access denial.

`Start-RT3Disposable.ps1` implements the guarded launcher. It requires an
already elevated native Windows PowerShell, refuses UNC/original/nested paths,
requires the disposable `Saved Games` directory, snapshots the original five
GOG values privately, restores them in `finally` once the game window exists,
and verifies every restored value. It stops only the RT3 process it started on
startup/restore failure. It never self-elevates or bypasses UAC. **Its
privileged positive path remains untested until a UAC-approved run.**

```powershell
# Run in native Windows PowerShell opened as Administrator.
$env:RT3_HOME = 'D:\RT3-oracle'
$env:RT3_SAVE_DIR = 'D:\RT3-oracle\Saved Games'
$env:RT3_PRIVATE_OUT = Join-Path $env:LOCALAPPDATA 'RT3Engine-private'
New-Item -ItemType Directory -Force $env:RT3_SAVE_DIR,$env:RT3_PRIVATE_OUT | Out-Null
& .\scripts\Start-RT3Disposable.ps1
```

The game inherits elevation, so run the AutoHotkey helpers from the same
elevated PowerShell. After startup, prove that the Save/Load dialog sees the
disposable directory before any save; otherwise close RT3 and stop.

Keep the actual save directory in a separate `RT3_SAVE_DIR` variable rather
than inferring it from the executable path. Before saving, require all of:

1. no pre-existing destination file;
2. a private capture of the expected state;
3. a private capture of the Save dialog showing the intended short name;
4. after `Return`, a new `.gms` whose size and SHA-256 are recorded under
   `RT3_PRIVATE_OUT`.

The independently generated British Isles control save and its derived counts
are recorded by rt3engine PR #33. Original-game read-back, a second controlled
save and a fully orchestrated verified launcher remain open.
