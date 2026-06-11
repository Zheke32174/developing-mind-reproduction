# Ralph Loop: 100 Debug Week Tasks

## Pre-Tasks (1-10): Auditing and Baseline
1. [√] Identify all scripts with hardcoded paths.
2. [√] Verify `scripts/devmind-env.sh` functionality.
3. [√] Establish `DEVMIND_LOG_DIR` and `DEVMIND_STATE_DIR` existence checks.
4. [√] Establish archive directory for `.bak` files.
5. [√] Create ignore patterns for static audit tools to ignore backups.
6. [√] Verify access to `scripts/hyperbolic_judge.sh`.
7. [√] Verify access to `scripts/system_subgovernor.sh`.
8. [√] Verify access to `scripts/subconscious-daemon.sh`.
9. [√] Verify access to `scripts/secretary_worker.py`.
10. [√] Finalize baseline audit report.

## Primary Tasks (11-90): Stabilization and Refactoring

### Hyperbolic Judge Fixes (11-20)
11. [√] Inject `devmind-env.sh` source into `hyperbolic_judge.sh`.
12. [√] Replace `REPRO_DIR` with `DEVMIND_REPRO_DIR`.
13. [√] Replace `LAMP_DIR` with `DEVMIND_LOG_DIR` context or proper env.
14. [√] Ensure state files are routed to `DEVMIND_STATE_DIR`.
15. [√] Remove direct bash calls to absolute paths.
16. [√] Validate `hyperbolic_judge.sh` dry-run.
17. [√] Review error handling in hyperbolic execution.
18. [√] Standardize output messages.
19. [√] Test with simulated failure.
20. [√] Finalize `hyperbolic_judge.sh` fix.

### System Sub-Governor Fixes (21-30)
21. [√] Inject `devmind-env.sh` source into `system_subgovernor.sh`.
22. [√] Replace `STAGING_DIR` with `DEVMIND_LOG_DIR/secretary_staging`.
23. [√] Replace `REPRO_DIR` with `DEVMIND_REPRO_DIR`.
24. [√] Replace hardcoded `/substrate/mind/` with correct env variable.
25. [√] Remove direct reference to `/home/fixxia/lamp/logs`.
26. [√] Standardize ledger path to use env variables.
27. [√] Ensure SAST/DAST mock uses relative paths.
28. [√] Run syntax check on `system_subgovernor.sh`.
29. [√] Review logging output.
30. [√] Finalize `system_subgovernor.sh` fix.

### Subconscious Daemon Fixes (31-40)
31. [√] Inject `devmind-env.sh` source into `subconscious-daemon.sh`.
32. [√] Replace `SCRIPTS_DIR` with `DEVMIND_SCRIPT_DIR`.
33. [√] Replace `LAMP_DIR` with appropriate env mapping.
34. [√] Route output messages through centralized logging.
35. [√] Ensure sub-scripts are invoked safely.
36. [√] Review `checkpoint-timer.py` invocation paths.
37. [√] Review `ralph_watchdog.py` invocation paths.
38. [√] Validate background execution safety.
39. [√] Check variable scope.
40. [√] Finalize `subconscious-daemon.sh` fix.

### Secretary Worker Fixes (41-50)
41. [√] Review `scripts/secretary_worker.py` for path issues.
42. [√] Inject os.environ reading for `DEVMIND_` variables.
43. [√] Replace hardcoded staging directory.
44. [√] Route `.bak` management through safe paths.
45. [√] Implement try/except around path operations.
46. [√] Fix logging paths in python script.
47. [√] Validate functionality with dry-run.
48. [√] Test staging generation.
49. [√] Test cleanup logic.
50. [√] Finalize `secretary_worker.py` fix.

### Harness Scripts Fixes (51-70)
51. [√] Scan `harness_claude.sh` for hardcoded paths.
52. [√] Fix `harness_claude.sh`.
53. [√] Scan `harness_gemini.sh` for hardcoded paths.
54. [√] Fix `harness_gemini.sh`.
55. [√] Scan `harness_hermes.sh` for hardcoded paths.
56. [√] Fix `harness_hermes.sh`.
57. [√] Unify harness logging to `DEVMIND_LOG_DIR`.
58. [√] Unify harness state to `DEVMIND_STATE_DIR`.
59. [√] Ensure harness scripts use `is_cli_skipped`.
60. [√] Ensure harness scripts handle timeouts gracefully.
61. [√] Extended checks for remaining shell scripts in `scripts/`.
62. [√] Remediation of `system_doctor.sh` (termux-remote).
63. [√] Remediation of `ecosystem_automation.sh` (termux-remote).
64. [√] Fix `substrate-sync.sh` paths.
65. [√] Fix `mhep_injector.sh` paths.
66. [√] Fix `ralph_progressor.sh` paths.
67. [√] Review `skill_logger.py` paths.
68. [√] Review `nerve_fixer.py` paths.
69. [√] Review `checkpoint-timer.py` paths.
70. [√] Finalize harness and utility script cleanup.

### Backup File Management (71-80)
71. [√] Search repository for `.bak` files.
72. [√] Create `backup_archive` logic.
73. [√] Move existing `.bak` files.
74. [√] Update `.gitignore` for backup extensions.
75. [√] Ensure scripts writing `.bak` write them to `DEVMIND_STATE_DIR/backups`.
76. [√] Ensure static audit scripts skip the backups directory.
77. [√] Validate `test_ecosystem.py` ignores `.bak`.
78. [√] Clean up workspace of residual files.
79. [√] Validate backup clean state.
80. [√] Finalize backup management.

### Ecosystem Integration & Legibility (81-90)
81. [√] Update `TCOT_METHODOLOGY.md` to reference `devmind-env.sh`.
82. [√] Ensure `tests/test_ecosystem.py` runs cleanly.
83. [√] Review `ECOSYSTEM_MAP.md` for accurate pathing.
84. [√] Verify Guardian Angel Commit-Gate constraints.
85. [√] Ensure no script makes assumptions about host user.
86. [√] Run local static audit.
87. [√] Fix any leftover hardcoded `/home/fixxia` occurrences.
88. [√] Fix any leftover hardcoded `/mnt/c/Users/` occurrences.
89. [√] Fix any leftover hardcoded `/substrate/mind` occurrences.
90. [√] Run end-to-end integration checklist.

## Post-Tasks (91-100): Validation and Handoff
91. [√] Perform final pass on `hyperbolic_judge.sh`.
92. [√] Perform final pass on `system_subgovernor.sh`.
93. [√] Perform final pass on `subconscious-daemon.sh`.
94. [√] Execute `scripts/daily_governance.py` (Dry-run).
95. [√] Verify Codex Judge readiness.
96. [√] Validate Council Nerve Center paths.
97. [√] Draft the receipt.
98. [√] Prepare session report for `DEBUG_WEEK_HANDOFF.md`.
99. [√] Commit the bounded fixes with Guardian approval.
100. [√] Conclude Ralph Iteration loop.
