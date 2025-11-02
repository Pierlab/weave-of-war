# Context Update — Current Branch

## Summary
- 2026-01-03 — Ajouté un panneau "Télémetrie" filtrable dans l'overlay debug, alimenté par le nouveau signal `Telemetry.event_logged`, avec statut de persistance, rafraîchissement manuel et copie du chemin de session pour faciliter les playtests checklist 53. Les commandes Godot headless restent bloquées faute de binaire provisionné dans ce conteneur.
- 2026-01-02 — Ajouté des traces de raisonnement Assistant AI couvrant les ordres, les recommandations espionnage et les alertes logistiques : la debug overlay expose les trois flux, un échantillon JSONL (`docs/logs/assistant_ai_reasoning_sample_2026-01-02.jsonl`) sert de référence analytics, et les docs/checklists/mission ont été mis à jour. Les commandes Godot headless restent bloquées faute de binaire provisionné dans ce conteneur.
- 2025-12-31 — Persisté les buffers `TelemetryAutoload` sur disque via des fichiers JSONL `user://telemetry_sessions/telemetry_session_<horodatage>.jsonl`, ajouté un test gdUnit couvrant la persistance, et documenté le rituel dans le README, la checklist et le mission brief (checklist item 51 bouclé). Godot headless reste bloqué faute de binaire provisionné localement.
- 2025-12-30 — Revu l'intégralité des schémas `TelemetryAutoload`, confirmé la duplication profonde des payloads et mis à jour
  `docs/telemetry/dashboard_plan.md` avec une matrice de champs (readiness, commandement, logistique/météo, combat/formation,
  compétence, renseignement) plus un plan KPI/dashboards Phase 7. CHECKLISTS item 50 et mission brief Phase 7 reflètent
  l'avancement.
- 2025-12-29 — Corrigé les arrêts de chargement Godot : cast explicite des dictionnaires dans `AssistantAI`, `Map`,
  `FormationSystem` et `HUDManager`, remplacement des overrides `theme_override_constants` par
  `add_theme_constant_override`, ce qui restaure l'affichage de la carte et des panneaux HUD sans warnings-as-errors.
- 2025-12-28 — Restauré le chargement des scripts Assistant AI / carte / HUD en ajoutant des hints explicites sur les
  dictionnaires (`Variant` → `Dictionary`), supprimant les erreurs Godot "Variant inferred" et les types manquants. README et
  CHANGELOG documentent le pattern.
- 2025-12-27 — Rebuilt the HUD left rail into a tabbed container (Commandement/Renseignements/Compétence/Formations/Dernier engagement) with scrollable panels for dense sections and bumped the default window to 1600×900 so the tactical map has more breathing room. README and CHANGELOG document the UX change; Godot headless commands remain blocked until the executable is provisioned in this container.
- 2025-12-26 — Added a dataset-backed gdUnit regression for formation swaps (`test_formation_system_dataset_swap_consumes_elan_and_modifies_pillars`) validating Élan spend, inertia locks, and pillar deltas to close checklist item 49. README, CHANGELOG, mission brief, and checklist now reference the coverage, while Godot headless commands remain blocked until the executable is provisioned in the container.
- 2025-12-24 — Relié la télémétrie de formation aux résolutions combat : `CombatSystem` réémet désormais `formation_changed`
  pour chaque unité avec l'engagement, l'ordre, le résumé de piliers et le `unit_result`, tandis que `FormationSystem`
  conserve les verrous d'inertie et stocke le contexte dans `formation_status_updated`. README, CHANGELOG, checklist et mission
  brief détaillent l'item 48, un nouveau test gdUnit verrouille le flux, et les commandes Godot headless restent bloquées tant
  que l'exécutable n'est pas provisionné dans le conteneur.
