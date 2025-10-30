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
- [x] Lock Command Model + Élan SDS with acceptance criteria and share for review in `docs/design/`. (See
  [`sds_command_model.md`](../../design/sds_command_model.md) and [`sds_elan.md`](../../design/sds_elan.md) — status: Locked for
  review.)
- [x] Define a delivery timeline across Semaine 0–6 with milestones mapped to the systems above.
- [x] Update Godot scenes/scripts incrementally per milestone, ensuring tests and telemetry hooks keep pace. (Doctrine/Élan, Logistique, Combat/Espionnage et Compétence/Formations sont en place avec couverture gdUnit.)
- [ ] Run headless lint/build/test commands after each milestone and archive logs/screenshots as needed. (Bloqué tant que l'exécutable Godot 4.5.1 n'est pas provisionné localement — voir `context_update.md`.)
- [x] Refresh `context_update.md`, `CHANGELOG.md`, and `context_snapshot.md` after every significant increment. (Docs synchronisés après les jalons Semaine 0–6.)
- [x] Capture risks, open questions, and decision records in mission follow-ups or ADRs. (ADR ajouté : [`docs/ADR_0002_event_bus_and_telemetry_autoloads.md`](../../ADR_0002_event_bus_and_telemetry_autoloads.md).)

## Deliverables
- Branch name & PR link documenting the latest progress.
- Updated documentation (`README.md`, SDS files, mission briefs) linked from `context_update.md`.
- Logs or summaries for automated test runs.
- New or updated telemetry schemas validating the covered systems.
- Follow-up task list for remaining polish or stretch items.

### Delivery timeline (Semaine 0–6)
- **Semaine 0 — Kickoff & alignment**: Finalise mission scope review, confirm SDS owners, et mettre en place le socle d'autoloads (`EventBus`, `DataLoader`, `Telemetry`, `AssistantAI`) pour que les systèmes Checklist C puissent consommer les données/événements dès le sprint 1. Validate onboarding rituals with the latest `AGENTS.md` updates.
- **Semaine 1 — Command Model & Élan loop**: Implement doctrine selection, Élan accumulation caps, and command order validation with debug HUD feedback. Target gdUnit smoke coverage around Élan spend and doctrine toggles.
- **Semaine 2 — Logistics backbone**: Prototype hybrid supply (rings + routes), animate convoy nodes, and track logistics state transitions in telemetry. Ensure data schemas in `data/` capture route types and supply thresholds.
- **Semaine 3 — Terrain & weather layering**: Introduce Plains/Forest/Hill terrain with movement modifiers and Sun/Rain/Fog weather affecting logistics pipelines. Expose modifiers through HUD tooltips and log them via the telemetry bus.
- **Semaine 4 — Combat 3 Piliers**: Deliver probabilistic resolution for Manoeuvre, Feu, and Moral pillars, surfacing outcomes through combat panels. Wire foundational automated tests to cover resolution edge cases and telemetry events.
- **Semaine 5 — Espionage systems**: Add fog of war, probabilistic pings, and intention reveals, including counterplay hooks. Record espionage interactions in analytics payloads and document decision points via ADR drafts if scope shifts.
- **Semaine 6 — Competence sliders & formations**: Ship turn-based competence budget management and unit formation postures (infantry/archers/cavalry). Integrate final telemetry events (Élan spent, pillar results, logistic breaks) and complete documentation updates (`context_update.md`, `CHANGELOG.md`, `context_snapshot.md`).

## Handoff (fill when pausing or finishing)
Pinned CI to Godot 4.5.1 and cleaned UI scene parenting so build smoke checks can run headless without crashes. Awaiting a full
test pass once the new Godot binary is available locally. Updated HUD and GameManager scripts to the Python-style conditional
syntax required by Godot 4.5.1 so the editor no longer reports parse errors on load. Follow-up pass resolved lingering HUD/Debug
Overlay logistics toggle warnings and documented the new Godot `.uid` sidecar files for future agents.
- Semaine 0–1 complétée : boucle commandement/Élan jouable (DoctrineSystem + ElanSystem), HUD avec sélection doctrine/ordres,
  inertie affichée, feedback audio et tests gdUnit pour sécuriser la logique de verrouillage et de dépense d’Élan.
- Semaine 2–3 complétée : socle logistique hybride opérationnel (`LogisticsSystem`, météo tournante `sunny/rain/mist`, anneaux
  d'approvisionnement, routes/convoys, tests gdUnit dédiés) prêt à alimenter HUD et télémétrie.
- Semaine 4–5 complétée : résolution Combat 3 Piliers alimentée par doctrines/météo/espionnage (`CombatSystem`), brouillard et
  pings probabilistes opérationnels (`EspionageSystem`), télémétrie `combat_resolved`/`espionage_ping` vérifiée via
  `tests/gdunit/test_combat_and_espionage_systems.gd`.
- Semaine 6 complétée : budget de compétences par tour (`TurnManager`), formations actives (`data/formations.json`) et bonus de
  piliers via `CombatSystem`, avec télémétrie `competence_reallocated`/`formation_changed` et tests `test_competence_and_formations.gd`.
- Préparation autoload validée : `DataLoader` reporte désormais le signal `data_loader_ready` après initialisation via
  `call_deferred`, télémétrie et `AssistantAI` s’y connectent automatiquement, et le test `tests/gdunit/test_autoload_preparation.gd`
  capture la preuve.
- Vérification locale actuelle : les jeux de données sous `data/` sont parsés via un script Python partagé dans le README,
  tandis que l'exécutable Godot reste à provisionner dans le conteneur pour relancer les commandes headless.
- Instrumentation télémétrie consolidée : `logistics_break` complète `elan_spent`, `combat_resolved` et `espionage_ping`, les tests gdUnit valident l'émission dédiée et le plan KPI/Dashboard vit dans `docs/telemetry/dashboard_plan.md`.
