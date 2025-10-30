# Vibe Coding Checklists — Vertical Slice P0

These checklists consolidate the planning artefacts for the vertical slice described in `docs/Projet_Jeu_Strategique_Synthese.md`. They provide ready-to-run missions for coding agents.

## Checklist A — Démarrage documentaire & mission (Semaine 0–1)
- [x] Créer un nouveau brief `docs/agents/missions/vertical_slice_p0.md` à partir de `docs/agents/agent_base.md`, incluant les huit systèmes P0, les SDS à livrer et les validations attendues. (Voir mission `vertical_slice_p0.md`.)
- [x] Rédiger une page GDD synthèse (vision, fantasy, piliers, boucles, risques) conformément à la section 2.1. (Livrable : [`docs/gdd_vertical_slice.md`](docs/gdd_vertical_slice.md).)
- [x] Produire les SDS prioritaires (`Commandement`, `Élan`) avec le template indiqué, en listant règles joueur/système, UX et télémétrie initiale. (Livrables: [`docs/design/sds_command_model.md`](docs/design/sds_command_model.md), [`docs/design/sds_elan.md`](docs/design/sds_elan.md).)
- [x] Mettre à jour `context_update.md`, `README.md` et `CHANGELOG.md` pour référencer les nouveaux artefacts et leur statut, puis régénérer `context_snapshot.md` via `python scripts/generate_context_snapshot.py` avant la revue.

## Checklist B — Architecture & données (TDD initial)
- [x] Définir le plan d’architecture data-driven dans un TDD, couvrant composants Godot, bus d’événements et interactions IA assistante comme mentionné en section 2.3. (Livrable : [`docs/design/tdd_architecture_data.md`](docs/design/tdd_architecture_data.md))
- [x] Élargir les schémas JSON (`data/`) avec les champs nécessaires pour doctrines, ordres, unités, météo et logistique, y compris métadonnées pour inertie, coûts d’élan, interactions logistiques. (Ajout des champs de référence dans `data/*.json`.)
- [ ] Documenter le mapping JSON → scènes/scripts dans le TDD afin que les agents sachent où charger et valider les données (référencer les scripts cibles sous `scripts/core` et `scripts/systems`).
- [ ] Ajouter des tests d’intégrité (unitaires ou gdUnit) pour s’assurer que les fichiers JSON se chargent et respectent le schéma avant de poursuivre le gameplay.

## Checklist C — Production du vertical slice (Semaine 0–6)
- [ ] Semaine 0–1 : Implémenter la boucle commandement/élan (doctrine active, ordres autorisés, inertie) avec feedback visuel/sonore minimal et stockage d’élan plafonné.
- [ ] Semaine 2–3 : Mettre en place le ravitaillement hybride (anneaux, routes animées, convois interceptables) et terrain/météo (Plaine/Forêt/Colline + Soleil/Pluie/Brume) avec impacts sur mouvement/logistique.
- [ ] Semaine 4–5 : Développer la résolution Combat 3 Piliers et les mécaniques d’espionnage (brouillard, pings probabilistes, intentions) en suivant le test d’acceptation fourni pour les 3 piliers.
- [ ] Semaine 6 : Finaliser les compétences/points par tour et les formations d’unités (infanterie/archers/cavalerie avec postures), raccorder la télémétrie minimale (élan dépensé, résultats piliers, ruptures logistiques) et valider la boucle complète via tests automatisés + mise à jour des acceptances.
- [ ] À chaque étape, tenir à jour `context_update.md`, ajouter des entrées à `CHANGELOG.md`, régénérer `context_snapshot.md`, et aligner `docs/tests/acceptance_tests.md` avec les nouvelles interactions (ex. boutons HUD, overlays).

## Checklist D — Télémetrie & ADR
- [ ] Instrumenter les événements listés (dépenses d’élan, résultats piliers, ruptures logistiques, intentions espionnées) et noter les KPIs/dashboards initiaux.
- [ ] Documenter les décisions structurantes via des ADR (`docs/`), en suivant l’exemple fourni pour les doctrines sans cartes.
- [ ] Maintenir un glossaire vivant (éventuellement dans `docs/`) pour les termes clés : Élan, Doctrine, Ordre, Zone logistique, Pilier, Ping, Posture, Inertie.
