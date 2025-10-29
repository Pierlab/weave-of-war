# Weave of War

Weave of War is a strategy game prototype built with Godot 4.x that focuses on logistics, doctrines, and Élan-driven momentum.
This repository now bundles the rituals and automation needed for agent-driven vibe coding.

## Getting Started
1. Install [Godot 4.5.1](https://godotengine.org/) (headless-capable builds are required for CI parity).
2. Open the project by launching Godot and selecting the `project.godot` file in this repository.
3. Read [`AGENTS.md`](AGENTS.md) for the workflow rules, required documents, and test commands.
4. Review the current mission briefs in [`docs/agents/missions/`](docs/agents/missions/)—start with
   [`vertical_slice_p0.md`](docs/agents/missions/vertical_slice_p0.md) to align on the vertical slice scope—and the latest
   [`context_snapshot.md`](context_snapshot.md).
5. Utilise the vertical slice planning checklists in [`CHECKLISTS.md`](CHECKLISTS.md) to coordinate upcoming tasks.

## Running automated checks
All headless commands assume the Godot executable is available on your `PATH`. When switching branches or updating Godot, remove
the `.godot/` metadata folder to avoid stale parser caches before running the commands below.
```bash
godot --headless --path . --script res://scripts/ci/gd_lint_runner.gd
godot --headless --path . --script res://scripts/ci/gd_build_check.gd
godot --headless --path . --script res://scripts/ci/gdunit_runner.gd
```
These scripts now extend `SceneTree` directly so they can be executed with `--script` in both local shells and CI runners.
They power local validation and the GitHub Actions workflow defined in `.github/workflows/ci.yml`.

### Troubleshooting build parsing
- If the build smoke check reports missing class names (for example `HexTile` or `EventBus`), preload the corresponding script
  resource before using it for type annotations or `is` checks. See `scenes/map/map.gd` and the UI scripts under
  `scripts/ui/` for reference on the preferred preload pattern.

## Maintaining context for agents
- After each iteration, run `python scripts/generate_context_snapshot.py` to refresh [`context_snapshot.md`](context_snapshot.md).
- Document branch-level progress in [`context_update.md`](context_update.md) so the next agent can resume smoothly.
- Append notable entries to [`CHANGELOG.md`](CHANGELOG.md) before requesting review.
- Reference the draft SDS outlines for the eight P0 systems in [`docs/design/sds_outlines.md`](docs/design/sds_outlines.md) when
  planning gameplay or telemetry changes.

## Acceptance Checks
The high-level manual acceptance flow lives in [`docs/tests/acceptance_tests.md`](docs/tests/acceptance_tests.md). Keep it in sync
with the Godot scenes and systems as they evolve.
