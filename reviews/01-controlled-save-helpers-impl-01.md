# Implementation review: controlled-save-helpers

- **Revision reviewed:** `c550804786da3a40fed7c797de6b3f63ddd1d471`
- **Pull request:** [#1](https://github.com/diegoami/rt3engine-windows/pull/1), `controlled-save-helpers` → `main`
- **Base:** `e17b53a3500b1ca7418a2f679e05934f36a1b96b`
- **Files:** `.gitignore`, `README.md`, `scripts/Capture-RT3Window.ps1`, `scripts/Invoke-RT3Click.ahk`, `scripts/Invoke-RT3Key.ahk`, `scripts/Invoke-RT3Text.ahk`
- **How obtained:** `gh pr view 1 --repo diegoami/rt3engine-windows --json baseRefOid,headRefOid,files` reported that head, base and six-file list; `git diff --name-status <base>...<head>` matched. Read the complete diff and each changed file.
- **Reviewer:** GPT-6 Luna (`opencode-go/gpt-6-luna#high`)
- **Mode:** OpenCode implementation review, round 01, in a fresh reviewer context.

## Findings

1. **Blocking — click coordinates can escape the RT3 client.** `scripts/Invoke-RT3Click.ahk:8-13,24-36` accepts any integers for `x` and `y`; the 800×600 check validates only the window dimensions. With `CoordMode "Mouse", "Client"`, out-of-range coordinates can map outside the game client and click another screen location. Reject coordinates unless `0 <= x < width` and `0 <= y < height` before moving or clicking.

2. **Blocking — input helpers do not establish that the matched window is RT3.** `scripts/Invoke-RT3Click.ahk:2,10-20`, `scripts/Invoke-RT3Key.ahk:2,8-20`, and `scripts/Invoke-RT3Text.ahk:2,8-20` use substring title matching on a caller-supplied string. They never check the matched window's process identity or bind subsequent activation/input to a verified RT3 window handle. A different or ambiguous matching window can therefore receive the click or global `Send`/`SendText`. Verify the RT3 process and use one validated window handle throughout each action.

3. **Blocking — the capture is a screen crop, not an RT3-only window capture.** `scripts/Capture-RT3Window.ps1:23-37` ignores the result of `SetForegroundWindow` and uses `Graphics.CopyFromScreen` over the window rectangle. That samples whatever is visible on the desktop in those coordinates; an overlapping window or a failed foreground request can produce unrelated pixels. This does not support the README/PR claim that capture contains only RT3 and no unrelated desktop content, and can make a state screenshot misleading. Use a verified window-surface capture that works for RT3, or narrow the claim and explicitly detect/fail when the requested RT3 content is not what is captured.

4. **Non-blocking — the example continues after helper failures and skips its stated checkpoints.** `README.md:69-79` invokes click, key and text consecutively without checking each AutoHotkey process exit code; it captures only after all three, despite instructing users to capture and verify after each transition. A failed click guard therefore does not stop later input. Show fail-fast exit-code handling and separate the actions with the stated state checks, or label the snippet as isolated commands that must not be replayed as a sequence.

## Verification

- `git diff --check <base>...<head>` passed.
- `git check-ignore -v --no-index test.gms test.gmc test.sav test.png test.tga test.xwd test.log` confirmed all seven extension patterns are ignored.
- The diff contains no save bytes, assets or captures. No save operation, registry change, or RT3 launch was performed; the README retains the no-pre-existing-destination requirement and requires a newly created `.gms` plus size/hash evidence before claiming a save.
- PowerShell parsing and AutoHotkey negative-path execution could not be independently reproduced here: `pwsh`, `powershell`, and AutoHotkey are unavailable in this Linux environment. The PR body reports those checks passed, but I did not count them as independently verified. No positive-path rerun was attempted; verified save-path isolation remains a prerequisite.

— GPT-6 Luna (opencode-go/gpt-6-luna#high), reviewer
BLOCK
