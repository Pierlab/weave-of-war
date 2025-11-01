# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- Introduced [`data/competence_sliders.json`](data/competence_sliders.json) and extended `TurnManager` to enforce per-category inertia locks, delta caps, and modifier tracking (`logistics_penalty`) so HUD/telemetry consumers can react to competence reallocations and supply disruptions.
- Added espionage-focused gdUnit coverage (`tests/gdunit/test_combat_and_espionage_systems.gd`) validating fog snapshot emissions, probabilistic ping success rates, and counter-intel decay to close checklist item 37.
- Instrumented espionage telemetry with a dedicated `intel_intent_revealed` event, normalised payloads in `TelemetryAutoload`, and preserved per-event history so analytics dashboards can compare ping confidence against revealed intentions.
- Added a fog-of-war rendering pipeline: `EspionageSystem` now emits `fog_of_war_updated` snapshots and the hex map applies a
  dark overlay/tooltip redaction when visibility falls below scout confidence, keeping player-controlled supply rings readable
  while concealing enemy intel.
- Added reconnaissance and deep cover orders to `data/orders.json`: these consume Élan plus competence points, surface their
  combined costs in the HUD, and trigger automatic `espionage_ping` payloads that prioritise the least visible tiles when
  issued.
- Added an intelligence feedback layer: `espionage_ping` payloads now expose roll/visibility deltas, competence bonuses, and
  intent confidence while the HUD "Renseignements" panel and debug overlay timeline surface coloured summaries for each ping
  (success vs countered, intention revealed, probability vs RNG roll).
- Added a HUD "Dernier engagement" panel driven by `combat_resolved` that renders pillar gauges, logistics flow/severity, and
  Élan adjustments so players can review battle context without relying on the debug overlay.
- Extended `combat_resolved` payloads with pillar summaries and per-unit outcomes (formation, casualties, logistics notes) and
  normalised the Telemetry buffer so analytics/HUD consumers can reference combat state without recomputing strengths.
- Added gdUnit combat regression scenarios (`tests/gdunit/test_combat_resolution.gd`) validating seed reproducibility, contested
  tie-breakers, and critical logistics penalties so pillar maths stay trustworthy as the SDS evolves.
- Refined `CombatSystem` pillar resolution with doctrine focus, logistics severity (flow + movement cost), terrain/weather
  multipliers, and intel profiles so Position/Impulse/Information follow the documented SDS formulas. Mission brief and README
  now outline the equations for future tuning.
- Instantiated `CombatSystem` from `GameManager`, wired it to `logistics_update`/order events, and extended `combat_resolved`
  payloads with logistics context so engagements reflect supply health alongside doctrine, weather, and espionage inputs.
- Instantiated `EspionageSystem` from `GameManager`, hydrated fog-of-war from `data/terrain.json`, and added gdUnit coverage to
  ensure EventBus turn ticks keep `espionage_ping` telemetry aligned with logistics updates.
- Refreshed manual acceptance tests (AT-08 à AT-10) pour couvrir la bascule HUD/debug du overlay logistique, les tooltips terrain dynamiques et les impacts météo sur `logistics_update`.
- Introduced `WeatherSystem` to cycle weather states deterministically from `data/weather.json`, emit rich `weather_changed`
  payloads, and drive the new HUD weather panel. Added gdUnit coverage in `tests/gdunit/test_weather_system.gd` to lock the
  rotation order and seeded duration rolls.
- Extended `tests/gdunit/test_logistics_system.gd` with coverage for storm-driven reachability, single-fire convoy interception breaks,
  and logistics-triggered weather rotation cadence so supply telemetry stays deterministic under adverse conditions.
- Normalised `weather_changed` telemetry in `TelemetryAutoload`, added gdUnit coverage to ensure the buffer captures the
  schema, and documented the dashboard fields so analytics consumers can track climate-driven modifiers.
- Linked weather penalties directly to logistics throughput and convoy interception risk by extending `LogisticsSystem` with
  `weather_adjustments` summaries and per-route `intercept_risk` data in every `logistics_update` payload.
- Introduced [`data/terrain.json`](data/terrain.json) and wired it through `DataLoader`, the hex map, and HUD/debug overlay
  tooltips so Plains/Forest/Hill tiles display names, movement costs, and contextual summaries sourced directly from data.
