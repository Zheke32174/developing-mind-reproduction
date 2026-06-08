# gh / git — three-level integration (Linux-first)

GitHub CLI works on all three levels, with **Linux as the source of truth**. No native Windows
install (declined by operator) — Windows defers to WSL's authenticated gh. On-ethos: the Linux
toolchain is canonical; other surfaces borrow it.

| Level | How | Status |
| :--- | :--- | :--- |
| **WSL (Linux)** | native `gh` 2.46 + `git` 2.53, authed as `Zheke32174` (repo/workflow/gist/read:org) | ✅ source of truth |
| **Windows** | `C:\Users\Fixxia\bin\{gh,git}.cmd` proxy → `wsl -d Ubuntu -- gh/git`; dir on user PATH | ✅ verified (`gh auth status` OK) |
| **Termux** | `ssh termux-lab gh …` (reuses the phone's gh, or proxies to WSL via `wsl-bridge`) | ⏳ pattern ready; phone offline now |

## Install (Windows side, already applied)
- Shims at `C:\Users\Fixxia\bin\gh.cmd` / `git.cmd` (single-line `@wsl -d Ubuntu -- gh %*`).
- `C:\Users\Fixxia\bin` added to **user** PATH (no admin). New shells get `gh` / `git` directly.
- Versioned copies live here in `integration/windows/`.

## Verify
```powershell
gh --version          # -> gh 2.46.0 (Ubuntu)   [proxied to WSL]
gh auth status        # -> Logged in ... Zheke32174
git --version         # -> git 2.53.0
```

## Notes / limitations
- The proxy runs gh in WSL's context; for repos under `C:\` use the `/mnt/c/...` path inside WSL,
  or run from WSL directly. Good enough for auth, PRs, issues, releases, API calls.
- When the phone returns, `ssh termux-lab 'gh ...'` (or `ssh termux-lab ssh wsl-bridge gh ...`)
  completes the third level; `scripts/system_doctor.sh` reports tunnel reachability.
