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
- [x] Phase 1 — Command Model & Élan core loop (data contracts, systems, telemetry). *(2025-11-15 — Acceptation manuelle documentée dans `docs/tests/acceptance_tests.md` pour valider doctrines, ordres et télémétrie.)*
- [~] Phase 2 — Logistics backbone with terrain & weather integration. *(2025-11-22 — Les pénalités météo alimentent désormais le flux logistique et le risque d'interception; restent à brancher la télémétrie météo et la couverture de tests additionnelle.)*
- [~] Phase 3 — Combat (3 Pillars) resolution pipeline. *(2025-11-30 — CombatSystem instancié côté GameManager et connecté aux flux `order_*`/`logistics_update`.)*
- [x] Phase 4 — Espionage systems and fog of war feedback. *(2025-12-10 — Recon flows added: `recon_probe`/`deep_cover` orders consume competence, auto-trigger `espionage_ping`, and HUD/tooling surface the validation.)*
- [x] Phase 5 — Competence sliders (tactics/strategy/logistics) with inertia. *(2025-12-14 — `TurnManager` consomme désormais
  `data/competence_sliders.json`, applique des caps de réallocation/inertie par catégorie, expose l'état des modificateurs et la
  télémétrie `competence_reallocated` publie les deltas restants pour la HUD et l'Assistant AI. 2025-12-15 — HUD « Compétence »
  livrée avec sliders interactifs, raccourcis clavier/manette et feedback inline.)*
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
- 2025-11-27 — Détaché les `class_name` (`EventBus`, `DataLoader`, `Telemetry`, `AssistantAI`) des singletons `*Autoload`, ajouté les hints typés manquants dans `DataLoader` et `LogisticsSystem`, et mis à jour README/CHANGELOG/tests pour refléter le nouveau contrat (type hints via les classes, accès runtime via les autoloads).
- 2025-11-26 — Neutralisé l'avertissement `class_name_hides_autoload` en ajoutant `@warning_ignore` sur les autoloads et en renforçant les hints typés (`DataLoader`, systèmes logistique/terrain/météo, HUD) avec conversions `str()`/`fmod()` pour empêcher Godot 4.5 de promouvoir les inférences `Variant` et l'opérateur `%` float en erreurs bloquantes.
- 2025-11-01 — Re-read project spec, mission brief, and latest context snapshot; scope remains aligned with no new risks beyond the known local Godot binary provisioning blocker (tracked in `context_update.md`).
- 2025-11-02 — Audited `data/*.json` catalogues against the locked SDS packages; remaining gaps:
  - `data/doctrines.json` only lists `force` and `ruse`. The Command Model SDS requires the full set (Force/Ruse/Patience/Vitesse/Équilibre) plus CP cap deltas, inertia multipliers, and swap token budgets for doctrine gating.
  - `data/orders.json` lacks explicit `cp_cost` values, `base_delay`/inertia multipliers, targeting scopes, and posture requirements referenced in the Command Model SDS. Assistant AI intent metadata also needs interpreter hints for queue telemetry. *(2025-11-07 — Résolu via l'enrichissement complet du dataset et la mise à jour de la validation.)*
  - `data/logistics.json` still summarises logistics tiers without depot nodes, graph connectivity, convoy capacity, or hazard profiles expected by the Logistics SDS outline for map-driven validation.
  - `data/units.json` omits readiness penalties, surge/edge token hooks, and morale thresholds that combat and Élan systems depend on for pillar/decay calculations in the SDS specs.
  - `data/formations.json` is missing eligible unit class lists, Élan/posture switch costs, and recovery timings required to align with the formations + competence interplay described in the SDS outlines.
  - `data/weather.json` does not yet expose visibility modifiers, forecast sequencing metadata, or telemetry IDs needed for `weather_changed` payloads in the Logistics/Terrain SDS outline.
  - No competence slider dataset exists under `data/`; create `competence_sliders.json` (or equivalent) capturing slider caps, inertia limits, unlock effects, and telemetry keys demanded by the competence slider SDS outline.
- 2025-11-03 — Consolidated DataLoader hardening: `DataLoaderAutoload.validate_collection()` now rejects missing keys, enum drift, and numeric/type mismatches while `load_all()` surfaces schema issues. Added gdUnit coverage (`test_data_loader_validation_reports_missing_keys`, `test_data_loader_validation_accepts_valid_payload`) to capture regression evidence for Checklist Phase 0 / item 3.
- 2025-11-04 — Confirmed autoload readiness: renamed the four singletons in `project.godot` to their `*Autoload` identifiers, extended `tests/gdunit/test_autoload_preparation.gd` to assert configuration + readiness telemetry, and captured startup instrumentation in [`docs/logs/autoload_readiness_2025-11-04.log`](../../docs/logs/autoload_readiness_2025-11-04.log).
- 2025-11-05 — Stabilised HUD procedural audio: `_play_feedback()` now queues tone requests, defers buffer clears until playback goes inactive, and archives a repeated doctrine/order swap run in [`docs/logs/hud_audio_feedback_2025-11-05.log`](../../docs/logs/hud_audio_feedback_2025-11-05.log).

### Phase 1 progress
- 2025-12-07 — HUD feedback audio amorce maintenant son `AudioStreamPlayer` avant de récupérer le playback du générateur,
  supprimant l'erreur de console "Player is inactive" observée lors des premières interactions doctrine/ordre, notamment en
  environnement headless.
- 2025-11-06 — Locked the doctrine dataset to the SDS stances with command profile metadata and aligned logistics synergies (`data/doctrines.json`, `data/logistics.json`).
- 2025-11-07 — Élargi `data/orders.json` avec les coûts CP, délais de base, exigences doctrinales, ciblage/postures et métadonnées Assistant AI, puis renforcé `DataLoaderAutoload` + `tests/gdunit/test_data_integrity.gd` et documenté le nouveau contrat dans README/CHANGELOG.
- 2025-11-08 — Documenté dans le README la copie HUD (doctrine/order), les messages de validation, les couleurs de feedback et les bips associés, avec rappel des considérations accessibilité pour la boucle Commandement & Élan.
- 2025-11-09 — `GameManager` retarde désormais l'initialisation de `DoctrineSystem`/`ElanSystem` jusqu'au signal `data_loader_ready`, journalise le handshake (comptes des collections) et ne lance le tour 1 qu'une fois les systèmes configurés.
- 2025-11-10 — Bouclé l'item "Enforce command rules" : les multipliers SDS (`command_profile` + `orders[].inertia_profile`) allongent ou réduisent l'inertie appliquée par les ordres, l'Élan applique désormais un bonus de cap par doctrine et une décroissance automatique après un tour complet au plafond, et la HUD expose une ligne dédiée "Inertie" + des infobulles détaillant cap/decay. Capture HUD à prendre lors du prochain run Godot local (bloqué en environnement headless actuel).
- 2025-11-11 — Connecté la HUD au bus : les sélecteurs doctrine/ordre émettent désormais `doctrine_change_requested` / `order_execution_requested`, la doctrine active est restaurée si l'inertie bloque un swap, et les tooltips du bouton d'exécution détaillent l'Élan manquant pour fournir la validation directement dans l'interface.
- 2025-11-12 — `AssistantAIAutoload` enregistre les paquets d'ordres émis via `order_issued`, publie les interprétations enrichies, et la debug overlay affiche désormais un log déroulant (nom, cible, intention, confiance) pour prouver la propagation de l'ordre côté assistant.
- 2025-11-13 — Ajouté des tests gdUnit (`tests/gdunit/test_command_elan_loop.gd`) vérifiant le refus/succès de changement de doctrine, les validations de dépense/gain d'Élan et l'émission de paquets `assistant_order_packet`. La commande `godot --headless --path . --script res://scripts/ci/gdunit_runner.gd` reste à lancer quand le binaire Godot sera provisionné; consigner le log attendu sous `docs/logs/gdunit_command_loop_2025-11-13.log`.
- 2025-11-14 — Instrumentation complète de la boucle Commandement & Élan : `EventBusAutoload` expose désormais les signaux `order_rejected` et `elan_gained`, `TelemetryAutoload` sérialise des payloads normalisés (`doctrine_selected`, `order_issued`, `order_rejected`, `elan_spent`, `elan_gained`), et `tests/gdunit/test_command_elan_loop.gd` couvre les nouveaux cas de télémétrie (rejets doctrine/Élan, raisons de dépense, gains horodatés). La matrice KPI `docs/telemetry/dashboard_plan.md`/README reflète ces événements.
- 2025-11-15 — Mise à jour d'`AT-07` dans `docs/tests/acceptance_tests.md` pour lister les étapes de swap doctrine, d'émission d'ordre et de revue du buffer `TelemetryAutoload`, clôturant l'action Phase 1 item 15.

### Phase 2 progress
- 2025-11-16 — `GameManager` instancie `LogisticsSystem`, partage les autoloads `EventBus`/`DataLoader`, et `tests/gdunit/test_game_manager_logistics_bootstrap.gd` capture la propagation des signaux de tour/toggle pour verrouiller l'intégration.
- 2025-11-17 — `data/logistics.json` décrit désormais les centres d'approvisionnement et routes/convoys pour chaque scénario, `LogisticsSystem` les charge dynamiquement, et un test gdUnit (`tests/gdunit/test_logistics_data_connectivity.gd`) valide que chaque graphe reste connexe.
- 2025-11-18 — `LogisticsOverlay` dessine des anneaux d'approvisionnement pulsés et anime les convois selon l'état (`active`, `delivered`, `intercepted`), avec des marqueurs rouges pour les interceptions; capture GIF à réaliser lors du prochain run Godot local car l'environnement actuel est headless.
- 2025-11-19 — `LogisticsSystem` enrichit `logistics_update` avec `reachable_tiles`, `supply_deficits` et `convoy_statuses`. Exemple capturé depuis le debug overlay :
  ```json
  {
    "turn": 3,
    "reachable_tiles": ["1,1", "2,1", "3,1"],
    "supply_deficits": [
      { "tile_id": "4,2", "severity": "warning", "logistics_flow": 0.62 },
      { "tile_id": "5,3", "severity": "critical", "logistics_flow": 0.0 }
    ],
    "convoy_statuses": [
      { "route_id": "forward_road", "last_event": "delivered", "eta_turns": 0.0 },
      { "route_id": "harbor_convoy", "last_event": "intercepted", "eta_turns": 1.0 }
    ]
  }
  ```
- 2025-11-20 — Le dataset [`data/terrain.json`](../../data/terrain.json) alimente désormais les hexagones : chaque tuile affiche le nom du biome et son coût de mouvement, les payloads `logistics_update` exposent `terrain_name` et le HUD/debug overlay proposent un tooltip synthétique listant Plaines/Forêts/Collines et leurs comptes.
- 2025-11-21 — `WeatherSystem` fait tourner `sunny/rain/mist` via un RNG à seed, diffuse `weather_changed` avec modificateurs et
  tours restants, `LogisticsSystem` se contente désormais de consommer ces événements (désactivation de sa rotation interne) et
  la HUD affiche une icône météo colorée avec tooltip détaillé; `tests/gdunit/test_weather_system.gd` verrouille l'ordre et les
  durées générées.
- 2025-11-22 — `LogisticsSystem` applique les modificateurs météo/scénario au débit d'approvisionnement, calcule un `intercept_risk` détaillé par route, et expose un bloc `weather_adjustments` dans `logistics_update` pour documenter les pénalités et effets QA.
- 2025-11-23 — `TelemetryAutoload` enregistre désormais chaque `weather_changed` avec modificateurs (mouvement, flux logistique, bruit d'intel, bonus d'Élan, durée restante) et une gdUnit vérifie la capture initiale, tandis que le plan KPI documente les champs pour les dashboards météo/logistique.
- 2025-11-24 — Étendu `tests/gdunit/test_logistics_system.gd` avec des cas ciblant la réduction de portées sous météo "storm", l'émission unique des événements `logistics_break` lors d'interceptions successives et la cadence de rotation météo pilotée par la logistique; checklist item 24 clôturé avec notes dans `CHECKLISTS.md` et README/CHANGELOG mis à jour.
- 2025-11-25 — Rafraîchi `docs/tests/acceptance_tests.md` (AT-08 à AT-10) pour couvrir la bascule HUD/debug du overlay logistique, la mise à jour des tooltips terrain et les impacts météo sur la portée/logistique; checklist item 25 validé.
- 2025-11-28 — Corrigé les erreurs Godot 4.6 liées aux inférences `Variant` en typant `LogisticsSystem` (`route_id`) et la mise à jour de cap d'Élan, et dupliqué les définitions `TerrainData` avant merge pour que la carte puisse injecter `data/terrain.json` sans heurter les dictionnaires read-only.

### Phase 3 progress
- 2025-12-07 — `CombatSystem` accepte désormais le dictionnaire `{"attacker", "defender"}` renvoyé par `_build_unit_states`,
  ce qui rétablit la compilation Godot et l'initialisation du `GameManager` sans erreurs après le chargement des scripts.
- 2025-12-06 — Neutralisé les erreurs `Variant` promues en erreurs bloquantes par Godot 4.6 en typant les variables
  locales du `CombatSystem` et du `HUDManager`, ce qui permet à `GameManager` d'instancier à nouveau le pipeline combat/logistique
  sans échec de compilation.
- 2025-11-30 — `GameManager` instancie désormais `CombatSystem`, branche les signaux `order_execution_requested`/`order_issued`/`logistics_update`, et chaque payload `combat_resolved` inclut un bloc `logistics` (flow, niveau, sévérité, tour) pour contextualiser les victoires de piliers côté HUD et télémétrie.
- 2025-12-01 — Les formules des piliers Position/Impulsion/Information appliquent désormais le focus doctrinal, la sévérité logistique (flow + movement cost), les bonus de formation/compétence, ainsi que les multiplicateurs météo/terrain et renseignement (`intel_confidence`, `signal_strength`, `counter_intel`). Ce fichier conserve l'annotation de référence :
  - **Position** = (profil unités + doctrine + formation + ordre + bonus attaque) × terrain × météo × focus doctrinal × facteur logistique × pénalité mouvement (selon `movement_cost`) × ajustement sévérité (warning=×0,9, critical=×0,75) + 5% de bonus espionnage.
  - **Impulsion** = (profil unités + doctrine + formation + ordre + bonus attaque) × terrain × météo × focus doctrinal × facteur logistique × `[1 + 0,5*(intel_confidence-0,5) + 0,35*espionage_bonus + 0,4*(logistics_factor-1)]`.
  - **Information** = (profil unités + doctrine + formation + ordre + bonus attaque) × terrain × météo × focus doctrinal × facteur logistique × `[0,6 + intel_confidence + espionage_bonus + signal_strength + 0,4*(detection-counter_intel)]`.
  - Défenseurs : posture + bonus défense appliqués avant multiplications; pénalités logistiques warning/critical (×0,95/×0,8) et contrepoids d'intel `[0,9 + counter_intel + profil_counter - 0,4*espionage_bonus]` sur Information, `[1 + 0,6*posture_impulse + 0,2*counter_intel - 0,2*espionage_bonus]` sur Impulsion, `[1 + 0,5*posture_position] × clamp(1 - 0,3*(intel_confidence-0,5))` sur Position.
- 2025-12-02 — Panneau HUD "Dernier engagement" connecté à `combat_resolved` : jauges par pilier, résumé logistique (flow, sévérité, coût de mouvement, hex cible) et rappel des dépenses/gains d'Élan. Capture écran à prendre lors d'un run Godot graphique.
- 2025-12-03 — `combat_resolved` inclut désormais un résumé des piliers (totaux, marge normalisée, piliers décisifs) et un état
  par unité (formation, pertes estimées, remarques supply). `TelemetryAutoload` sérialise ces champs pour les dashboards et un
  test gdUnit vérifie la présence des blocs `pillar_summary`/`units`.
- 2025-12-04 — Batterie gdUnit `tests/gdunit/test_combat_resolution.gd` couvrant la reproductibilité contrôlée par seed, les cas
  contestés (1 pilier chacun + statu quo) et l'impact des déficits logistiques critiques sur les pertes/cas. Capture des sorties
  à consigner lors du prochain run Godot headless.
- 2025-12-05 — Documenté le déclenchement d'engagements et la lecture du panneau "Dernier engagement" : README détaille le flux
  HUD → CombatSystem → Telemetry, cette note rappelle l'inspection via Remote Debugger et référence l'item 31 de la checklist.

### Phase 4 progress
- 2025-12-13 — Ajouté des régressions gdUnit (`test_combat_and_espionage_systems.gd`) couvrant les snapshots de brouillard, l'échantillonnage probabiliste des pings et la décroissance du contre-espionnage. Capture `godot --headless` à consigner dès que le binaire sera provisionné dans le conteneur.
- 2025-12-12 — `EspionageSystem` émet désormais `intel_intent_revealed` lorsqu'un ping confirme une intention ; `TelemetryAutoload` normalise les payloads, expose `get_history` pour analyser la timeline, et HUD/Debug overlay consignent les révélations avec un feedback audio dédié.
- 2025-12-08 — `GameManager` instancie désormais `EspionageSystem`, hydrate le brouillard depuis `data/terrain.json`, et un test
  gdUnit (`test_game_manager_logistics_bootstrap.gd`) vérifie que les tours diffusés par `EventBus` synchronisent les pings
  `espionage_ping` avec l'état logistique.
- 2025-12-09 — Les tuiles de la carte appliquent maintenant un overlay de brouillard animé par les événements `fog_of_war_updated`
  : visibilité faible assombrit l'hex, masque les infos terrain/tooltip et ne laisse apparaître que les coordonnées, tandis que
  les tuiles ravitaillées conservent leur lisibilité complète.
- 2025-12-10 — *Recon Probe* et *Deep Cover* vivent dans `data/orders.json`, affichent leurs coûts de compétence/Élan dans la HUD,
  bloquent le bouton `Exécuter` tant que le budget requis n'est pas disponible, et déclenchent automatiquement un `espionage_ping`
  ciblant la tuile la plus opaque avec un bonus de détection proportionnel à la compétence dépensée.
- 2025-12-11 — La HUD accueille un panneau "Renseignements" (résumé coloré, probabilité vs jet) et l'overlay debug une timeline
  détaillée; `EspionageSystem` enrichit les payloads `espionage_ping` avec roll, bonus de détection, deltas de visibilité et budget
  de compétence restant pour suivre la qualité des pings.

### Phase 5 progress
- 2025-12-19 — Documented the competence loop end-to-end: README now hosts a "Competence slider usage guide" walkthrough covering selection, validation, telemetry checks, and downstream combat/logistics/assistant reactions, while `docs/tests/acceptance_tests.md` gains AT-16 to mirror the documented steps for manual QA.
- 2025-12-18 — Automated competence slider behaviour via gdUnit tests covering EventBus allocation requests: valid reallocations emit `competence_reallocated` payloads while delta/inertia violations surface `competence_allocation_failed` with detailed reasons.
- 2025-12-17 — `TurnManager` enrichit `competence_reallocated` avec un `turn_id` unique et des instantanés `before`/`after` (allocations, budget restant, inertie, modificateurs). `TelemetryAutoload` sérialise ces champs pour que HUD, tests et dashboards comparent les deltas sans reconstruire l'historique, clôturant la checklist item 41.
- 2025-12-16 — Les allocations de compétence alimentent désormais tout le pipeline : le multiplicateur d'Impulsion du `CombatSystem` applique le ratio Tactique, `AssistantAIAutoload` ajuste ses prévisions (`competence_alignment`, snapshot allocations/ratios) et `LogisticsSystem` diffuse un `competence_multiplier` qui module le flux. Docs, changelog et tests gdUnit (logistique, assistant, combat) verrouillent cette propagation.
- 2025-12-15 — HUD « Compétence » disponible : sliders dynamiques pour Tactique/Stratégie/Logistique, requêtes `EventBus` (`competence_allocation_requested`) et retours d'échec (`competence_allocation_failed`), feedback inline (budget, inertie, delta max) et raccourcis `[1]/[2]/[3]` + d-pad/`A`/`D` pour piloter les allocations sans souris.
- 2025-12-14 — `TurnManager` charge désormais [`data/competence_sliders.json`](../../data/competence_sliders.json), applique des caps
  de réallocation par tour et des verrous d'inertie par catégorie, archive les pénalités logistiques dans les modificateurs et
  publie l'état complet (`allocations`, `inertia`, `modifiers`) dans chaque événement `competence_reallocated`. Les tests
  `tests/gdunit/test_competence_and_formations.gd` couvrent les refus pour dépassement de delta et l'inertie multi-tours, tandis
  que la documentation (README, CHANGELOG, checklist) reflète les nouveaux contrats.

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
