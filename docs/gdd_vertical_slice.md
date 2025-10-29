# GDD Synthèse — Weave of War (Vertical Slice P0)

## Vision
Weave of War est un jeu de stratégie/gestion PC inspiré de l'Art de la guerre de Sun Tzu. Le prototype vertical slice vise à
faire ressentir une stratégie "par les flux" où les victoires se jouent avant l'affrontement. Le joueur orchestre doctrines,
élan et logistique pour façonner le champ de bataille plutôt que de réagir en urgence.

## Fantasy joueur
Incarner un stratège lucide qui perçoit les réseaux invisibles d'influence et d'approvisionnement. Chaque décision doit donner
l'impression de tisser ou rompre des flux vitaux en anticipant les intentions adverses.

## Piliers non négociables
1. **Flux animés** — les réseaux logistiques et d'influence sont visibles, animés et lisibles.
2. **Lisibilité** — toute action génère un feedback clair (UI, audio, animation) en <200 ms.
3. **Réactivité** — doctrines, ordres et dépenses d'élan répondent immédiatement avec explications accessibles.

## Boucles de jeu
### Boucle core (30–90s)
Observer les flux → Ajuster doctrine/ordres → Dépenser de l'élan pour un coup de pouce → Résolution animée → Feedback immédiat.

### Boucle mid (5–20 min)
Étendre ses réseaux → Stabiliser les fronts → Employer l'espionnage pour sonder/ping → Déclencher des engagements décisifs.

### Boucle meta (heures)
Maîtriser les doctrines, composer des scénarios et optimiser les profils de victoire (territoire, attrition, morale/diplomatie).

## Public cible & ton
Joueurs PC de stratégie midcore appréciant la planification réfléchie, les systèmes transparents et une ambiance calme mais
sous tension.

## North Star Metric
≥ **30 %** des joueurs reviennent quotidiennement.

## Risques & mitigations
- **Crédibilité de l'IA assistante** — prioriser des règles interprétables + journaux d'intention avant toute complexité.
- **Surcharge visuelle** — fournir des toggles de calques et niveaux de détails progressifs.
- **Dérive de périmètre** — s'appuyer sur les SDS, checklists et ADR pour contenir le scope vertical slice.
