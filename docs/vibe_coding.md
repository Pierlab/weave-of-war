# Weave of War — Vibe Coding Playbook

> Purpose: make the project comfortable for coding agents by combining lightweight rituals, living documentation, and detailed checklists that keep large features safe.

## 1. Core principles
- **Clarity first** – every task starts with a shared understanding of the goal anchored in [`docs/project_spec.md`](project_spec.md).
- **Iterative flow** – ship in small, verifiable steps, even when a feature spans multiple sessions.
- **Checklist discipline** – before touching code on a sizeable effort, co-design a granular checklist with the agent. Each checklist item should be testable and have a single owner.
- **Documentation is part of the work** – when a change lands, update the references that help the next agent (README, specs, tests, mission files).

## 2. Standard vibe-coding loop
1. **Align**
   - Review the active mission (`docs/agents/<mission>.md`) and confirm context from the last merged PR.
   - Extract acceptance criteria and risks; if anything is unclear, pause and clarify before writing code.
2. **Plan with a checklist**
   - Draft a checklist covering analysis, implementation, tests, and documentation tasks.
   - Include validation for edge cases and telemetry/log updates when relevant.
   - Store the checklist alongside the mission or in the PR body; keep it visible to everyone.
3. **Code in vibes**
   - Implement one checklist item at a time.
   - After finishing an item, run its associated tests, update docs, and tick it off with a short note.
   - If scope changes, revise the checklist before proceeding.
4. **Validate**
   - Run acceptance tests from [`docs/tests/acceptance_tests.md`](tests/acceptance_tests.md) plus any feature-specific checks.
   - Capture logs or screenshots when useful for reviewers.
5. **Document & share**
   - Summarise the work in the PR description using the template below.
   - Mention any follow-up items discovered while coding.

## 3. Checklist design guidelines
- **Granularity** – steps must be small enough to complete within one agent iteration (think "create logistics overlay toggle" rather than "implement logistics").
- **Traceability** – link each item to files, scenes, or systems (e.g., `scripts/core/game_manager.gd`, `scenes/ui/hud.tscn`).
- **Validation** – append the validation command or expected observation ("Run `godot --headless --run-tests`", "Verify console shows 'Turn X started'").
- **Lifecycle** – keep historical checklists in the PR conversation so future agents can learn from them.

### Example checklist block
```
- [ ] Analyse event flow for Next Turn button (`scripts/ui/hud_manager.gd`).
- [ ] Wire HUD button to EventBus (`scripts/core/event_bus.gd`) and log the action.
- [ ] Update acceptance tests to mention Next Turn behaviour (`docs/tests/acceptance_tests.md`).
- [ ] Run scene in editor and capture console log.
```

## 4. Branching, commits, and PRs
- Branch naming: `feature/<scope>`, `fix/<scope>`, `chore/<scope>`.
- Commit messages follow Conventional Commits (e.g., `feat: add logistics overlay toggle`).
- Never push directly to `main`; every change flows through a PR.
- Keep diffs reviewable (~300 LOC). Split work when the checklist grows too large for one PR.
- Use this PR template:
  ```
  ## What
  ## Why (player impact)
  ## How (key files & systems)
  ## Tests (commands + expected output)
  ## Documentation updates
  ## Risks / Rollback
  ```

## 5. Mission files (`docs/agents/`)
- Each initiative gets a mission file derived from [`docs/agents/agent_base.md`](agents/agent_base.md).
- Missions must include: goal, inputs, acceptance tests, constraints, deliverables, and the authoritative checklist.
- Update the mission file whenever the plan shifts; unchecked items should explain blockers.

## 6. Documentation & knowledge hygiene
- Update `README.md` when onboarding steps or acceptance expectations change.
- Reflect system updates in `docs/project_spec.md` or add an ADR if the architecture evolves.
- Keep `docs/tests/acceptance_tests.md` aligned with reality after every functional change.
- When new terminology or workflows appear, document them immediately to preserve shared context.

## 7. Testing expectations
- Minimum: run the acceptance flow described in `docs/tests/acceptance_tests.md` before requesting review.
- Prefer automated checks (gdUnit4, headless scripts) when available; document any manual steps.
- If a test is flaky or skipped, log it in the PR with rationale and a follow-up checklist item.

## 8. Communication style for agents
- Cite files and line ranges when explaining changes.
- Surface open questions early and propose clear options with trade-offs.
- When blocked, record the state, update the checklist, and hand off with actionable next steps.

Following this playbook keeps the Weave of War project calm, transparent, and ready for larger systems work without losing our creative vibe.
