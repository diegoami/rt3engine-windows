# Implementation review: disposable-launcher

- **Revision reviewed:** `1a99a039c39850ac4725e9ec5f3a8aad3df3325e`
- **Pull request:** [#2](https://github.com/diegoami/rt3engine-windows/pull/2), `verified-disposable-launch` → `main`
- **Base:** `bc53ee81b10f063a68add3a6650a82f25b819ca7`
- **Files in PR:** `README.md`, `reviews/02-disposable-launcher-impl-01.md`, `scripts/Start-RT3Disposable.ps1`
- **Round-two implementation delta:** `6001616d450cec79db8e912e5c5f4464a3d56cf6` → `1a99a039c39850ac4725e9ec5f3a8aad3df3325e` changes `README.md` and `scripts/Start-RT3Disposable.ps1`.
- **How obtained:** `gh pr view 2 --repo diegoami/rt3engine-windows --json number,title,state,baseRefName,baseRefOid,headRefName,headRefOid,url,files,body` reported the PR base, head and files. `git diff --name-status <base>...<head>` matched. Read the full base-to-head diff, round-two implementation delta, current launcher and README.
- **Reviewer:** GPT-6 Luna (`opencode-go/gpt-6-luna#high`)
- **Mode:** OpenCode implementation re-review, round 02.

## Round 01 disposition

- **Junction/symbolic-link path bypass:** directory components and `RT3.exe` are now checked for `ReparsePoint`. The implementer reports real Windows negative tests refused both `RT3_HOME` and `RT3_PRIVATE_OUT` junctions to the original, with the junctions removed without recursion. A different drive-alias bypass remains below.
- **Concurrent launcher race:** resolved by acquiring the global named mutex before the process check and registry read, and holding it through restore and verification. The implementer reports a separate Start-Job test where the second invocation was refused and all five registry values remained unchanged.
- **Lossy/colliding recovery snapshot:** resolved by a GUID filename, `FileMode.CreateNew`, UTF-8 bytes and read-back comparison before registry writes. The implementer reports exact German/Japanese synthetic-value round trips.

## Blocking findings

1. **Drive aliases can still bypass both the original-installation and local-drive guards.** `scripts/Start-RT3Disposable.ps1:15-29,68-76` checks the URI/path spelling and filesystem `ReparsePoint` attributes, but does not canonicalize the underlying drive target. A `SUBST` drive can name a directory in the original installation without any filesystem component being a reparse point; `RT3_HOME` and its `Saved Games` path then appear lexically outside the original and pass these checks, while the game still writes into the original. `RT3_PRIVATE_OUT` can use the same alias and write the recovery snapshot there. Likewise, a mapped drive to a UNC share is not itself parsed as a UNC path and may have no reparse-point component, bypassing the local-drive requirement. This also makes the unqualified refusal claim in `README.md:126-132` too broad. Canonicalize paths from opened filesystem handles (or otherwise reject these drive aliases) before comparing them, and add negative tests for a `SUBST` alias to the original and a mapped network drive.

## Non-blocking findings

No additional non-blocking findings.

## Verification

- `git diff --check bc53ee81b10f063a68add3a6650a82f25b819ca7...1a99a039c39850ac4725e9ec5f3a8aad3df3325e` passed.
- PowerShell and AutoHotkey are unavailable in this review environment. The implementer reports Windows PowerShell 5.1 parser validation; non-admin and original-path refusals; junction rejection for both configured paths; refusal of a concurrent launcher with all five registry values unchanged; and exact non-ASCII snapshot round trips. Those Windows tests were not independently rerun.
- No RT3 launch, registry write, original-installation write, or save operation was performed. The privileged positive path remains untested; no broader save orchestration run is required for this static launcher review.

— GPT-6 Luna (opencode-go/gpt-6-luna#high), reviewer
BLOCK
