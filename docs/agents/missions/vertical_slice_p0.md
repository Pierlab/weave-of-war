# Mission: Vertical Slice P0 Delivery

## Goal
Deliver the Weave of War vertical slice across the eight foundational systems (Command Model, Élan, Logistics, Combat 3 Pillars, Espionage, Terrain & Weather, Competence Sliders, Unit Formations) with shippable rituals, documentation, and telemetry hooks that let future agents iterate confidently.

## Inputs
- [`docs/project_spec.md`](../project_spec.md)
- Latest [`context_snapshot.md`](../../context_snapshot.md)
- Current notes in [`context_update.md`](../../context_update.md)
- [`CHECKLISTS.md`](../../CHECKLISTS.md) — track completion state for the vertical slice
- Existing scenes and scripts under `scenes/` and `scripts/`

## Acceptance tests
- Vertical slice checklists (A–D) are fully checked in [`CHECKLISTS.md`](../../CHECKLISTS.md) with validation evidence linked from this mission.
- Automated lint/build/test Godot commands succeed on CI and locally (or blockers documented with mitigation).
- `README.md`, `CHANGELOG.md`, `context_update.md`, and `context_snapshot.md` reflect the final vertical slice state.
- SDS deliverables for Command Model and Élan are stored under `docs/design/` with clear owner and review status.

## Constraints
- Scope work to the eight P0 systems listed in the goal; defer stretch goals to follow-up missions.
- Maintain Godot 4.x compatibility and avoid editor-only APIs in headless scripts.
- Ensure all data assets (`data/*.json`) remain human editable and validated by automated tests.
- Update onboarding and mission documentation alongside any behaviour changes.

## Implementation checklist
- [x] Draft SDS outlines for each system (Command Model, Élan, Logistics, Combat 3 Pillars, Espionage, Terrain & Weather, Competence Sliders, Unit Formations) capturing rules, UX, and telemetry needs. See [`docs/design/sds_outlines.md`](../../design/sds_outlines.md).
- [ ] Lock Command Model + Élan SDS with acceptance criteria and share for review in `docs/design/`.
- [ ] Define a delivery timeline across Semaine 0–6 with milestones mapped to the systems above.
- [ ] Update Godot scenes/scripts incrementally per milestone, ensuring tests and telemetry hooks keep pace.
- [ ] Run headless lint/build/test commands after each milestone and archive logs/screenshots as needed.
- [ ] Refresh `context_update.md`, `CHANGELOG.md`, and `context_snapshot.md` after every significant increment.
- [ ] Capture risks, open questions, and decision records in mission follow-ups or ADRs.

## Deliverables
- Branch name & PR link documenting the latest progress.
- Updated documentation (`README.md`, SDS files, mission briefs) linked from `context_update.md`.
- Logs or summaries for automated test runs.
- New or updated telemetry schemas validating the covered systems.
- Follow-up task list for remaining polish or stretch items.

## Handoff (fill when pausing or finishing)
Pinned CI to Godot 4.5.1 and cleaned UI scene parenting so build smoke checks can run headless without crashes. Awaiting a full
test pass once the new Godot binary is available locally.
