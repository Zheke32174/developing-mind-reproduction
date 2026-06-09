# Ralph Loop: Baseline Path Audit Report

This report identifies scripts containing hardcoded absolute paths that need to be replaced with environment variables defined in `scripts/devmind-env.sh`.

## Identified Hardcoded Paths

| Script | Hardcoded Path | Recommended Environment Variable |
| :--- | :--- | :--- |
| `scripts/secretary_worker.py` | `/home/fixxia/lamp/logs` | `DEVMIND_LOG_DIR` |
| `scripts/ralph_dashboard.py` | `/mnt/c/Users/Fixxia/...` | `DEVMIND_REPRO_DIR` |
| `scripts/checkpoint-timer.py` | `/mnt/c/Users/Fixxia/.../scripts` | `DEVMIND_STATE_DIR` |
| `scripts/angel_performance.sh` | `/mnt/c/Users/Fixxia/...` | `DEVMIND_REPRO_DIR` |
| `scripts/nerve_fixer.py` | `/mnt/c/Users/Fixxia/...` | `DEVMIND_REPRO_DIR` |
| `scripts/receive_swarm_alert.py` | `/mnt/c/Users/Fixxia` | `DEVMIND_WIN_HOME` |
| `scripts/angel_evolutionary.sh` | `/mnt/c/Users/Fixxia/...` | `DEVMIND_REPRO_DIR` |
| `scripts/ralph_watchdog.py` | `/mnt/c/Users/Fixxia/...` | `DEVMIND_REPRO_DIR` |
| `scripts/system_doctor.sh` | `/mnt/c/Users/Fixxia/...` | `DEVMIND_REPRO_DIR` |
| `scripts/system_doctor.sh` | `/home/fixxia/.bun/bin/bun` | `BUN` (from PATH or env) |
| `scripts/mhep_injector.sh` | `/mnt/c/Users/Fixxia/...` | `DEVMIND_REPRO_DIR` |
| `scripts/ralph_progressor.sh` | `/mnt/c/Users/Fixxia/...` | `DEVMIND_REPRO_DIR` |
| `scripts/angel_architectural.sh` | `/mnt/c/Users/Fixxia/...` | `DEVMIND_REPRO_DIR` |
| `scripts/skill_logger.py` | `/mnt/c/Users/Fixxia/...` | `DEVMIND_REPRO_DIR` |
| `scripts/substrate-sync.sh` | `/mnt/c/Users/Fixxia/scripts/gga_repo/bin/gga` | `DEVMIND_GGA_PATH` |
| `scripts/send_swarm_alert.py` | `/mnt/c/Users/Fixxia` | `DEVMIND_WIN_HOME` |
| `scripts/ecosystem_automation.sh` | `/home/fixxia/.bun/bin/bun` | `BUN` |

## Systemic Hardcoded Prefixes
- `/home/fixxia`
- `/mnt/c/Users/Fixxia`
- `/substrate/mind` (found in `package_map.txt` and `pnpm-workspace.yaml`)

## Next Steps
- Inject `source scripts/devmind-env.sh` into all shell scripts.
- Update Python scripts to read `os.environ`.
- Standardize logging and state directory usage.
