# Vertical Slice P0 Execution Checklist (2025 Refresh)

This checklist replaces the earlier milestone summary and expands every deliverable required to land the Vertical Slice P0 described in `docs/project_spec.md`, the mission brief `docs/agents/missions/vertical_slice_p0.md`, and the SDS/TDD artefacts.

> **Legend**  
> `[ ]` = pending · `[~]` = in progress (replace the space with `~`) · `[x]` = complete with validation evidence linked in mission notes.

## Phase 0 — Alignment, Data Hygiene, and Instrumentation
- [ ] Re-read `docs/project_spec.md`, `docs/agents/missions/vertical_slice_p0.md`, and the latest `context_snapshot.md` to confirm scope, constraints, and prior work. Record any deltas in `context_update.md`.
- [ ] Audit `data/*.json` against the SDS requirements (doctrines, orders, units, weather, logistics, formations, competence sliders) and list missing fields or inconsistencies in the mission brief.
- [ ] Update `DataLoader` schemas/tests so that every JSON file used in P0 validates structure and required enums before gameplay scripts consume them.
- [ ] Ensure autoload singletons (`EventBusAutoload`, `DataLoaderAutoload`, `TelemetryAutoload`, `AssistantAIAutoload`) are registered in `project.godot` and emit/consume the baseline signals without warnings at startup.
- [ ] Fix HUD audio feedback: make `_play_feedback()` start the stream, guard playback access, and stop/clear safely so console logs stay clean. Attach a short validation clip/log to the mission brief.

## Phase 1 — Command Model & Élan Core Loop
### Data & Design Contracts
- [ ] Confirm doctrine list (Force/Ruse/Patience/Vitesse/Équilibre) matches order requirements and update `data/doctrines.json` plus localisation strings accordingly.
- [ ] Expand `data/orders.json` with costs, doctrine permissions, and AI intent metadata that aligns with the SDS command rules.
- [ ] Document doctrine/order UX copy and audio cues in the HUD section of `README.md`.

### Implementation & Integration
- [ ] Instantiate `DoctrineSystem` and `ElanSystem` within `GameManager` with typed references and ensure they listen to `data_loader_ready` before running setup logic.
- [ ] Enforce doctrine inertia and Élan caps per SDS, exposing current inertia and Élan totals to the HUD (labels/tooltips).
- [ ] Connect HUD selectors to `EventBusAutoload` to request doctrine swaps/orders and display error messaging when validation fails.
- [ ] Ensure the assistant AI receives issued orders and logs interpretations for telemetry/debug overlay.

### Validation & Telemetry
- [ ] Add gdUnit tests covering doctrine change success/failure, Élan gain/spend limits, and assistant AI acknowledgements.
- [ ] Emit telemetry events: `doctrine_selected`, `order_issued`, `order_rejected`, `elan_spent`, `elan_gained` with structured payloads.
- [ ] Update `docs/tests/acceptance_tests.md` with manual steps for selecting doctrines, issuing orders, and checking telemetry buffers.

## Phase 2 — Logistics Backbone + Terrain & Weather Layering
### Logistics Foundations
- [ ] Implement `LogisticsSystem` instantiation in `GameManager` with hooks to `EventBusAutoload` for turn updates and HUD toggles.
- [ ] Load logistics rings, nodes, and convoy routes from `data/logistics.json`; validate via gdUnit that supply graphs are connected per scenario definition.
- [ ] Animate supply flows on the map (rings + moving convoy sprites) with state-dependent colouring.
- [ ] Publish `logistics_update` signals containing reachable tiles, supply deficits, and convoy statuses each turn.

### Terrain & Weather Coupling
- [ ] Extend map tiles with terrain metadata (Plains/Forest/Hill) sourced from data; display tooltips in HUD/debug overlay.
- [ ] Build a Weather controller that cycles through Sunny/Rain/Mist (and optional Snow/Storm hooks) with deterministic seeds for tests.
- [ ] Ensure weather modifiers affect logistics throughput and convoy vulnerability as defined in the SDS.
- [ ] Emit `weather_changed` telemetry with modifiers applied; update HUD icons/animations to reflect current weather.

### Validation
- [ ] Create gdUnit tests verifying logistics reachability, convoy interception hooks, and weather rotation cadence.
- [ ] Update `docs/tests/acceptance_tests.md` with manual checks for toggling the logistics overlay, viewing terrain tooltips, and observing weather-driven changes.