- 2025-12-23 — Ajouté un `FormationOverlay` à la carte tactique : les unités affichent désormais des badges de posture colorés
  (initiales, anneau d'inertie, surbrillance lors d'un swap) synchronisés avec `formation_status_updated`. README, CHANGELOG,
  AT-14 et le mission brief détaillent la nouvelle visibilité, un test gdUnit vérifie les abréviations/couleurs, et la carte se
  synchronise via `Map.set_data_sources`. Les commandes Godot headless restent en attente faute de binaire provisionné dans le
  conteneur.
- 2025-12-22 — Intégré les postures de formation dans la résolution combat : `CombatSystem` ajoute désormais les bonus/malus de
  formation et applique un multiplicateur moyen par pilier avant les facteurs terrain/météo/logistique, ce qui rend visibles les
  échanges Position/Impulsion/Information lors d'un swap. Un test gdUnit compare "Advance Column" vs "Shield Wall" et confirme
  les deltas, tandis que checklist/mission/README/doc tests reflètent l'achèvement de l'item 46.
- 2025-12-21 — Ajouté le panneau HUD « Formations » avec menus déroulants par unité, validation des coûts d'Élan et des verrous
  d'inertie côté `FormationSystem`. Un nouveau signal `formation_status_updated` synchronise l'état avec la HUD/tests, un panel
  Godot dédié décrit chaque posture (coût, inertie, description), et les tentatives refusées surfacent les raisons (`Élan` ou
  inertie) directement dans l'interface. README/CHANGELOG/mission/checklist documentent l'achèvement de l'item 45 et un test
  gdUnit couvre le flux de requêtes réussies/échouées.
- 2025-12-20 — `DataLoader` dérive désormais les archétypes par formation et expose des helpers (`get_unit_classes_for_formation`, `list_formations_for_unit_class`, `list_formations_for_unit`). `CombatSystem` s'appuie sur ce mapping pour ses fallbacks, `test_data_integrity.gd` vérifie la cartographie, et README/CHANGELOG/mission/checklist documentent l'achèvement de l'item 44.
- 2025-12-19 — Documenté le guide d'usage des sliders de compétence : README détaille désormais la boucle complète (sélection, validations HUD, vérifications télémétrie et réactions combat/logistique/assistant) et `docs/tests/acceptance_tests.md` ajoute AT-16 pour refléter le walkthrough. Checklist item 43 clôturée, Godot headless toujours bloqué tant que le binaire n'est pas provisionné.
- 2025-12-18 — Ajouté des tests gdUnit automatisant les sliders de compétence : les requêtes EventBus valides publient un nouvel événement `competence_reallocated` et les violations de delta/inertie renvoient `competence_allocation_failed` avec les raisons détaillées, clôturant la checklist item 42. Les commandes Godot headless restent en attente tant que le binaire n'est pas provisionné dans cet environnement.
- 2025-12-17 — `TurnManager` enrichit `competence_reallocated` avec un `turn_id` et des snapshots `before`/`after`, `TelemetryAutoload` sérialise ces deltas pour les dashboards/tests, et les artefacts (README, checklist, mission brief, AT-15) reflètent la clôture de l'item 41.
- 2025-12-16 — Propagé les sliders de compétence dans tout le pipeline : Tactique module désormais le multiplicateur d'Impulsion du `CombatSystem`, `AssistantAIAutoload` ajuste ses prévisions (`competence_alignment`, snapshot allocations/ratios) et `LogisticsSystem` publie un `competence_multiplier` qui influence `flow_multiplier`/`intercept_risk`. README, CHANGELOG, mission brief, acceptance tests et gdUnit (logistique/assistant/combat) couvrent ce comportement.
- 2025-12-15 — Livré le panneau HUD « Compétence » avec sliders dynamiques (Tactique/Stratégie/Logistique), signaux `EventBus` dédiés aux demandes/échecs (`competence_allocation_requested`/`competence_allocation_failed`), et des raccourcis clavier/manette pour piloter les allocations en surface les verrous d'inertie, les deltas maximum et les pénalités logistiques en temps réel.
  README, CHANGELOG, mission brief et checklist mis à jour en conséquence.