- Enriched `LogisticsSystem` `logistics_update` payloads with `reachable_tiles`, `supply_deficits`, and `convoy_statuses`, updating datasets, docs, and tests so downstream systems can react to supply health without rehydrating raw tile maps.
- Rendered the logistics overlay with pulsing supply rings and animated convoy markers that react to convoy interceptions and
  flow strength emitted by `LogisticsSystem`.
- Expanded `data/logistics.json` with explicit supply center and route graphs, taught `LogisticsSystem` to ingest them, and added gdUnit coverage ensuring every logistics scenario map stays connected.
- Bootstrapped `LogisticsSystem` from `GameManager` so headless turn cycles and HUD toggles immediately emit supply payloads, backed by gdUnit coverage of the integration path.
- Instrumented the command loop telemetry: `EventBusAutoload` now emits `order_rejected`/`elan_gained`, `TelemetryAutoload` normalises the `doctrine_selected`/`order_issued`/`order_rejected`/`elan_spent`/`elan_gained` payloads, and `tests/gdunit/test_command_elan_loop.gd` locks the new schemas while README + telemetry dashboard docs capture the fields.
- Added gdUnit regression tests covering doctrine swap gating, Élan spend failures, and Assistant AI acknowledgements to secure the command loop behaviour.
- Expanded `data/orders.json` with CP costs, base delay turns, doctrine requirements, targeting scopes, posture gates, and assistant intent metadata, updating the DataLoader schema and gdUnit data integrity coverage accordingly.
- Locked the doctrine catalogue to the five SDS-defined stances with command profile metadata (CP caps, swap tokens, inertia multipliers) for downstream systems.
- Added gdUnit data integrity tests to load and validate the JSON data assets before gameplay systems consume them.
- Bootstraped the agent-driven workflow: root `AGENTS.md`, refreshed vibe-coding playbook, and mission workspace.

### Fixed
- Corrected the combat resolution payload to store unit state dictionaries (attacker/defender blocks) instead of forcing them
  into an array, restoring Godot's typed parsing and allowing `GameManager` to instantiate `CombatSystem` without compile
  errors. The HUD feedback audio now primes its `AudioStreamPlayer` before requesting the generator playback to silence the
  startup `Player is inactive` warning.
- Restored Godot script loading by typing combat/HUD variables that previously inferred as `Variant`, aligning `CombatSystem`
  and `HUDManager` with the explicit casting pattern so warnings no longer escalate to parse errors during headless runs.
- Introduced lightweight gdUnit-style tests plus CI runners for lint, build, and test checks.
- Added automatic context snapshot generator and documentation for maintaining context updates.
- Created GitHub Actions pipeline to execute headless lint/build/test commands and enforce snapshot freshness.
- Published `CHECKLISTS.md` at the repository root to capture the vertical slice P0 vibe-coding checklists.
- Authored the `vertical_slice_p0` mission brief to drive Vertical Slice P0 delivery across the eight core systems.
- Drafted SDS outlines for all eight P0 systems in `docs/design/sds_outlines.md` and linked them from the mission brief and
  README.
- Locked dedicated SDS documents for the Command Model and Élan systems with acceptance criteria under
  `docs/design/sds_command_model.md` and `docs/design/sds_elan.md`.
- Authored a one-page vertical slice GDD synthèse in `docs/gdd_vertical_slice.md` to capture vision, fantasy, piliers, boucles,
  et risques.
- Documented a week-by-week (Semaine 0–6) delivery timeline in the vertical slice mission brief to guide milestone execution.
- Published the data-driven architecture TDD in `docs/design/tdd_architecture_data.md`, outlining autoloads, event bus
  contracts, and assistant AI/data pipeline responsibilities for Checklist B.
- Documented the JSON→runtime mapping table in the data-driven architecture TDD so agents can locate loaders and consumer
  scripts quickly when extending schemas.
- Expanded the Vertical Slice JSON schemas under `data/` to include inertia locks, Élan costs, and logistics/weather interplays
  required for gameplay scripting.
- Configured global autoload singletons (`EventBus`, `DataLoader`, `Telemetry`, `AssistantAI`), emitted readiness telemetry, and
  updated tests/docs so Checklist C systems can plug into shared data and signals immediately.
