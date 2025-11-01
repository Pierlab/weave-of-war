# Mission: Vertical Slice P0 Delivery

## Goal
Deliver the Weave of War vertical slice across the eight foundational systems (Command Model, Élan, Logistics, Combat 3 Pillars, Espionage, Terrain & Weather, Competence Sliders, Unit Formations) with shippable rituals, documentation, and telemetry hooks that let future agents iterate confidently.

## Inputs
- [`docs/project_spec.md`](../project_spec.md)
- Latest [`context_snapshot.md`](../../context_snapshot.md)
- Current notes in [`context_update.md`](../../context_update.md)
- Expanded execution plan in [`CHECKLISTS.md`](../../CHECKLISTS.md)
- Previous milestone snapshot archived at [`docs/agents/archive/CHECKLISTS_2024-vertical_slice_snapshot.md`](../archive/CHECKLISTS_2024-vertical_slice_snapshot.md)
- Existing scenes and scripts under `scenes/` and `scripts/`

## Acceptance tests
- Vertical slice checklist items in [`CHECKLISTS.md`](../../CHECKLISTS.md) are completed with evidence linked from this mission file.
- Automated lint/build/test Godot commands succeed on CI and locally (or blockers documented with mitigation).
- `README.md`, `CHANGELOG.md`, `context_update.md`, and `context_snapshot.md` reflect the final vertical slice state.
- SDS deliverables for Command Model and Élan are stored under `docs/design/` with clear owner and review status.

## Constraints
- Scope work to the eight P0 systems listed in the goal; defer stretch goals to follow-up missions.
- Maintain Godot 4.x compatibility and avoid editor-only APIs in headless scripts.
- Ensure all data assets (`data/*.json`) remain human editable and validated by automated tests.
- Update onboarding and mission documentation alongside any behaviour changes.

## Implementation checklist
(Follow the numbered sequence in [`CHECKLISTS.md`](../../CHECKLISTS.md); each task must be completed in order with evidence linked back here.)
- [ ] Phase 0 — Alignment, data hygiene, and instrumentation foundations.
- [ ] Phase 1 — Command Model & Élan core loop (data contracts, systems, telemetry).
- [ ] Phase 2 — Logistics backbone with terrain & weather integration.
- [ ] Phase 3 — Combat (3 Pillars) resolution pipeline.
- [ ] Phase 4 — Espionage systems and fog of war feedback.
- [ ] Phase 5 — Competence sliders (tactics/strategy/logistics) with inertia.
- [ ] Phase 6 — Unit formations/postures influencing combat outcomes.
- [ ] Phase 7 — Telemetry dashboards and Assistant AI insights.
- [ ] Phase 8 — QA rituals, acceptance coverage, and release documentation.

## Deliverables
- Branch name & PR link documenting the latest progress.
- Updated documentation (`README.md`, SDS files, mission briefs) linked from `context_update.md`.
- Logs or summaries for automated test runs.
- New or updated telemetry schemas validating the covered systems.
- Follow-up task list for remaining polish or stretch items.

### Phase 0 findings
- 2025-11-01 — Re-read project spec, mission brief, and latest context snapshot; scope remains aligned with no new risks beyond the known local Godot binary provisioning blocker (tracked in `context_update.md`).
- 2025-11-02 — Audited `data/*.json` catalogues against the locked SDS packages; remaining gaps:
  - `data/doctrines.json` only lists `force` and `ruse`. The Command Model SDS requires the full set (Force/Ruse/Patience/Vitesse/Équilibre) plus CP cap deltas, inertia multipliers, and swap token budgets for doctrine gating.
  - `data/orders.json` lacks explicit `cp_cost` values, `base_delay`/inertia multipliers, targeting scopes, and posture requirements referenced in the Command Model SDS. Assistant AI intent metadata also needs interpreter hints for queue telemetry.
  - `data/logistics.json` still summarises logistics tiers without depot nodes, graph connectivity, convoy capacity, or hazard profiles expected by the Logistics SDS outline for map-driven validation.
  - `data/units.json` omits readiness penalties, surge/edge token hooks, and morale thresholds that combat and Élan systems depend on for pillar/decay calculations in the SDS specs.
  - `data/formations.json` is missing eligible unit class lists, Élan/posture switch costs, and recovery timings required to align with the formations + competence interplay described in the SDS outlines.
  - `data/weather.json` does not yet expose visibility modifiers, forecast sequencing metadata, or telemetry IDs needed for `weather_changed` payloads in the Logistics/Terrain SDS outline.
  - No competence slider dataset exists under `data/`; create `competence_sliders.json` (or equivalent) capturing slider caps, inertia limits, unlock effects, and telemetry keys demanded by the competence slider SDS outline.
- 2025-11-03 — Consolidated DataLoader hardening: `DataLoaderAutoload.validate_collection()` now rejects missing keys, enum drift, and numeric/type mismatches while `load_all()` surfaces schema issues. Added gdUnit coverage (`test_data_loader_validation_reports_missing_keys`, `test_data_loader_validation_accepts_valid_payload`) to capture regression evidence for Checklist Phase 0 / item 3.

