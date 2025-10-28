# Mission: Bootstrap vibe-coding operations

## Goal
Establish the automation, documentation, and workflows required for coding agents to work in vibe mode with confidence.

## Inputs
- [`docs/project_spec.md`](../project_spec.md)
- [`docs/vibe_coding.md`](../vibe_coding.md)
- [`context_snapshot.md`](../../context_snapshot.md) (regenerate after completing this mission)
- [`context_update.md`](../../context_update.md)

## Acceptance tests
- Automated CI commands exist for linting, build, and gdUnit-style tests.
- `CHANGELOG.md`, `context_snapshot.md`, and `context_update.md` reflect the latest repository state.
- Mission directory contains at least this bootstrap brief.
- README communicates how to run tests and regenerate the context snapshot.

## Constraints
- Keep the automation lightweight and compatible with Godot 4.x headless execution.
- Do not introduce external package managers that require network access during CI.
- Maintain documentation clarity; remove redundant legacy text if superseded.

## Implementation checklist
- [x] Author root `AGENTS.md` with onboarding, testing, and documentation rituals.
- [x] Refresh `docs/vibe_coding.md` to reference context artefacts and CI commands.
- [x] Create mission workspace structure under `docs/agents/`.
- [x] Add lightweight gdUnit-style harness and CI scripts under `res://scripts/ci/` and `res://tests/`.
- [x] Add automation for generating `context_snapshot.md` and document how to use it.
- [x] Update README, changelog, and acceptance tests to reflect the new workflow expectations.

## Deliverables
- Updated documentation files committed (README, vibe coding playbook, mission briefs, tests doc).
- New automation scripts (`scripts/generate_context_snapshot.py`, Godot CI runners, GitHub Actions workflow).
- Latest `context_snapshot.md`, `context_update.md`, and `CHANGELOG.md` entries summarising the work.
- Evidence of commands to run CI scripts locally.

## Handoff
Status: **In progress while this branch is open.**
- Once merged, future missions should duplicate this file or the base template to continue the workflow.
- Watch CI logs after the first merge to ensure the headless commands run correctly in GitHub Actions.