- Deferred the `DataLoader` readiness broadcast so `Telemetry`/`AssistantAI` reliably capture `data_loader_ready`, and added
  gdUnit coverage (`tests/gdunit/test_autoload_preparation.gd`) to lock the handshake.
- Delivered the initial command/Élan loop with doctrine selection, inertia tracking, Élan caps, HUD feedback, and gdUnit
  coverage for the systems interplay.
- Enforced doctrine inertia multipliers and Élan cap decay with doctrine bonuses, refreshed HUD tooltips/labels to surface the
  new rules, and updated datasets plus gdUnit coverage to lock the command loop.
- Implemented the hybrid logistics backbone with rotating weather states, convoy progress telemetry, and gdUnit coverage for
  supply rings, terrain penalties, and interception odds.
- Delivered the Combat 3 Piliers + espionage milestone: `CombatSystem` resolves pillars with doctrine/weather/terrain inputs,
  `EspionageSystem` maintains fog-of-war with probabilistic pings, and gdUnit coverage (`test_combat_and_espionage_systems.gd`)
  guards telemetry events.
- Completed the Semaine 6 competence & formations loop with a new formations dataset, `TurnManager` competence budget, and
  `CombatSystem` formation/competence hooks validated by gdUnit coverage (`test_competence_and_formations.gd`).
- Added telemetry for competence reallocations and formation changes, wiring the new events through `Telemetry`, the HUD bus,
  and data integrity checks for [`data/formations.json`](data/formations.json).
- Documented a fallback JSON validation snippet in the README so agents can verify data integrity while provisioning a local
  Godot binary.
- Documented HUD doctrine/order copy, audio cues, and accessibility notes in the README to lock the checklist item for the
  Command & Élan loop.
- Wired `AssistantAIAutoload` order packet history and a debug overlay log so every executed order exposes the assistant's
  interpreted intent, target, and confidence.
- Added a dedicated `logistics_break` telemetry signal with gdUnit coverage, README/TDD documentation, and a KPI dashboard
  starter in `docs/telemetry/dashboard_plan.md` to complete Checklist D instrumentation.
- Logged the EventBus/Telemetry autoload synchronisation strategy in [`docs/ADR_0002_event_bus_and_telemetry_autoloads.md`](docs/ADR_0002_event_bus_and_telemetry_autoloads.md) and wired the mission/checklist updates that close the ADR action item.
- Authored a living terminology glossary in [`docs/glossary.md`](docs/glossary.md) and linked it across docs to close the
  remaining Checklist D documentation task.
- Captured autoload readiness instrumentation: renamed the singletons in `project.godot`, extended `tests/gdunit/test_autoload_preparation.gd` to assert configuration/signals, and archived the startup log excerpt under `docs/logs/autoload_readiness_2025-11-04.log` for future audits.

### Changed
- Documented the combat loop workflow: README now explique comment déclencher un engagement depuis la HUD Commandement, lire le panneau "Dernier engagement" et inspecter la télémétrie `combat_resolved`, tandis que le mission brief référence le Remote Debugger pour clôturer l'item 31 de la checklist.
- Updated HUD docs to cover competence-aware order execution: the selector lists `competence_cost` entries, the execute button blocks when the remaining allocations are insufficient, and feedback copy surfaces the exact shortfalls for recon/spy orders.
- Decoupled the core autoload script classes (`EventBus`, `DataLoader`, `Telemetry`, `AssistantAI`) from their singleton keys to avoid the Godot 4.6 `class_name_hides_autoload` parse error, refreshed docs/tests to reflect the new typing pattern, and hardened `DataLoader`/`LogisticsSystem` with explicit hints so warnings-as-errors no longer block startup.
- Deferred `GameManager` core system initialisation until `data_loader_ready`, logging collection counts and starting the turn loop only after Doctrine/Élan setup succeeds.
- Documented the expected Windows startup warnings (SDL controller mappings, Vulkan loader layer manifests, optional Vulkan extensions) in the README so agents know the logs are benign and how to silence them locally if desired.
- Hardened `DataLoaderAutoload` to validate schema keys, enums, and numeric fields at load time and exposed `validate_collection()` so tests and tooling can reuse the checks.
- Re-sequenced the Vertical Slice P0 checklist into a numbered execution script with detailed validations and cross-doc updates referenced from the mission brief and README.
- Documented the Phase 0 data gap audit in the vertical slice mission brief and README so upcoming schema work stays aligned with the locked SDS expectations.
- Updated onboarding docs (`README.md`, `docs/tests/acceptance_tests.md`) to describe the new rituals and automation.
- Expanded `docs/tests/acceptance_tests.md` AT-07 with explicit steps for doctrine swaps, order issuance validation, and telemetry buffer review to close Phase 1 manual checks.
- Replaced the root vertical slice checklist with a 2025 detailed execution plan and archived the previous milestone summary under `docs/agents/archive/`.
- Pinned the CI workflow to Godot 4.5.1 using the latest setup action and cache cleanup step for consistent headless runs.
- Documented the new Godot `.uid` companion files in the README to clarify their purpose in resource referencing.
- Expanded logistics payloads with break summaries and competence penalty values so downstream systems can react to convoy
  interceptions without bespoke polling.
