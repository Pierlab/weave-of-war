# AGENTS — Operational Guide for Coding Assistants

Welcome to **Weave of War**. This file is the first stop for every coding agent. It summarises the current rituals, required
artefacts, and quality bars that keep the project coherent when we work in vibe-coding loops.

## 1. Before you touch the code
1. Read the following documents in order:
   - [`docs/vibe_coding.md`](docs/vibe_coding.md) — describes the iteration loop and checklist discipline.
   - [`context_snapshot.md`](context_snapshot.md) — auto-generated state of the codebase after the latest merge.
   - [`context_update.md`](context_update.md) — running log of changes made in the active PR.
   - The active mission brief inside `docs/agents/missions/` (one file per mission).
   - [`docs/project_spec.md`](docs/project_spec.md) for the product north star.
2. Confirm whether the mission you picked already has an open checklist. If not, create or refresh it using the template in
   [`docs/agents/agent_base.md`](docs/agents/agent_base.md).

## 2. Implementation rules
- Follow Godot GDScript best practices (Godot 4.x). Prefer composition via nodes/signals. Keep functions under ~30 lines.
- Use descriptive English names and type hints. Document non-obvious flows with comments or docstrings.
- Keep diffs scoped: touch only files that advance the active mission and update their related docs.
- When introducing new systems, add or update mission briefs so future agents inherit the plan.

## 3. Mandatory artefacts to update
Whenever you modify behaviour or project structure, review and update:
- [`README.md`](README.md) for onboarding/usage notes.
- [`CHANGELOG.md`](CHANGELOG.md) with a new entry under the latest heading.
- [`context_update.md`](context_update.md) with a bullet list describing the PR-level changes and follow-ups.
- [`context_snapshot.md`](context_snapshot.md) by running `python scripts/generate_context_snapshot.py` at the end of your work.
- Mission files inside `docs/agents/missions/` so they reflect the latest scope and checklist state.
- Any impacted docs (`docs/vibe_coding.md`, `docs/project_spec.md`, `docs/tests/*`). Keep everything consistent.

## 4. Testing expectations
- Automated tests live under `res://tests/`. We run them through a lightweight gdUnit-style harness.
- **Required commands (headless Godot 4.x):**
  ```bash
  godot --headless --path . --script res://scripts/ci/gd_lint_runner.gd
  godot --headless --path . --script res://scripts/ci/gd_build_check.gd
  godot --headless --path . --script res://scripts/ci/gdunit_runner.gd
  ```
- Record all executed commands (and their results) in the PR summary.
- If a command cannot run locally, state why in the PR and provide the reasoning artefacts (logs, screenshots).

## 5. Continuous integration
- GitHub Actions validate linting, build loading, and automated tests on every push. Keep workflow files in sync with local
  scripts.
- Never disable CI steps without opening a discussion in the mission brief.

## 6. Pull request checklist
Before requesting review:
1. Ensure the mission checklist is complete and referenced in the PR body.
2. Update `context_update.md` with a short narrative of the changes and outstanding questions.
3. Run the commands in section 4 and paste their output (or explain blockers) into the PR template.
4. Regenerate `context_snapshot.md` and confirm it is committed.
5. Double-check docs and changelog are current.

Keep this file up to date whenever the workflow evolves. If you create nested folders with their own rules, add another
`AGENTS.md` there describing the specifics.
