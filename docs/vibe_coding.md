# Weave of War — Vibe Coding (agent orchestration)

> Purpose: Make this repo “agent-friendly”: consistent context, safe PRs, automatic checks, and crisp missions.

## 1) Branching & PR policy
- Protected `main`. Work on short-lived feature branches: `feature/<scope>`, `chore/<scope>`, `fix/<scope>`.
- Conventional Commits in PR titles (`feat:`, `fix:`, `chore:`, `refactor:`, `test:`).
- **Agent rule**: never push to `main`; always open a PR.
- Max diff per PR: ~300 LOC (encourage small, reviewable changes).

## 2) Required PR checklist
- [ ] All tests green (gdUnit4 or scripted asserts).  
- [ ] No Godot errors/warnings on run.  
- [ ] Follows folder & naming conventions.  
- [ ] Contains minimal docs: `docs/agents/<mission>.md` with context, assumptions, decisions.  
- [ ] Updates `CHANGELOG.md` and emits telemetry events if relevant.  
- [ ] Adds/updates `context_snapshot.md` (what changed, why, how to extend).

### PR template (paste in description)
```
## What
## Why (player impact / Sun Tzu principle)
## How (tech brief, files touched)
## Tests (how to run, expected output)
## Telemetry (events added/used)
## Risks / Rollback plan
```

## 3) Repository layout (expected)
- `assets/`, `scenes/`, `scripts/`, `data/`, `docs/`
- Key scenes: `main.tscn`, `map.tscn`, `ui/hud.tscn`, `ui/debug_overlay.tscn`
- Key scripts: `scripts/core/{game_manager,turn_manager,event_bus}.gd`, `scripts/systems/*.gd`
- Data JSON: `data/{doctrines,orders,units,weather,logistics}.json`

## 4) Missions for agents
Store each mission in `docs/agents/` as a single self-contained file the agent can follow.

### `docs/agents/agent_base.md` (template)
```
# Mission: <short title>
## Goal
Describe the desired player-facing result.

## Inputs
Links to `project_spec.md`, latest merged PRs, and any data files.

## Acceptance tests (Given/When/Then)
- Given ...
- When ...
- Then ...

## Constraints
- Do not touch assets outside this scope.
- Keep diff < 300 LOC; include unit tests.

## Deliverables
- Feature branch name
- Files to create/change
- PR description (use template)
```

## 5) Testing
- Prefer **gdUnit4**. Where not possible, use lightweight GDScript asserts and headless runs.
- Minimal acceptance tests should run the main scene, press a few buttons, and validate logs/UI state.
- Add a `docs/tests/acceptance_tests.md` and keep it updated.

## 6) CI (lightweight suggestion)
GitHub Actions (suggested):
- **build**: Godot headless export or at least load all scenes without error.
- **test**: run gdUnit4 or scripted test scenes.
- **lint**: optional GDScript formatter/checks.

## 7) Context hygiene
- Maintain `context_snapshot.md` at repo root; update each PR with a short bullet list of changes.
- Keep `CHANGELOG.md` (Keep a Changelog). Tag releases with SemVer on VS milestones.
- Use **ADR**s (`docs/adr/ADR-XXXX.md`) for decisive shifts (e.g., “cards → doctrines”).

## 8) Secrets & data
- No secrets in code or prompts. If needed, mock external calls. Keep repo private.

## 9) Communication style for agents
- Be explicit, cite files and line ranges; prefer small PRs; link to acceptance tests.
- When uncertain, propose 2–3 options with pros/cons, defaulting to the simplest VS-compatible one.

## 10) Roadmap pointers
- VS scope is defined in `project_spec.md` §3 and §6.
- After VS, expand Logistics (pipes/convoys), weather palette, and formations advanced.

---

**Quickstart for a new agent**
1. Read `project_spec.md` fully.
2. Read last 3 merged PRs + `context_snapshot.md`.
3. Open a mission file under `docs/agents/`, commit plan as first PR comment.
4. Implement small, testable steps; keep diffs small.
5. Ensure acceptance tests pass locally and in CI.
