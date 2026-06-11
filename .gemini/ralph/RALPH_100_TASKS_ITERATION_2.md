# Ralph Loop Iteration 2: 100 Autonomic Evolution Tasks

## Pre-Tasks (1-10): Scaffolding & Context Bootstrapping
1. [x] Audit existing SwarmMail implementation (`send_swarm_alert.py`, `receive_swarm_alert.py`).
2. [x] Verify `pnpm-workspace.yaml` and `package_map.txt` validity.
3. [x] Check `scripts/mhep_injector.sh` and evaluate MHEP readiness.
4. [x] Establish baseline metrics for Ryz compiler/runtime execution.
5. [x] Create Phase 3 staging directory.
6. [x] Verify existence and functionality of `storage_compliance_simulation` stubs.
7. [x] Audit `src/papers` to identify missing implementation of Markovian logics.
8. [x] Initialize `RALPH_ITERATION_2_LEDGER.md`.
9. [x] Verify multi-agent coordination server status.
10. [x] Finalize pre-task baseline.

## Primary Tasks (11-90): Autonomic Evolution & MHEP Transplant

### SwarmMail & Multi-Agent Event Bus (11-25)
11. [x] Review SwarmMail Python scripts for JSON payload support.
12. [x] Refine `send_swarm_alert.py` to support structured JSON.
13. [x] Refine `receive_swarm_alert.py` to support structured JSON.
14. [x] Test basic JSON SwarmMail payload roundtrip.
15. [x] Finalize SwarmMail JSON protocol.
16. [ ] Integrate SwarmMail into `subconscious-daemon.sh`.
17. [ ] Integrate SwarmMail into `hivemind_governor.sh`.
18. [ ] Test Daemon-to-Governor SwarmMail alerting.
19. [ ] Resolve path/logging issues in SwarmMail alerts.
20. [ ] Finalize Event-driven SwarmMail integration.
21. [ ] Setup agent-to-agent negotiation stubs.
22. [ ] Apply Paper 2406.03075 (Multi-agent Debate MC-MAD) principles to SwarmMail.
23. [ ] Draft MC-MAD coordination scripts.
24. [ ] Test MC-MAD conflict resolution.
25. [ ] Finalize MC-MAD coordination layer.

### Storage Compliance & Dependency Consolidation (26-40)
26. [ ] Audit JS/TS extensions for missing `pnpm-workspace.yaml` inclusion.
27. [ ] Enforce `pnpm` monorepo structure across all identified modules.
28. [ ] Validate pnpm root install.
29. [ ] Map redundant `node_modules` guided by `DEPENDENCY_CONSOLIDATION.md`.
30. [ ] Consolidate shared dependencies into root `package.json`.
31. [ ] Remove duplicate nested `node_modules`.
32. [ ] Re-run tests to ensure dependency resolution intact.
33. [ ] Analyze `disk_monitor.sh` functionality.
34. [ ] Enhance `disk_monitor.sh` to validate the 15GB Blueprint limit.
35. [ ] Integrate `disk_monitor.sh` alerts into SwarmMail.
36. [ ] Create `storage_compliance_simulation` dummy test.
37. [ ] Run storage compliance simulation.
38. [ ] Verify disk usage warnings.
39. [ ] Refine cleanup automation for compliance.
40. [ ] Finalize Storage Compliance & Dependency Consolidation.

### MHEP (Markovian Heuristic Execution Pipeline) Transplant (41-60)
41. [ ] Analyze `mhep_injector.sh`.
42. [ ] Refactor `mhep_injector.sh` for stability.
43. [ ] Activate `mhep_injector.sh` into the main runtime.
44. [ ] Validate MHEP injection logs.
45. [ ] Finalize MHEP activation.
46. [ ] Connect Paper 2410.02724 (LLM == Markov Chain) logic.
47. [ ] Implement transition matrix evaluation in MHEP.
48. [ ] Test Markovian equivalence logic.
49. [ ] Refine transition evaluations.
50. [ ] Finalize Paper 2410.02724 integration.
51. [ ] Connect Paper 2502.12018 (Atom of Thoughts).
52. [ ] Integrate AOT into `TCOT_METHODOLOGY.md` automated enforcement.
53. [ ] Develop AOT tracking scripts.
54. [ ] Test AOT state decomposition.
55. [ ] Finalize AOT integration.
56. [ ] Review MHEP logging paths.
57. [ ] Standardize MHEP logs into `DEVMIND_LOG_DIR`.
58. [ ] Ensure MHEP state routes to `DEVMIND_STATE_DIR`.
59. [ ] Validate MHEP logging portability.
60. [ ] Finalize MHEP Transplant.

### Ryz Language Maturation (61-75)
61. [ ] Audit `ryz/` integration points.
62. [ ] Audit `ryz-linux/` integration points.
63. [ ] Consolidate Ryz testing scripts.
64. [ ] Verify cross-compatibility of Ryz scripts.
65. [ ] Finalize Ryz integration audit.
66. [ ] Connect Paper 2506.07298 (Bayesian Forward Filtering) to Ryz.
67. [ ] Implement Bayesian parsing heuristics in Ryz.
68. [ ] Write unit tests for Ryz Bayesian filtering.
69. [ ] Run Ryz Bayesian tests.
70. [ ] Finalize Paper 2506.07298 Ryz implementation.
71. [ ] Review native parity requirements.
72. [ ] Establish native parity benchmarks (`ryz/test/native_parity.sh`).
73. [ ] Run native parity benchmarking suite.
74. [ ] Document native parity results.
75. [ ] Finalize Ryz maturation layer.

### Systemic Reliability & TraceToChain (76-90)
76. [ ] Review `test_runner.py` functionality.
77. [ ] Implement Paper 2604.24579 (Analytic Reliability) within `test_runner.py`.
78. [ ] Enable reliability metrics output for tests.
79. [ ] Test TraceToChain reliability mapping.
80. [ ] Finalize Paper 2604.24579 integration.
81. [ ] Setup error rate threshold variables.
82. [ ] Integrate threshold monitoring into Subconscious Daemon.
83. [ ] Configure automatic execution halts upon threshold breach.
84. [ ] Test automatic halt mechanisms.
85. [ ] Finalize threshold monitoring.
86. [ ] Inventory existing testing frameworks (pytest, vitest, bun test, etc.).
87. [ ] Create a unified testing wrapper script.
88. [ ] Integrate wrapper into an automated CI-like local pipeline.
89. [ ] Validate local pipeline execution.
90. [ ] Finalize Systemic Reliability & TraceToChain.

## Post-Tasks (91-100): Validation & Phase 4 Preparation
91. [ ] Conduct end-to-end integration tests of MHEP.
92. [ ] Conduct end-to-end tests of SwarmMail.
93. [ ] Validate pnpm monorepo structure integrity.
94. [ ] Verify 15GB storage compliance boundaries.
95. [ ] Review all generated logs for pathing errors.
96. [ ] Draft MHEP Transplant capability document.
97. [ ] Draft SwarmMail protocol usage guide.
98. [ ] Prepare Iteration 2 summary.
99. [ ] Generate the Iteration 2 Sign-off Ledger (`RALPH_ITERATION_2_LEDGER.md`).
100. [ ] Conclude Ralph Iteration 2 and formulate prep for Iteration 3.