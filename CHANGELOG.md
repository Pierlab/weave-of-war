# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- Added gdUnit data integrity tests to load and validate the JSON data assets before gameplay systems consume them.
- Bootstraped the agent-driven workflow: root `AGENTS.md`, refreshed vibe-coding playbook, and mission workspace.
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
- Added a dedicated `logistics_break` telemetry signal with gdUnit coverage, README/TDD documentation, and a KPI dashboard
  starter in `docs/telemetry/dashboard_plan.md` to complete Checklist D instrumentation.
- Logged the EventBus/Telemetry autoload synchronisation strategy in [`docs/ADR_0002_event_bus_and_telemetry_autoloads.md`](docs/ADR_0002_event_bus_and_telemetry_autoloads.md) and wired the mission/checklist updates that close the ADR action item.
- Authored a living terminology glossary in [`docs/glossary.md`](docs/glossary.md) and linked it across docs to close the
  remaining Checklist D documentation task.

### Changed
- Updated onboarding docs (`README.md`, `docs/tests/acceptance_tests.md`) to describe the new rituals and automation.
- Pinned the CI workflow to Godot 4.5.1 using the latest setup action and cache cleanup step for consistent headless runs.
- Documented the new Godot `.uid` companion files in the README to clarify their purpose in resource referencing.
- Expanded logistics payloads with break summaries and competence penalty values so downstream systems can react to convoy
  interceptions without bespoke polling.
- Realigned the `vertical_slice_p0` mission brief checklist with delivered systems and documented the pending headless command blocage.

### Fixed
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
