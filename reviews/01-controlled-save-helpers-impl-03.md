# Implementation review: controlled-save-helpers

- **Revision reviewed:** `ac2c8f152a521cdf42c26ad3f65ae9bcf59f85ae`
- **Pull request:** [#1](https://github.com/diegoami/rt3engine-windows/pull/1), `controlled-save-helpers` → `main`
- **Base:** `e17b53a3500b1ca7418a2f679e05934f36a1b96b`
- **Files:** `.gitignore`, `README.md`, `reviews/01-controlled-save-helpers-impl-01.md`, `reviews/01-controlled-save-helpers-impl-02.md`, `scripts/Capture-RT3Window.ps1`, `scripts/Invoke-RT3Click.ahk`, `scripts/Invoke-RT3Key.ahk`, `scripts/Invoke-RT3Text.ahk`
- **How obtained:** `gh pr view 1 --repo diegoami/rt3engine-windows --json baseRefOid,headRefOid,files` reported this head, base and eight-file list. `git diff --name-status <base>...<head>` matched. The round-3 implementation diff is `10d84d784859948fc0372e881e62af37623af385...ac2c8f152a521cdf42c26ad3f65ae9bcf59f85ae`; it changes `README.md`, `scripts/Capture-RT3Window.ps1`, and `scripts/Invoke-RT3Click.ahk`. Read the complete diff and current files.
- **Reviewer:** GPT-6 Luna (`opencode-go/gpt-6-luna#high`)
- **Mode:** OpenCode implementation re-review, round 03.

## Round 02 disposition

- **Click focus:** resolved. The hold/release path is gone; after `MouseMove` and the 250 ms delay, the helper checks that the same HWND is active immediately before `MouseClick`.
- **Repeated capture:** resolved. `Capture-RT3Window.ps1` defines `RT3Window` only when the type is not already loaded. The implementer reports that two invocations in one Windows PowerShell 5.1 session, with RT3 stopped, both reached the expected no-RT3 guard without a type-redefinition failure.
- **Save/checkpoint gates:** resolved. The README resolves `RT3_SAVE_DIR`, uses one `$name` for text and `$savePath`, checks for an existing destination before input and again immediately before Enter, requires explicit `YES` after both captures, checks each AHK exit code, and verifies the created file and its size/hash afterward.

## Findings

No blocking or non-blocking findings.

## Verification

- `git diff --check` passed for both the round-3 diff and the full PR diff.
- `git check-ignore -v --no-index test.gms test.gmc test.sav test.png test.tga test.xwd test.log` confirmed the relevant ignore rules.
- The implementer reports that the PowerShell 5.1 parser and repeated-capture check passed, as did the missing-window click negative test. PowerShell and AutoHotkey are unavailable in this review environment, so those platform-specific tests were not independently rerun.
- No RT3 launch, save operation, registry change, or original-install write was performed. No positive-path run was attempted; verified save-path isolation remains a prerequisite.

— GPT-6 Luna (opencode-go/gpt-6-luna#high), reviewer
AGREE
