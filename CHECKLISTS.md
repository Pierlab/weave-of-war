# Vertical Slice P0 Execution Checklist (2025 Refresh)

This checklist replaces the earlier milestone summary and expands every deliverable required to land the Vertical Slice P0 described in `docs/project_spec.md`, the mission brief `docs/agents/missions/vertical_slice_p0.md`, and the SDS/TDD artefacts.

> **How to use this document**
> 1. Progress strictly from the first numbered task to the last—do not skip ahead unless a dependency explicitly says so.
> 2. After completing a task, update the linked artefacts (mission brief, docs, tests) before checking it off.
> 3. Capture validation evidence (logs, screenshots, recordings) in `docs/agents/missions/vertical_slice_p0.md` as you go.

> **Legend**
> `[ ]` = pending · `[~]` = in progress (replace the space with `~`) · `[x]` = complete with validation evidence linked in mission notes.

## Phase 0 — Alignment, Data Hygiene, and Instrumentation Foundations
1. [x] **Re-align scope and mission context.** Re-read `docs/project_spec.md`, `docs/agents/missions/vertical_slice_p0.md`, and the latest `context_snapshot.md`. Log any scope delta or open risk in `context_update.md` under a new dated bullet. *(2025-11-01 — Scope aligned; no new risks beyond existing Godot binary provisioning blocker.)*
2. [x] **Catalogue data gaps.** Audit every `data/*.json` file against SDS expectations (doctrines, orders, units, weather, logistics, formations, competence sliders). Record missing fields/inconsistencies in the mission brief under a "Phase 0 findings" heading. *(2025-11-02 — Documented gaps per dataset in mission brief Phase 0 findings.)*
3. [x] **Harden DataLoader validation.** Update `DataLoader` schemas and gdUnit tests so that all JSON documents used in P0 validate required enums/keys before consumption. *(2025-11-03 — `DataLoaderAutoload.validate_collection()` enforces schema + enum checks, and new gdUnit coverage (`test_data_loader_validation_reports_missing_keys`, `test_data_loader_validation_accepts_valid_payload`) verifies failures/success.)*
4. [x] **Verify autoload readiness.** Confirm `EventBusAutoload`, `DataLoaderAutoload`, `TelemetryAutoload`, and `AssistantAIAutoload` are registered in `project.godot`, emit baseline signals during startup, and surface no warnings. Capture an editor/headless log excerpt proving success. *(2025-11-04 — Autoload names normalised in `project.godot`, gdUnit coverage checks configuration + readiness signals, and startup instrumentation captured in `docs/logs/autoload_readiness_2025-11-04.log`.)*
5. [ ] **Stabilise HUD audio feedback.** Rework `_play_feedback()` and related helpers to start streams, guard playback, and stop/clear safely. Attach a short validation log or clip demonstrating clean console output after repeated doctrine/order swaps.

## Phase 1 — Command Model & Élan Core Loop
6. [ ] **Lock doctrine catalogue.** Ensure doctrine names (Force/Ruse/Patience/Vitesse/Équilibre) and metadata in `data/doctrines.json` match SDS rules. Update localisation strings or HUD labels as needed.
7. [ ] **Enrich orders dataset.** Expand `data/orders.json` with Élan costs, doctrine requirements, and AI intent metadata aligned with the SDS. Document any new fields in the mission brief.
8. [ ] **Document HUD UX copy.** Capture doctrine/order text, audio cues, and accessibility notes in the HUD section of `README.md`.
9. [ ] **Wire core systems.** Instantiate `DoctrineSystem` and `ElanSystem` within `GameManager` using typed references. Ensure both wait for `data_loader_ready` before setup logic runs (add assertions/logs as proof).
10. [ ] **Enforce command rules.** Implement doctrine inertia and Élan caps per SDS, exposing current inertia/Élan totals on the HUD (labels/tooltips). Include screenshots in mission notes.
11. [ ] **Connect HUD interactions.** Link HUD selectors to `EventBusAutoload` so doctrine swaps/orders raise signals, and present validation errors in-line when rules fail.
12. [ ] **Propagate orders to Assistant AI.** Confirm `AssistantAIAutoload` receives issued orders and logs interpretations accessible from the debug overlay.
13. [ ] **Automate verification.** Add gdUnit tests covering doctrine change success/failure, Élan gain/spend limits, and assistant acknowledgements. Store command output hashes/paths in mission notes.
14. [ ] **Instrument telemetry.** Emit structured payloads for `doctrine_selected`, `order_issued`, `order_rejected`, `elan_spent`, and `elan_gained`. Update telemetry schemas/docs accordingly.
15. [ ] **Update manual checks.** Extend `docs/tests/acceptance_tests.md` with steps for doctrine selection, order issuance, and telemetry review.

