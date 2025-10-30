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

### Changed
- Updated onboarding docs (`README.md`, `docs/tests/acceptance_tests.md`) to describe the new rituals and automation.
- Pinned the CI workflow to Godot 4.5.1 using the latest setup action and cache cleanup step for consistent headless runs.
- Documented the new Godot `.uid` companion files in the README to clarify their purpose in resource referencing.

### Fixed
- CI headless scripts now extend `SceneTree` so `godot --script` runs succeed in local and CI environments.
- Preloaded map and UI dependencies so the build smoke check no longer fails on missing `HexTile` or `EventBus` types.
- Corrected UI scene node parenting so headless instantiation no longer drops children or crashes the build smoke check.
- Updated HUD and game manager scripts to use Godot 4's Python-style conditional expressions, removing project load parse errors.
- Resolved new Godot 4.5 warnings by renaming EventBus preload constants, repairing logistics toggle handlers, and aligning HUD
  and debug overlay parenting so the UI buttons are found at runtime.
