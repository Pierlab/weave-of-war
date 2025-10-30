# ADR 0002 — EventBus + Telemetry Autoloads comme socle de synchronisation

- **Statut**: Accepté
- **Date**: 2025-10-31
- **Décideurs**: Équipe Vertical Slice P0
- **Références**: `scripts/core/event_bus.gd`, `scripts/core/telemetry.gd`, `scripts/core/data_loader.gd`, `scripts/core/assistant_ai.gd`, `tests/gdunit/test_autoload_preparation.gd`

## Contexte
Les systèmes P0 (commandement/Élan, logistique, combat 3 piliers, espionnage, compétences, formations) reposent sur des flux
d’événements partagés. Les jeux de données JSON chargés par `DataLoader` doivent être disponibles avant que les systèmes ne
s’abonnent aux signaux et la télémétrie doit capturer les interactions clés (`elan_spent`, `logistics_update`, `combat_resolved`,
`espionage_ping`, `competence_reallocated`, etc.). Les milieux CI/agents exigent également un point de branchement unique pour
les tests gdUnit et les outils de diagnostic HUD/debug overlay.

## Décision
1. **Conserver les autoloads `EventBus`, `Telemetry`, `DataLoader`, `AssistantAI`** définis dans `project.godot` comme contrat de
   synchronisation unique.
2. **Garantir la séquence de démarrage via `DataLoader.call_deferred("emit_ready")`** afin que `Telemetry` et `AssistantAI`
puisse enregistrer les signaux avant l’émission `data_loader_ready`.
3. **Normaliser les événements** : chaque système publie des dictionnaires structurés via `EventBus`, relayés vers `Telemetry`
   pour instrumentation et vers la HUD pour feedback joueur.
4. **Tester l’initialisation** avec `tests/gdunit/test_autoload_preparation.gd` qui vérifie la présence des autoloads,
   l’abonnement `Telemetry` et la réception du signal `data_loader_ready`.

## Conséquences
- Les agents disposent d’un pipeline déterministe pour brancher de nouveaux systèmes sans recréer la plomberie évènementielle.
- Les tests peuvent stubber `EventBus`/`Telemetry` pour simuler des signaux, assurant une couverture reproductible.
- La HUD et les overlays réutilisent les mêmes signaux que la télémétrie, ce qui garantit la cohérence des feedbacks en jeu et
  dans les logs.
- Les futurs ADRs ou SDS devront respecter le contrat de message (champs `event_name`, `payload`) centralisé dans `Telemetry`.

## Alternatives considérées
- **Autoloads dédiés par système** : rejeté car multiplie les points d’intégration et complexifie la synchronisation.
- **Bus d’événements local par scène** : rejeté car empêche la télémétrie centralisée et augmente le couplage HUD ↔ systèmes.
- **Émission directe vers `Telemetry` sans `EventBus`** : rejeté car rendrait les tests et les overlays dépendants d’un service
  unique au lieu d’une couche de distribution neutre.

## Suivi
- Maintenir un tableau de correspondance événement → charge utile dans `docs/design/tdd_architecture_data.md`.
- Ajouter de nouveaux signaux aux tests gdUnit correspondants pour verrouiller leur contrat.
- Documenter dans la HUD/Debug overlay toute visualisation reposant sur ces signaux afin de garder le joueur et la télémétrie
  alignés.