## Phase 2 — Logistics Backbone with Terrain & Weather Layering
16. [ ] **Bootstrap LogisticsSystem.** Instantiate the logistics controller within `GameManager`, wiring turn update hooks and HUD toggles via `EventBusAutoload`.
17. [ ] **Load logistics data.** Parse rings, nodes, and convoy routes from `data/logistics.json`; create gdUnit assertions that every scenario graph is connected.
18. [ ] **Animate supply flows.** Render ring pulses and moving convoy sprites with state-dependent colouring (supply OK/at risk/broken). Capture GIF or screenshot evidence.
19. [ ] **Publish logistics updates.** Emit `logistics_update` signals containing reachable tiles, supply deficits, and convoy statuses each turn. Document payload examples in mission notes.
20. [ ] **Attach terrain metadata.** Extend map tiles to include Plains/Forest/Hill descriptors sourced from data, and surface tooltips in HUD/debug overlay.
21. [ ] **Implement weather controller.** Cycle through Sunny/Rain/Mist (plus optional Snow/Storm hooks) using deterministic seeds for tests; expose state on HUD icons.
22. [ ] **Link weather to logistics.** Apply weather modifiers to logistics throughput/convoy vulnerability as per SDS and log the adjustments for QA.
23. [ ] **Emit weather telemetry.** Send `weather_changed` events with applied modifiers and record schemas.
24. [ ] **Extend automated tests.** Add gdUnit coverage for logistics reachability, convoy interception hooks, and weather rotation cadence; commit outputs.
25. [ ] **Refresh manual tests.** Update `docs/tests/acceptance_tests.md` with logistics overlay toggles, terrain tooltip checks, and weather-driven changes.

## Phase 3 — Combat (3 Pillars)
26. [ ] **Instantiate CombatSystem.** Wire combat to order execution events plus logistics/weather/espionage signals via `EventBusAutoload`.
27. [ ] **Implement pillar maths.** Encode Position/Impulse/Information calculations using doctrine, formation, terrain, weather, and intel modifiers exactly as SDS specifies. Annotate formulas in mission notes.
28. [ ] **Build combat UI.** Deliver HUD panels/modals showing gauges, textual summaries, and Élan adjustments; capture UI screenshots.
29. [ ] **Record telemetry.** Emit `combat_resolved` payloads with per-pillar breakdowns and resulting unit states.
30. [ ] **Automate combat checks.** Write gdUnit scenarios covering deterministic outcomes, tie-breakers, and edge cases. Archive result summaries.
31. [ ] **Document combat loop.** Update `README.md` and the mission brief with instructions for triggering combat and interpreting results.

