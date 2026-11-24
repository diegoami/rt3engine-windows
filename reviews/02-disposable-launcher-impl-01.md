# Implementation review: disposable-launcher

- **Revision reviewed:** `6001616d450cec79db8e912e5c5f4464a3d56cf6`
- **Pull request:** [#2](https://github.com/diegoami/rt3engine-windows/pull/2), `verified-disposable-launch` → `main`
- **Base:** `bc53ee81b10f063a68add3a6650a82f25b819ca7`
- **Files:** `README.md`, `scripts/Start-RT3Disposable.ps1`
- **How obtained:** `gh pr view 2 --repo diegoami/rt3engine-windows --json baseRefOid,headRefOid,files,url,title,headRefName,baseRefName` reported this base, head and two-file list. `git diff --name-status <base>...<head>` matched. Read the complete base-to-head diff, current launcher and README context.
- **Reviewer:** GPT-6 Luna (`opencode-go/gpt-6-luna#high`)
- **Mode:** OpenCode implementation review, round 01.

## Blocking findings

1. **Filesystem aliases can bypass the original-installation guard.** `scripts/Start-RT3Disposable.ps1:15-22,44-48` normalizes and compares path strings, but does not resolve or reject directory junctions/symbolic links in the configured paths. For example, `RT3_HOME` can be a junction outside the original tree that targets the original installation; the check passes, while the executable and `Saved Games` directory still resolve into the original. `RT3_PRIVATE_OUT` can similarly alias a directory inside the original, causing the recovery snapshot to be written there. Canonicalize the actual targets or reject reparse-point components before comparing, and verify the rejection with junction-based negative tests.

2. **The no-running-RT3 check races with the registry override and process start.** `scripts/Start-RT3Disposable.ps1:32-34,65-70,89-100` has no single-instance synchronization. Two elevated invocations can both observe no RT3 process before either starts one. One invocation can then restore the original registry values while the other is still starting and has not yet consumed the redirected paths; that second game can consequently use the original installation. Acquire a named mutex before the process check and hold it through restoration/verification, releasing it on every exit path; verify that a concurrent invocation is refused before it can alter the registry or start RT3.

3. **The recovery snapshot is lossy for non-ASCII values.** `scripts/Start-RT3Disposable.ps1:61-62` serializes the originals and writes them with `-Encoding ASCII`. Windows PowerShell 5.1's ASCII encoding replaces non-ASCII characters with `?`; paths containing accented or other non-ASCII characters therefore cannot be recovered exactly from this file if the process is interrupted before `finally` or restoration fails. Write the snapshot using a lossless encoding and verify it round-trips the original values.

## Non-blocking findings

1. **The recovery filename is not exclusively unique.** `scripts/Start-RT3Disposable.ps1:61-62` uses a millisecond timestamp, then `Set-Content`, which overwrites an existing file of the same name. Use an exclusive create (for example, a GUID name with create-new semantics) so a collision cannot destroy an earlier recovery snapshot.

## Verification

- `git diff --check origin/main...6001616d450cec79db8e912e5c5f4464a3d56cf6` passed.
- PowerShell and AutoHotkey are unavailable in this review environment. The implementer's report says Windows PowerShell 5.1 parser validation passed; a non-admin run refused before registry modification/startup; original-installation `RT3_HOME` was refused before elevation/registry modification; and `git diff --check` passed. These Windows checks were not independently rerun.
- No RT3 launch, save operation, registry modification, or original-installation write was performed. No privileged positive-path run was attempted; the README correctly marks it untested.

— GPT-6 Luna (opencode-go/gpt-6-luna#high), reviewer
BLOCK
