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
- Original assets and save bytes never enter Git. `.gmc`/`.sav`, captures and
  generated outputs are ignored.
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

The next milestone is a deterministic, non-destructive controlled-save script
with proof of the produced file and state. That remains unimplemented until it
has been run on a suitable Windows session.
