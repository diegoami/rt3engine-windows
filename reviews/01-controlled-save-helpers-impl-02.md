# Implementation review: controlled-save-helpers

- **Revision reviewed:** `fe98231ab177c329c5c71d389a9717c6f0dc8603`
- **Pull request:** [#1](https://github.com/diegoami/rt3engine-windows/pull/1), `controlled-save-helpers` → `main`
- **Base:** `e17b53a3500b1ca7418a2f679e05934f36a1b96b`
- **Files:** `.gitignore`, `README.md`, `reviews/01-controlled-save-helpers-impl-01.md`, `scripts/Capture-RT3Window.ps1`, `scripts/Invoke-RT3Click.ahk`, `scripts/Invoke-RT3Key.ahk`, `scripts/Invoke-RT3Text.ahk`
- **How obtained:** `gh pr view 1 --repo diegoami/rt3engine-windows --json baseRefOid,headRefOid,files` reported this head, base and seven-file list. `git diff --name-status <base>...<head>` matched; the new implementation diff is `3f3127244544033fc8d0ff54593da39c78fc3658...fe98231ab177c329c5c71d389a9717c6f0dc8603` and changes `README.md` and the four scripts. Read that complete diff and the complete current changed files.
- **Reviewer:** GPT-6 Luna (`opencode-go/gpt-6-luna#high`)
- **Mode:** OpenCode implementation re-review, round 02.

## Round 01 disposition

- The click helper now checks exact 800×600 client size and rejects coordinates outside `0..799` / `0..599` before pointer movement.
- The input helpers now resolve one HWND, validate the exact RT3 title and `RT3.exe` process, and retain `ahk_id` through activation and input. Key and text helpers check the active HWND immediately before sending. The click helper's focus check is still too early; see finding 1.
- Capture now uses `PrintWindow` with flag `2` (`PW_RENDERFULLCONTENT`), requires exactly one RT3 process with a main window, and has no screen-capture fallback. The README correctly warns that DirectX output can still be blank and must be checked. The repeated `Add-Type` definition prevents the documented two-capture sequence in Windows PowerShell 5.1; see finding 2.
- The README now checks each AHK exit code and places captures in the described sequence. Those comments do not pause execution or enforce inspection/no-overwrite before the final Enter; see finding 3.

## Findings

1. **Blocking — click focus can change before the actual mouse input.** `scripts/Invoke-RT3Click.ahk:39-50` checks `WinActive(target)` before `MouseMove` and a 250 ms `Sleep`, then calls `MouseClick` without rechecking. If focus changes during that interval, the global click can land in another window. Recheck that the same HWND is active immediately before each mouse-down/click (and before release in the hold path), or otherwise target the input safely.

2. **Blocking — the second documented capture fails in the same PowerShell 5.1 session.** `scripts/Capture-RT3Window.ps1:10-21` adds the global `RT3Window` type every time the script runs. Windows PowerShell 5.1 requires type names to be unique in a session; the README invokes this script twice in one session (`README.md:81,87`). With `$ErrorActionPreference = 'Stop'`, the repeated `Add-Type` fails before the second capture. Reuse an already-loaded type or avoid redefining it, and verify repeated invocation in one PowerShell 5.1 session.

3. **Blocking — the sample does not enforce its screenshot or no-overwrite gates.** `README.md:81-90,117-124` puts inspection and destination verification in comments, then immediately proceeds to the next input and finally `{Enter}`. If the code block is run as written, it does not pause for the operator to inspect either image, and it never resolves `RT3_SAVE_DIR` or tests the intended `.gms` destination before saving. Split the steps so each inspection/check must happen before continuing, or add explicit gates including an absent-destination check tied to the same filename sent to the game.

## Verification

- Confirmed the live PR head/base and the seven files above; the new diff modifies only `README.md` and the four helper scripts.
- `git diff --check` passed for both the new commit diff and the full PR diff.
- `git check-ignore -v --no-index test.gms test.gmc test.sav test.png test.tga test.xwd test.log` confirmed the relevant ignore rules.
- The implementer reports that all three missing-window checks exited 2 and logged, a Chrome title was rejected, and the PowerShell 5.1 parser passed. I could not independently rerun those platform-specific checks because PowerShell and AutoHotkey are unavailable in this Linux environment. The repeated-type issue is a PowerShell 5.1 session/runtime issue, not a parser issue.
- No RT3 launch, save operation, registry change, or original-install write was performed. No positive-path run was attempted; verified save-path isolation remains a prerequisite.

— GPT-6 Luna (opencode-go/gpt-6-luna#high), reviewer
BLOCK