- 2025-12-14 — Étendu `TurnManager` pour charger [`data/competence_sliders.json`](data/competence_sliders.json), appliquer des
  caps de réallocation par tour/inertie et publier l'état des modificateurs (`logistics_penalty`, deltas restants) dans
  `competence_reallocated`. Ajouté le dataset, la validation `DataLoader`, des tests gdUnit ciblant l'inertie et mis à jour les
  docs (README, CHANGELOG, mission/checklist) pour refléter la boucle compétence.
- 2025-12-13 — Ajouté des tests gdUnit pour `EspionageSystem` couvrant la diffusion du brouillard, l'échantillonnage probabiliste des pings et la décroissance du contre-espionnage afin de verrouiller l'item 37 de la checklist.
- 2025-12-12 — Instrumenté `EspionageSystem` et `TelemetryAutoload` : les pings publient désormais un événement `intel_intent_revealed` dédié, la HUD/debug overlay consigne ces révélations, et `TelemetryAutoload.get_history` préserve l'historique complet des `espionage_ping`/intentions pour les dashboards.
- 2025-12-11 — Le panneau HUD "Renseignements" affiche maintenant chaque ping `espionage_ping` (succès/échec, intention, probabilité vs jet),
  la timeline debug consigne les tirages détaillés, et `EspionageSystem` enrichit ses payloads avec roll, bonus de détection,
  deltas de visibilité et budget de compétence restant.