- Realigned the `vertical_slice_p0` mission brief checklist with delivered systems and documented the pending headless command blocage.
- HUD doctrine and order controls now raise EventBus requests directly, restore the previous doctrine when inertia blocks a swap, and surface Élan shortfall tooltips so validation feedback stays visible without leaving the HUD.

### Fixed
- Stopped Godot 4.6 from aborting on Variant inference by explicitly typing logistics route IDs and clamping Élan cap updates,
  and ensured terrain definitions are duplicated before merge so the map no longer mutates read-only dictionaries at runtime.
- Stabilised the HUD's procedural audio feedback by queueing tone requests and clearing the generator buffer only after the
  playback instance reports inactive, eliminating `AudioStreamGeneratorPlayback.clear_buffer` warnings during doctrine/order
  swaps and shutdown.
- Regenerated the Godot class cache metadata to reflect the `*Autoload` class names so typed autoload references no longer
  trigger `Could not find type` parse errors when the project boots.
- Reordered `class_name` declarations ahead of `extends` statements across core systems/autoloads to remove editor parse
  errors when loading the project.
- CI headless scripts now extend `SceneTree` so `godot --script` runs succeed in local and CI environments.
- Preloaded map and UI dependencies so the build smoke check no longer fails on missing `HexTile` or `EventBus` types.
- Corrected UI scene node parenting so headless instantiation no longer drops children or crashes the build smoke check.
- Updated HUD and game manager scripts to use Godot 4's Python-style conditional expressions, removing project load parse errors.
- Resolved new Godot 4.5 warnings by renaming EventBus preload constants, repairing logistics toggle handlers, and aligning HUD
  and debug overlay parenting so the UI buttons are found at runtime.
- Silenced autoload/class name conflicts and added explicit type hints so Godot 4.5 no longer aborts on Variant inference errors
  when loading autoloads and the HUD scene.
- Renamed autoload script classes to follow the `*Autoload` pattern and hardened Élan/TurnManager typing so warnings-as-errors no
  longer block startup when launching the project in Godot 4.5.1.
- Restored the Élan system's turn income calculation by casting doctrine/unit dictionaries explicitly, removing the Variant
  inference warning that Godot elevated to a blocking error on project load.
- Hardened Élan type hints further by annotating clamp results and dictionary lookups so Godot no longer reports "Cannot infer"
  parse errors when loading the project.
- Primed the HUD's procedural audio generator before requesting playback so doctrine/order interactions no longer emit inactive
  audio player errors in the console.
- Stopped and drained the HUD feedback generator before clearing frames so repeated doctrine/turn interactions no longer spam
  `AudioStreamGeneratorPlayback.clear_buffer` errors or leak playback instances at shutdown.
- Guarded the HUD feedback generator's stop-and-clear sequence so `clear_buffer()` only runs once playback is fully inactive,
  eliminating the `Condition "active" is true` assertions that resurfaced during doctrine changes and turn advances.

### Fixed
- Restored Godot 4.5+ project loading by suppressing the new `class_name`/autoload warning and adding explicit type hints across
  `DataLoader`, logistics/weather/terrain systems, and UI scripts; replaced deprecated APIs (`Array.join`, float modulo) so
  warnings-as-errors no longer block autoload initialisation or logistics overlay rendering.