## Phase 4 — Espionage & Fog of War
32. [ ] **Spawn EspionageSystem.** Ensure it initialises alongside combat/logistics systems and updates fog state each turn.
33. [ ] **Render fog visuals.** Dim hidden tiles, hide enemy intel, and keep player territory visible; document shader/material changes if any.
34. [ ] **Design recon flows.** Implement reconnaissance/spy orders with Élan/competence costs, integrate them into HUD + assistant pipeline, and log validation rules.
35. [ ] **Generate intel feedback.** Produce probabilistic pings with intent categories surfaced via HUD notifications and debug overlay timelines.
36. [ ] **Instrument espionage telemetry.** Emit `espionage_ping` and `intel_intent_revealed` events, preserving history in telemetry buffers.
37. [ ] **Test espionage systems.** Add gdUnit coverage for fog toggling, ping probability distribution, and intel decay. Attach outputs to mission notes.

## Phase 5 — Competence Sliders (Tactics / Strategy / Logistics)
38. [ ] **Extend TurnManager.** Track competence budget, inertia, and modifiers following SDS guidelines; expose state to HUD/telemetry.
39. [ ] **Ship HUD sliders.** Build slider controls with visual feedback and keyboard/controller shortcuts; capture interaction clips.
40. [ ] **Propagate slider effects.** Apply slider values to combat impulse, assistant AI planning, and logistics efficiency.
41. [ ] **Emit competence telemetry.** Publish `competence_reallocated` events with before/after values and turn IDs.
42. [ ] **Automate slider behaviour.** Cover inertia constraints and downstream effects via gdUnit tests; store logs.
43. [ ] **Update documentation.** Expand `README.md` and acceptance tests with slider usage guidance and expected outcomes.

## Phase 6 — Unit Formations & Postures
44. [ ] **Load formation definitions.** Map `data/formations.json` entries to unit archetypes and document the mapping.
45. [ ] **Implement formation controls.** Provide HUD interactions (dropdown/radial) respecting Élan costs and inertia delays.
46. [ ] **Integrate with combat.** Ensure `CombatSystem` consumes formation data when computing pillar modifiers; verify via logs/tests.
47. [ ] **Visualise formation changes.** Update map visuals/icons when formations shift; capture assets in mission notes.
48. [ ] **Emit formation telemetry.** Publish `formation_changed` events linked to combat outcomes.
49. [ ] **Test formation flows.** Add gdUnit coverage validating transitions, costs, and combat influence; archive results.

## Phase 7 — Telemetry, Analytics, and Assistant AI Insights
50. [ ] **Review telemetry schemas.** Cross-check all emitted events for schema consistency and update `docs/telemetry/dashboard_plan.md` with KPI dashboards.
51. [ ] **Persist telemetry buffers.** Extend `TelemetryAutoload` to persist session buffers (or stub) and document storage paths in README + mission brief.
52. [ ] **Enhance Assistant AI logging.** Record reasoning traces for orders, espionage suggestions, and logistics alerts; provide sample logs.
53. [ ] **Expose inspection tooling.** Add debug overlay panels or tooling to review telemetry buffers and assistant suggestions during playtests; capture screenshots.

## Phase 8 — Quality Assurance & Delivery Rituals
54. [ ] **Run mandatory headless commands.** Execute the three Godot headless scripts and save logs alongside the mission brief:
    - [ ] `godot --headless --path . --script res://scripts/ci/gd_lint_runner.gd`
    - [ ] `godot --headless --path . --script res://scripts/ci/gd_build_check.gd`
    - [ ] `godot --headless --path . --script res://scripts/ci/gdunit_runner.gd`
55. [ ] **Complete manual QA sweep.** Perform HUD interactions, logistics overlay toggles, combat resolutions, espionage pings, slider adjustments, and formation swaps; attach screenshots/GIFs.
56. [ ] **Refresh canonical docs.** Update `context_update.md`, append CHANGELOG/README notes, and regenerate `context_snapshot.md` after validation.
57. [ ] **Summarise in mission brief.** Document completion status, risks, and evidence links in `docs/agents/missions/vertical_slice_p0.md`.
58. [ ] **Prepare PR package.** Draft the PR description using the template in `docs/vibe_coding.md`, referencing checklist items and providing test logs.
