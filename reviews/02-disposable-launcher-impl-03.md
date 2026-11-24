# Implementation review: disposable-launcher

- **Revision reviewed:** `55367700e5fc9ee9fd3cec211a7b31efafdb60c4`
- **Pull request:** [#2](https://github.com/diegoami/rt3engine-windows/pull/2), `verified-disposable-launch` → `main`
- **Base:** `bc53ee81b10f063a68add3a6650a82f25b819ca7`
- **Files in PR:** `README.md`, `reviews/02-disposable-launcher-impl-01.md`, `reviews/02-disposable-launcher-impl-02.md`, `scripts/Start-RT3Disposable.ps1`
- **Round-three implementation delta:** `1a99a039c39850ac4725e9ec5f3a8aad3df3325e` → `55367700e5fc9ee9fd3cec211a7b31efafdb60c4` changes `README.md` and `scripts/Start-RT3Disposable.ps1`.
- **How obtained:** `gh pr view 2 --repo diegoami/rt3engine-windows --json number,title,state,baseRefName,baseRefOid,headRefName,headRefOid,url,files,body` reported the PR base, head and files. `git diff --name-status <base>...<head>` matched. Read the full base-to-head diff, round-three implementation delta, current launcher and README.
- **Reviewer:** GPT-6 Luna (`opencode-go/gpt-6-luna#high`)
- **Mode:** OpenCode implementation re-review, round 03.

## Round 02 disposition

- **Drive-alias bypass:** addressed by opening each directory and comparing normalized final paths, rejecting canonical UNC paths and non-fixed drives. The implementer reports Windows tests rejected `SUBST` aliases to the original for both configured paths and rejected a mapped network drive. The reported tests also confirm the junction, concurrency, non-admin and original-path checks still pass.

## Blocking findings

1. **A drive-root original path defeats the nested-path check.** `scripts/Start-RT3Disposable.ps1:87-90,127-133` deliberately preserves a canonical root such as `C:\`. The containment check then tests `StartsWith("$originalRoot\", ...)`; for `C:\`, that expression produces the prefix `C:\\`, while a child path starts with `C:\`. Consequently, if the original GOG `PATH` is a drive root, a `RT3_HOME` or `RT3_PRIVATE_OUT` below that root is not rejected as nested. Use a separator-aware containment helper that handles roots without adding a second separator, and test root plus child paths without changing the real registry.

## Non-blocking findings

No additional non-blocking findings.

## Verification

- `git diff --check bc53ee81b10f063a68add3a6650a82f25b819ca7...55367700e5fc9ee9fd3cec211a7b31efafdb60c4` passed.
- PowerShell and AutoHotkey are unavailable in this review environment. The implementer reports Windows PowerShell 5.1 parser validation and the SUBST, mapped-network-drive, junction, concurrency, non-admin and original-path negative tests. Those Windows tests were not independently rerun.
- No RT3 launch, registry write, original-installation write, or save operation was performed. The privileged positive path remains untested; no broader save orchestration run is required for this static launcher review.

— GPT-6 Luna (opencode-go/gpt-6-luna#high), reviewer
BLOCK
