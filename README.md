# Weave of War

Weave of War is a strategy game prototype built with Godot 4.x that focuses on logistics, doctrines, and Élan-driven momentum.
This repository now bundles the rituals and automation needed for agent-driven vibe coding.

## Getting Started
1. Install [Godot 4.x](https://godotengine.org/).
2. Open the project by launching Godot and selecting the `project.godot` file in this repository.
3. Read [`AGENTS.md`](AGENTS.md) for the workflow rules, required documents, and test commands.
4. Review the current mission briefs in [`docs/agents/missions/`](docs/agents/missions/) and the latest
   [`context_snapshot.md`](context_snapshot.md).

## Running automated checks
All headless commands assume the Godot executable is available on your `PATH`.
```bash
godot --headless --path . --script res://scripts/ci/gd_lint_runner.gd
godot --headless --path . --script res://scripts/ci/gd_build_check.gd
godot --headless --path . --script res://scripts/ci/gdunit_runner.gd
```
These scripts power both local validation and the GitHub Actions workflow defined in `.github/workflows/ci.yml`.

## Maintaining context for agents
- After each iteration, run `python scripts/generate_context_snapshot.py` to refresh [`context_snapshot.md`](context_snapshot.md).
- Document branch-level progress in [`context_update.md`](context_update.md) so the next agent can resume smoothly.
- Append notable entries to [`CHANGELOG.md`](CHANGELOG.md) before requesting review.

## Acceptance Checks
The high-level manual acceptance flow lives in [`docs/tests/acceptance_tests.md`](docs/tests/acceptance_tests.md). Keep it in sync
with the Godot scenes and systems as they evolve.