### Delivery timeline (Semaine 0–6)
- **Semaine 0 — Kickoff & alignment**: Finalise mission scope review, confirm SDS owners, et mettre en place le socle d'autoloads (`EventBus`, `DataLoader`, `Telemetry`, `AssistantAI`) pour que les systèmes Checklist C puissent consommer les données/événements dès le sprint 1. Validate onboarding rituals with the latest `AGENTS.md` updates.
- **Semaine 1 — Command Model & Élan loop**: Implement doctrine selection, Élan accumulation caps, and command order validation with debug HUD feedback. Target gdUnit smoke coverage around Élan spend and doctrine toggles.
- **Semaine 2 — Logistics backbone**: Prototype hybrid supply (rings + routes), animate convoy nodes, and track logistics state transitions in telemetry. Ensure data schemas in `data/` capture route types and supply thresholds.
- **Semaine 3 — Terrain & weather layering**: Introduce Plains/Forest/Hill terrain with movement modifiers and Sun/Rain/Fog weather affecting logistics pipelines. Expose modifiers through HUD tooltips and log them via the telemetry bus.
- **Semaine 4 — Combat 3 Piliers**: Deliver probabilistic resolution for Manoeuvre, Feu, and Moral pillars, surfacing outcomes through combat panels. Wire foundational automated tests to cover resolution edge cases and telemetry events.
- **Semaine 5 — Espionage systems**: Add fog of war, probabilistic pings, and intention reveals, including counterplay hooks. Record espionage interactions in analytics payloads and document decision points via ADR drafts if scope shifts.
- **Semaine 6 — Competence sliders & formations**: Ship turn-based competence budget management and unit formation postures (infantry/archers/cavalry). Integrate final telemetry events (Élan spent, pillar results, logistic breaks) and complete documentation updates (`context_update.md`, `CHANGELOG.md`, `context_snapshot.md`).

## Handoff (fill when pausing or finishing)
Pinned CI to Godot 4.5.1 and cleaned UI scene parenting so build smoke checks can run headless without crashes. Awaiting a full test pass once the new Godot binary is available locally. Updated HUD and GameManager scripts to the Python-style conditional syntax required by Godot 4.5.1 so the editor no longer reports parse errors on load. Follow-up pass resolved lingering HUD/Debug Overlay logistics toggle warnings and documented the new Godot `.uid` sidecar files for future agents.
- Semaine 0–1 complétée : boucle commandement/Élan jouable (DoctrineSystem + ElanSystem), HUD avec sélection doctrine/ordres, inertie affichée, feedback audio et tests gdUnit pour sécuriser la logique de verrouillage et de dépense d’Élan.
- Semaine 2–3 complétée : socle logistique hybride opérationnel (`LogisticsSystem`, météo tournante `sunny/rain/mist`, anneaux d'approvisionnement, routes/convoys, tests gdUnit dédiés) prêt à alimenter HUD et télémétrie.
- Semaine 4–5 complétée : résolution Combat 3 Piliers alimentée par doctrines/météo/espionnage (`CombatSystem`), brouillard et pings probabilistes opérationnels (`EspionageSystem`), télémétrie `combat_resolved`/`espionage_ping` vérifiée via `tests/gdunit/test_combat_and_espionage_systems.gd`.
- Semaine 6 complétée : budget de compétences par tour (`TurnManager`), formations actives (`data/formations.json`) et bonus de piliers via `CombatSystem`, avec télémétrie `competence_reallocated`/`formation_changed` et tests `test_competence_and_formations.gd`.
- Préparation autoload validée : `DataLoader` reporte désormais le signal `data_loader_ready` après initialisation via `call_deferred`, télémétrie et `AssistantAI` s’y connectent automatiquement, et le test `tests/gdunit/test_autoload_preparation.gd` capture la preuve.
- Vérification locale actuelle : les jeux de données sous `data/` sont parsés via un script Python partagé dans le README, tandis que l'exécutable Godot reste à provisionner dans le conteneur pour relancer les commandes headless.
- Instrumentation télémétrie consolidée : `logistics_break` complète `elan_spent`, `combat_resolved` et `espionage_ping`, les tests gdUnit valident l'émission dédiée et le plan KPI/Dashboard vit dans `docs/telemetry/dashboard_plan.md`.
- Éditeur stabilisé : l'ordre `class_name` → `extends` est désormais appliqué partout pour empêcher les erreurs de parsing "Unexpected \"class_name\" here" signalées par les versions plus anciennes de l'éditeur.
- Les autoloads suivent désormais le suffixe `Autoload` (EventBus/DataLoader/Telemetry/AssistantAI) avec des hints typés actualisés, supprimant les avertissements Godot 4.5 traités en erreurs et clarifiant la documentation (README + errors.log) sur la commande PowerShell utilisée pour lancer le projet.
- Rafraîchi le cache `.godot/global_script_class_cache.cfg` pour refléter ces nouveaux `class_name` et lever les erreurs de parsing "Could not find type ...Autoload" lors du démarrage.
- Corrigé l'erreur de compilation `Variant` dans `ElanSystem` et amorcé le générateur audio HUD pour éliminer les logs "Player is inactive" lors des interactions doctrines/ordres.
- Dégagé la boucle audio HUD en stoppant et purgeant le générateur avant relance, supprimant les erreurs `AudioStreamGeneratorPlayback.clear_buffer` répétées et la fuite d'instances `AudioStreamGeneratorPlayback` constatée à la fermeture du jeu.
- Consolidé cette boucle audio en vérifiant que le `AudioStreamGeneratorPlayback` est inactif avant chaque purge afin d'éliminer l'assertion `Condition "active" is true` apparue lors des changements de doctrine et des avances de tour.
