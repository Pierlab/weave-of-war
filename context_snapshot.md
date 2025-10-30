# Context Snapshot

- Generated on: 2025-10-30T15:35:50Z
- Branch: work
- Commit when generated: b2f9b4a462a7f70553b8e7535024aae2be59310c
- Subject: Merge pull request #23 from Pierlab/codex/update-checklist.md-with-completed-action-j1ng2n
- Working tree dirty: True
- Note: commit hash may differ once this file is included in a new commit.

## Mission briefs
- docs/agents/missions/bootstrap_vibe_coding.md
- docs/agents/missions/vertical_slice_p0.md

## Godot scenes
- scenes/main.tscn
- scenes/map/hex_tile.tscn
- scenes/map/map.tscn
- scenes/ui/debug_overlay.tscn
- scenes/ui/hud.tscn

## Scripts
- scripts/ci/gd_build_check.gd
- scripts/ci/gd_lint_runner.gd
- scripts/ci/gdunit_runner.gd
- scripts/core/assistant_ai.gd
- scripts/core/data_loader.gd
- scripts/core/event_bus.gd
- scripts/core/game_manager.gd
- scripts/core/telemetry.gd
- scripts/core/turn_manager.gd
- scripts/core/utils.gd
- scripts/generate_context_snapshot.py
- scripts/systems/combat_system.gd
- scripts/systems/doctrine_system.gd
- scripts/systems/elan_system.gd
- scripts/systems/espionage_system.gd
- scripts/systems/logistics_system.gd
- scripts/ui/debug_overlay.gd
- scripts/ui/hud_manager.gd

## CI scripts
- scripts/ci/gd_build_check.gd
- scripts/ci/gd_lint_runner.gd
- scripts/ci/gdunit_runner.gd

## Automated tests
- tests/gdunit/assertions.gd
- tests/gdunit/test_autoload_preparation.gd
- tests/gdunit/test_case.gd
- tests/gdunit/test_combat_and_espionage_systems.gd
- tests/gdunit/test_command_elan_loop.gd
- tests/gdunit/test_competence_and_formations.gd
- tests/gdunit/test_data_integrity.gd
- tests/gdunit/test_logistics_system.gd
- tests/gdunit/test_smoke.gd

## Key documentation
- README.md
- CHANGELOG.md
- context_update.md
- docs/vibe_coding.md
- docs/tests/acceptance_tests.md
- docs/project_spec.md

## GitHub workflows
- .github/workflows/ci.yml

## Usage
- Run `python scripts/generate_context_snapshot.py` after every merge or significant change.
- Cross-check with `context_update.md` to understand in-flight work.
