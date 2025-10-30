# Context Update — Current Branch

## Summary
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
- Livré la boucle commandement/Élan Semaine 0–1 : systèmes Doctrine/Élan interconnectés, HUD avec sélection doctrine/ordres, gestion de l'inertie et feedback audio, plus tests gdUnit dédiés.

## Follow-ups / Open Questions
- Monitor the first CI run on GitHub to ensure the headless Godot image has the required permissions and paths.
- Expand gdUnit-style tests beyond the initial smoke coverage as systems evolve.
- Provision the `godot` executable in local dev containers so automated commands can run outside CI.
- Re-run the full headless command suite once Godot 4.5.1 is available locally to confirm there are no lingering parse errors.
- Confirm the fixed HUD/debug overlay parenting removes the missing node warnings during the next headless build run.
- Ajouter la validation JSON Schema dans `DataLoader`, enrichir `AssistantAI` avec des prévisions simulées, et consigner les événements Checklist C (élan, combat, espionnage) dans `Telemetry` une fois les systèmes branchés.