## Phase 3 — Combat (3 Pillars)
- [ ] Instantiate `CombatSystem` in `GameManager` and subscribe to order execution events plus logistics/weather/espionage signals.
- [ ] Implement pillar calculations (Position, Impulse, Information) using doctrines, formations, terrain, weather, and intel modifiers per SDS.
- [ ] Create combat resolution UI (HUD panel or modal) with three gauges, textual summaries, and Élan adjustments.
- [ ] Log outcomes to telemetry (`combat_resolved`) including per-pillar breakdown and resulting unit states.
- [ ] Add gdUnit coverage for deterministic combat scenarios, ensuring tie-breaker and edge-case handling.
- [ ] Document the combat loop in `README.md` and the mission brief, including how to trigger and interpret results.

## Phase 4 — Espionage & Fog of War
- [ ] Instantiate `EspionageSystem` alongside combat/logistics systems; ensure turn start hooks update fog states.
- [ ] Implement fog of war rendering on the map (dim tiles, hide enemy details) while keeping player territories visible.
- [ ] Design reconnaissance/spy order flows, including Élan or competence costs, and integrate them into the HUD/assistant AI pipeline.
- [ ] Generate probabilistic intel pings with intent categories and surface them through HUD notifications + debug overlay.
- [ ] Emit telemetry events `espionage_ping`, `intel_intent_revealed`, and maintain history in telemetry buffer for QA.
- [ ] Write gdUnit tests for fog toggling, ping probability distribution, and intel decay over turns.

## Phase 5 — Competence Sliders (Tactics / Strategy / Logistics)
- [ ] Extend `TurnManager` to track competence budget, inertia, and their modifiers per SDS.
- [ ] Create HUD slider controls with visual feedback and integrate with keyboard/controller shortcuts.
- [ ] Apply slider values to relevant systems: tactics affects combat impulse, strategy influences assistant AI planning, logistics boosts supply efficiency.
- [ ] Emit telemetry `competence_reallocated` with before/after values and link to turn IDs.
- [ ] Cover slider operations with gdUnit tests ensuring inertia constraints and effect propagation to dependent systems.
- [ ] Document slider usage and impacts in `README.md` and acceptance tests.

## Phase 6 — Unit Formations & Postures
- [ ] Load formation definitions from `data/formations.json` and associate them with unit archetypes.
- [ ] Provide HUD controls (dropdown or radial) to assign formations/postures, respecting Élan costs and inertia delays.
- [ ] Ensure `CombatSystem` consumes formation data when computing Position/Impulse modifiers.
- [ ] Update visual representation on the map (icons or overlays) when formations change.
- [ ] Emit telemetry `formation_changed` and link to combat outcomes for analytics.
- [ ] Add gdUnit coverage verifying formation transitions, costs, and combat influence.

## Phase 7 — Telemetry, Analytics, and Assistant AI Insights
- [ ] Review all emitted telemetry events for schema consistency; update `docs/telemetry/dashboard_plan.md` with dashboards answering mission KPIs.
- [ ] Ensure `TelemetryAutoload` persists session buffers to disk (or stub) for later ingestion; document storage path in README.
- [ ] Extend `AssistantAIAutoload` to log reasoning traces for orders, espionage suggestions, and logistics alerts.
- [ ] Provide tooling (e.g., debug overlay panels) to inspect telemetry buffers and assistant suggestions during playtests.

## Phase 8 — Quality Assurance & Delivery Rituals
- [ ] Run required commands and archive logs in mission notes:
  - [ ] `godot --headless --path . --script res://scripts/ci/gd_lint_runner.gd`
  - [ ] `godot --headless --path . --script res://scripts/ci/gd_build_check.gd`
  - [ ] `godot --headless --path . --script res://scripts/ci/gdunit_runner.gd`
- [ ] Perform manual smoke tests covering HUD interactions, logistics overlay, combat resolution, espionage pings, slider adjustments, and formation swaps; capture screenshots/GIFs for review.
- [ ] Refresh `context_update.md`, append CHANGELOG/README updates, and regenerate `context_snapshot.md` after final validation.
- [ ] Summarise completion status and outstanding risks in `docs/agents/missions/vertical_slice_p0.md` with links to evidence (logs, videos, telemetry dumps).
- [ ] Prepare PR description following the template in `docs/vibe_coding.md`, referencing this checklist and mission deliverables.