- 2025-12-10 — Ajouté les ordres *Recon Probe*/*Deep Cover* avec coûts combinés Élan/compétence : la HUD affiche désormais ces budgets,
  bloque l'exécution tant que la compétence manque, `EspionageSystem` déclenche automatiquement un ping ciblant l'hex le moins visible,
  et `DataLoader`/tests couvrent la validation `competence_cost`.
- 2025-12-09 — La carte rend désormais le brouillard de guerre : `EspionageSystem` émet des événements `fog_of_war_updated`
  consommés par `Map`, chaque `HexTile` affiche un overlay assombri proportionnel à la visibilité et masque les infos terrain
  quand l'intel est faible, ce qui clôt l'item 33 de la checklist Phase 4.
- 2025-12-08 — `GameManager` instancie désormais `EspionageSystem`, hydrate le brouillard via `data/terrain.json`, et le test
  gdUnit `test_game_manager_logistics_bootstrap.gd` vérifie que les tours `EventBus` synchronisent les pings `espionage_ping`
  avec les mises à jour logistiques.
- 2025-12-07 — Corrigé le typage de `CombatSystem.unit_states` pour accepter le dictionnaire `{"attacker", "defender"}` renvoyé
  par `_build_unit_states`, restaurant la compilation de `GameManager` et le bootstrap du pipeline combat/logistique. Le HUD
  amorce désormais son `AudioStreamPlayer` avant de récupérer le playback du générateur pour supprimer l'erreur Godot
  "Player is inactive" lors des premières interactions.
- 2025-12-06 — Corrigé les erreurs de parsing Godot en annotant explicitement les variables `CombatSystem`/`HUDManager`,
  rétablissant l'initialisation du GameManager; README et CHANGELOG documentent le pattern de typage renforcé.
- 2025-12-05 — Documenté le flux HUD → CombatSystem → Telemetry pour déclencher les engagements et lire le panneau "Dernier engagement"; README, mission brief et checklist Phase 3 item 31 mis à jour.
- 2025-12-04 — Ajouté `tests/gdunit/test_combat_resolution.gd` pour couvrir la reproductibilité contrôlée par seed, les tie-breakers
  contestés et les pénalités logistiques critiques sur les pertes, clôturant l'item 30 de la checklist Phase 3. README, CHANGELOG,
  mission brief et checklist mis à jour en conséquence.
- 2025-12-03 — `combat_resolved` transporte désormais un résumé des piliers (totaux, marge, piliers décisifs) et un état par
  unité (formation active, pertes estimées, remarques logistiques) que `TelemetryAutoload` sérialise pour les dashboards/HUD,
  accompagnés de nouveaux tests gdUnit verrouillant la structure.
- 2025-12-02 — Le panneau HUD "Dernier engagement" consomme désormais `combat_resolved` : jauges Position/Impulsion/Information,
  résumé logistique (flow, sévérité, mouvement, hex cible) et rappel des dépenses/gains d'Élan. README, changelog, mission brief,
  checklist et tests d'acceptation documentent l'UX; capture écran en attente d'un run Godot non headless.
- 2025-12-01 — `CombatSystem` applique désormais les formules SDS détaillant les piliers Position/Impulsion/Information : focus doctrinal multiplicatif, atténuation logistique (flow, movement_cost, sévérité), pondération météo/terrain et profils de renseignement (`signal_strength`, `counter_intel`). README, changelog et mission brief consignent les équations.
- 2025-11-30 — `GameManager` instancie désormais `CombatSystem`, relie les signaux `logistics_update`/`order_*` et enrichit les
  payloads `combat_resolved` avec le contexte de supply (flow, niveau, sévérité) afin que la télémétrie et les futurs panneaux
  HUD expliquent comment la logistique influence les piliers.
- 2025-11-29 — Documenté dans le README les avertissements Godot au démarrage sous Windows (mappings SDL `misc2`, couches Vulkan
  Microsoft incomplètes, extensions optionnelles absentes) afin que les agents sachent qu'ils sont bénins et comment les
  neutraliser localement si nécessaire.
- 2025-11-28 — Supprimé les nouveaux arrêts Godot 4.6 en annotant `LogisticsSystem` avec des identifiants de route typés, en
  forçant `ElanSystem` à utiliser des cibles de cap flottantes explicites et en dupliquant les définitions `TerrainData` avant
  merge afin que la carte puisse injecter les entrées `data/terrain.json` sans heurter les dictionnaires en lecture seule.
- 2025-11-27 — Séparé les `class_name` (`EventBus`, `DataLoader`, `Telemetry`, `AssistantAI`) des clés Autoload `*Autoload` pour supprimer l'erreur Godot 4.6 `class_name_hides_autoload`, ajouté les hints typés manquants dans `DataLoader` et `LogisticsSystem`, et mis à jour la documentation/tests (`README`, `CHANGELOG`, mission brief) afin que les agents utilisent désormais les nouveaux identifiants tout en conservant les singletons existants.
- 2025-11-26 — Neutralisé l'avertissement Godot 4.5 `class_name_hides_autoload`, ajouté des hints typés explicites dans `DataLoader`, les systèmes logistique/terrain/météo et les scripts HUD pour éviter les inférences `Variant`, et remplacé les API obsolètes (`Array.join`, opérateur `%` sur float) afin que le projet se charge sans erreurs. README et CHANGELOG reflètent la procédure de suppression.
- 2025-11-25 — `docs/tests/acceptance_tests.md` couvre maintenant la bascule HUD/debug du overlay logistique, les tooltips terrain dynamiques et la rotation météo sur la portée/logistique; README, CHANGELOG, mission brief et checklist ont été alignés.
- 2025-11-24 — `tests/gdunit/test_logistics_system.gd` couvre maintenant la réduction de portée sous météo `storm`, l'unicité des événements `logistics_break` lors des interceptions successives et la cadence de rotation météo contrôlée par la logistique; README, CHANGELOG, mission brief et checklist ont été alignés.
- 2025-11-19 — `LogisticsSystem` diffuse désormais des payloads `logistics_update` incluant les tuiles atteignables (`reachable_tiles`), les déficits de ravitaillement classés par sévérité et un résumé `convoy_statuses` pour chaque route; documentation (README, tests d'acceptation, mission brief) et données (`data/logistics.json`) reflètent les nouveaux champs.
- 2025-11-20 — `data/terrain.json` décrit désormais chaque hexagone (Plaines/Forêt/Colline) avec noms, coûts de mouvement et texte descriptif; la carte applique ces métadonnées, les payloads logistiques incluent `terrain_name`, et les boutons HUD/debug exposent un tooltip synthétique pour suivre les biomes et leurs coûts.
- 2025-11-21 — `WeatherSystem` pilote maintenant la rotation `sunny/rain/mist` via les plages `duration_turns`, publie des payloads
  `weather_changed` avec modificateurs + tours restants, désactive la rotation interne du `LogisticsSystem`, et la HUD affiche un
  panneau météo coloré synchronisé avec ces événements (couverture `tests/gdunit/test_weather_system.gd`).
- 2025-11-22 — `LogisticsSystem` applique les modificateurs météo/scénario aux multiplicateurs de flux, expose un bloc `weather_adjustments` (notes QA incluses) et un `intercept_risk` par route, et les tests `tests/gdunit/test_logistics_system.gd` couvrent ces nouveaux champs.
- 2025-11-23 — `TelemetryAutoload` normalise désormais les payloads `weather_changed` (modificateurs mouvement/logistique/intel/Élan, durée restante, raison), `tests/gdunit/test_weather_system.gd` vérifie la capture côté buffer, et `docs/telemetry/dashboard_plan.md` liste les nouveaux champs pour les dashboards météo.
- 2025-11-18 — `LogisticsOverlay` affiche désormais des anneaux d'approvisionnement pulsés et des marqueurs de convois animés (verts/ambers/rouges) directement alimentés par `logistics_update`; les interceptions se signalent via des croix rouges, et la capture GIF reste en attente faute de client Godot graphique dans ce conteneur.
- 2025-11-17 — `data/logistics.json` encode désormais les centres d'approvisionnement/rings/convoys, `LogisticsSystem` consomme ces graphes, et un test gdUnit vérifie que chaque scénario logistique reste connexe.
- 2025-11-16 — `GameManager` instancie `LogisticsSystem`, partage les autoloads `EventBus`/`DataLoader`, et le test `tests/gdunit/test_game_manager_logistics_bootstrap.gd` verrouille la propagation des signaux `turn_started`/`logistics_toggled` pour lancer la Phase 2.
- 2025-11-15 — Documenté l'acceptation manuelle de la boucle Commandement & Élan : `docs/tests/acceptance_tests.md` détaille le swap de doctrine, l'émission d'ordres et la vérification du buffer `TelemetryAutoload`, clôturant l'item 15 de la checklist Phase 1.
- 2025-11-11 — Les contrôles HUD de doctrine/ordre déclenchent désormais les requêtes EventBus, restaurent la doctrine active lorsqu'une inertie bloque un swap et ajoutent des infobulles de bouton détaillant l'Élan manquant pour exposer les validations directement dans l'interface.
- 2025-11-12 — `AssistantAIAutoload` archive les paquets `order_issued`/`assistant_order_packet` et la debug overlay affiche un journal déroulant (ordre, cible, intention, confiance) validant la propagation des ordres côté assistant.
- 2025-11-13 — Ajouté une batterie de tests gdUnit verrouillant le refus de changement de doctrine pendant l'inertie, les échecs de dépense d'Élan lorsque le budget est insuffisant et l'acquittement `assistant_order_packet`; en attente d'un run `godot --headless --path . --script res://scripts/ci/gdunit_runner.gd` dès que l'exécutable sera disponible.
- 2025-11-14 — Instrumenté la boucle commande/Élan : nouveaux signaux `order_rejected`/`elan_gained` côté `EventBusAutoload`, `TelemetryAutoload` normalise désormais les payloads `doctrine_selected`/`order_issued`/`order_rejected`/`elan_spent`/`elan_gained`, `tests/gdunit/test_command_elan_loop.gd` couvre les rejets Élan/doctrine + les raisons de dépense/gain, et README/plan KPI (`docs/telemetry/dashboard_plan.md`) reflètent les schémas.
- 2025-11-10 — Le couple Doctrine/Élan applique les multipliers SDS pour calculer l'inertie des ordres, ajoute les bonus de cap Élan propres à chaque doctrine, déclenche la décroissance automatique après un tour complet au plafond, et la HUD affiche désormais une ligne "Inertie" + des infobulles détaillant cap, bonus et tours bloqués (capture HUD à prendre lors du prochain run Godot local car le conteneur actuel est headless).
- 2025-11-09 — `GameManager` attend désormais le signal `data_loader_ready` avant de configurer `DoctrineSystem`/`ElanSystem`, en journalisant les comptes et en ne démarrant le tour 1 qu'après l'initialisation garantie.
- 2025-11-08 — Documenté la copie HUD (doctrines, ordres, messages de feedback, tonalités audio) et les notes d'accessibilité dans le README pour boucler l'item 8 de la checklist.
- 2025-11-07 — Enrichi `data/orders.json` avec les coûts de CP, délais de base, exigences doctrinales, ciblage, postures et métadonnées Assistant AI, puis renforcé `DataLoaderAutoload`/`tests/gdunit/test_data_integrity.gd` et la documentation (README/CHANGELOG) pour refléter le nouveau contrat.
- 2025-11-06 — Locked the doctrine catalogue to SDS specs with command profiles and updated logistics synergies so downstream systems consume the full Force/Ruse/Patience/Vitesse/Équilibre dataset.
- 2025-11-05 — Stabilised HUD procedural audio by queueing `_play_feedback()` requests, deferring buffer clears until playback is inactive, and generating `docs/logs/hud_audio_feedback_2025-11-05.log` via `scripts/tools/simulate_hud_audio_feedback.py` to verify repeated doctrine/order swaps stay silent.
- 2025-11-04 — Normalised the autoload names in `project.godot`, extended `tests/gdunit/test_autoload_preparation.gd` to cover configuration/signals, and recorded the startup handshake in `docs/logs/autoload_readiness_2025-11-04.log` to close Checklist Phase 0 item 4.
- 2025-11-03 — Hardened `DataLoaderAutoload` with schema + enum validation (`validate_collection()`), surfaced load-time issues through `load_all()`, and extended `tests/gdunit/test_data_integrity.gd` with regression coverage for valid/invalid payloads while checking off Checklist Phase 0 item 3.
- 2025-11-01 — Re-aligned Vertical Slice P0 scope after reviewing `docs/project_spec.md`, mission brief, and `context_snapshot.md`; confirmed no new scope deltas beyond the existing local Godot binary provisioning blocker.
- 2025-11-02 — Catalogued Phase 0 data gaps across `data/*.json`, highlighting missing doctrines, CP metadata, logistics graphs, weather telemetry fields, and the absent competence slider dataset in the mission brief.
- Re-sequenced `CHECKLISTS.md` into a numbered, evidence-driven execution script and updated the mission brief/README to call out the strict sequential flow.
- Reordered every `class_name` declaration ahead of its `extends` clause across autoloads, systems, and tests so older editor builds stop aborting with `Unexpected "class_name" here` parse errors.
- Replaced the vertical slice planning checklist with a detailed 2025 execution plan, archived the previous milestone summary, and aligned the mission brief/README/CHANGELOG with the new structure.
- Established agent onboarding artefacts (`AGENTS.md`, refreshed vibe-coding playbook, mission workspace).
- Added automated Godot lint/build/test runners plus a GitHub Actions workflow mirroring the headless commands.
- Introduced a generated context snapshot, changelog, and branch-level reporting routine for sustained continuity.
- Ajouté des tests d’intégrité gdUnit pour valider le chargement et la structure des fichiers JSON `data/` avant d’étendre le gameplay.
- Documented the vertical slice planning checklists in `CHECKLISTS.md` and linked them from the onboarding flow.
- Adjusted CI Godot scripts to extend `SceneTree` so headless `--script` execution works during merges.
- Updated map and UI scripts to preload their dependencies, restoring the build smoke check after missing type parse errors.
- Authored the `docs/agents/missions/vertical_slice_p0.md` brief and checked off the corresponding checklist item for Vertical Slice P0 planning.
- Drafted SDS outlines for all eight P0 systems in `docs/design/sds_outlines.md` and linked them across the onboarding docs.
- Locked full SDS packages for Command Model and Élan (`docs/design/sds_command_model.md`, `docs/design/sds_elan.md`) with
  acceptance criteria and telemetry requirements ready for review.
- Upgraded the CI workflow to install Godot 4.5.1 with cache cleanup to eliminate parser regressions on headless runners.
- Normalised HUD and debug overlay scene parenting so UI nodes instantiate reliably during the build smoke check.
- Replaced deprecated ternary syntax in HUD and game manager scripts so the project opens cleanly in Godot 4.5.1.
- Repaired the HUD and debug overlay scripts after merge conflicts, restoring logistics toggle wiring and resolving Godot 4.5
  preload warnings.
- Authored a one-page GDD synthèse (`docs/gdd_vertical_slice.md`) summarising vision, fantasy, piliers, boucles et risques, et
  coché la Checklist A du vertical slice après avoir relié le document aux artefacts clés.
- Séquencé la feuille de route vertical slice sur Semaine 0–6 dans `docs/agents/missions/vertical_slice_p0.md`, en reliant
  chaque jalon aux systèmes P0 et aux artefacts de télémétrie/tests à préparer.
- Rédigé le TDD d'architecture data-driven (`docs/design/tdd_architecture_data.md`) couvrant autoloads Godot, bus d'événements,
  pipeline JSON et interactions avec l'IA assistante, puis coché la première action de la Checklist B.
- Étendu les schémas JSON `data/` avec les métadonnées d'inertie, de coûts d'Élan et d'interactions logistiques pour préparer le chargement data-driven des systèmes P0, puis documenté la référence dans le README et le changelog.
- Complété la Checklist B en documentant dans le TDD le mapping JSON → scripts/scènes, avec une table de routage DataLoader et des références directes vers `scripts/core` et `scripts/systems`, puis relié ce guide dans le README et le changelog.
- Préparé l'entrée en Checklist C en configurant les autoloads `EventBus`, `DataLoader`, `Telemetry` et `AssistantAI`, en publiant un test gdUnit qui vérifie les caches du DataLoader et en ajoutant une acceptation `AT-06` pour contrôler le signal `data_loader_ready` et la télémétrie.
- Consolidé cette préparation en différant l'émission initiale `data_loader_ready` pour laisser `Telemetry` et `AssistantAI` se connecter, puis en verrouillant le flux via le nouveau test `tests/gdunit/test_autoload_preparation.gd`.
- Livré la boucle commandement/Élan Semaine 0–1 : systèmes Doctrine/Élan interconnectés, HUD avec sélection doctrine/ordres, gestion de l'inertie et feedback audio, plus tests gdUnit dédiés.
- Mis en service le socle logistique hybride Semaine 2–3 : calcul des anneaux d'approvisionnement, routes/convoys animés et rotation météo (`sunny`/`rain`/`mist`) émettant des payloads `logistics_update` et `weather_changed` exploitables par la HUD et la télémétrie.
- Finalisé les systèmes Semaine 4–5 : `CombatSystem` calcule les trois piliers via doctrines/terrain/météo/espionnage, `EspionageSystem` maintient le brouillard, produit des pings probabilistes avec intentions révélées, et la télémétrie capture `combat_resolved`/`espionage_ping` avec tests `test_combat_and_espionage_systems.gd`.
- Bouclé la Semaine 6 : `TurnManager` gère désormais un budget de compétences par tour, consomme automatiquement des points lors des ruptures logistiques, et `CombatSystem` combine formation active + allocations pour moduler les piliers avec publication `formation_changed`.
- Livré le catalogue `data/formations.json`, la couverture gdUnit (`test_competence_and_formations.gd`) et l'enrichissement des payloads `logistics_update`/`Telemetry` afin que la boucle compétence/formation soit entièrement instrumentée.
- Vérifié dans l'environnement local que tous les fichiers `data/*.json` se parsant sans erreur via un script Python pendant que
  l'exécutable Godot est provisionné pour les commandes headless obligatoires.
- Aligné le brief `docs/agents/missions/vertical_slice_p0.md` avec l'état réel : jalons Semaine 0–6 cochés, commandes headless notées comme bloquées en attendant l'exécutable Godot local.
- Consolidé la télémétrie Checklist D : nouveau signal `logistics_break`, Telemetry/test gdUnit mis à jour, note KPI & dashboards dans `docs/telemetry/dashboard_plan.md`, et checklist cochée.
- Documenté la stratégie de synchronisation EventBus/Telemetry/DataLoader dans un ADR (`docs/ADR_0002_event_bus_and_telemetry_autoloads.md`) et coché l'action dédiée dans les checklists/mission.
- Maintenu le glossaire vertical slice en ajoutant [`docs/glossary.md`](docs/glossary.md), en le reliant au README et en cochant la dernière action de la Checklist D.
- Rétabli le chargement de l'éditeur en neutralisant l'avertissement `class_name_hides_autoload` et en ajoutant des annotations de types explicites dans la HUD et le DataLoader pour éviter les inférences `Variant` bloquantes de Godot 4.5.
- Renommé les classes des autoloads en `EventBusAutoload`/`DataLoaderAutoload`/`TelemetryAutoload`/`AssistantAIAutoload`, renforcé les hints typés d'Élan et du TurnManager pour qu'aucun avertissement Godot 4.5 ne bloque le chargement, et documenté dans le README la commande PowerShell utilisée pour lancer le projet (répliquée dans `errors.log`).
- Actualisé le cache `global_script_class_cache.cfg` de Godot pour refléter les suffixes `Autoload`, supprimant les erreurs de parsing "Could not find type ...Autoload" rencontrées au démarrage.
- Réaligné `ElanSystem` pour typer explicitement les dictionnaires `elan_generation`, levant l'erreur Godot "Variant" qui empêchait la compilation des scripts dépendants.
- Renforcé `ElanSystem` en annotant le résultat de `clamp()` et la récupération `elan_generation` afin de supprimer les nouveaux avertissements "Cannot infer" que Godot 4.5 traite désormais comme des erreurs au chargement.
- Amorçé le générateur audio de la HUD avant l'injection des frames pour supprimer les erreurs "Player is inactive" lors des interactions doctrines/ordres.
- Arrêté et vidangé le générateur audio de la HUD avant chaque nouveau ton afin de supprimer les erreurs `AudioStreamGeneratorPlayback.clear_buffer` récurrentes et la fuite d'instances observées à la fermeture du jeu.
- Consolidé ce correctif audio en imposant que le `AudioStreamGeneratorPlayback` soit complètement inactif avant de purger le
  buffer, ce qui élimine l'assertion `Condition "active" is true` constatée lors des changements de doctrine et des avances de
  tour.

## Follow-ups / Open Questions
- Monitor the first CI run on GitHub to ensure the headless Godot image has the required permissions and paths.
- Expand gdUnit-style tests beyond the initial smoke coverage as systems evolve.
- Provision the `godot` executable in local dev containers so automated commands can run outside CI.
- Re-run the full headless command suite once Godot 4.5.1 is available locally to confirm there are no lingering parse errors.
- Confirm the fixed HUD/debug overlay parenting removes the missing node warnings during the next headless build run.
- Ajouter la validation JSON Schema dans `DataLoader`, enrichir `AssistantAI` avec des prévisions simulées, et consigner les événements Checklist C (élan, combat, espionnage) dans `Telemetry` une fois les systèmes branchés.
- Itérer sur les overlays HUD/logistiques pour visualiser les nouvelles données de terrain et de météo émises par `LogisticsSystem`.
- Brancher `CombatSystem` et `EspionageSystem` sur la HUD (panneaux combat/intel) et préparer une boucle IA/assistant pour fournir des cibles et unités réelles aux engagements simulés.
