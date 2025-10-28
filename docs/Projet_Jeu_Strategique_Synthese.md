# 🧭 Projet de Jeu Stratégique — Synthèse de Conception

## 1. Unification et Priorisation

### P0 — Socle Jouable (Vertical Slice)
1. **Commandement sans cartes (Doctrines + Ordres)**  
   - Une doctrine active par tour, modulant attaque, ruse, logistique.  
   - Ordres : Avancer, Tenir, Fortifier, Harceler, Intercepter, Feindre.  
   - Inertie : changement limité par tour.

2. **Élan Global**  
   - Ressource centrale plafonnée.  
   - Gagnée via succès, dépensée pour assauts, marches forcées, inspirations.  
   - Feedback visuel et sonore immersif.

3. **Ravitaillement Hybride**  
   - Zones d’approvisionnement en anneaux.  
   - Routes/flux animés reliant les villes.  
   - Convois automatiques interceptables.

4. **Combat “3 Piliers”**  
   - Position (terrain/formation/météo), Impulsion (élan/moral), Information (renseignement).  
   - 2/3 gagnés = victoire.

5. **Espionnage**  
   - Brouillard + pings probabilistes.  
   - Renseignements donnant des intentions probables (offensive/logistique).

6. **Terrain & Météo**  
   - Version A : Plaine / Forêt / Colline + Soleil/Pluie/Brume.  
   - Version B (plus tard) : Neige/Orage rares.

7. **Compétences & Points par Tour**  
   - 6 points répartis entre Tactique / Stratégie / Logistique (cap 3).  
   - Déplacement de 2 pts max par tour (inertie).

8. **Unités & Formations**  
   - Infanterie / Archers / Cavalerie.  
   - Postures : Attaque / Défense / Marche (coût élan + délai).

### P1 — Extensions à prototyper
- Ravitaillement “pipes” animés.  
- Convois interceptables.  
- Formations avancées.  
- Doctrines additionnelles.

### P2 — Long terme
- Espions physiques, méta-campagne, diplomatie.

---

## 2. Documentation du Projet

### 2.1 GDD — Vision & Boucles
- Vision, fantasy, piliers, public cible, NSM (30% joueurs quotidiens).  
- Boucles : core/mid/meta.  
- Risques et mitigations.

### 2.2 SDS (System Design Specs)
Chaque SDS décrit :
- Problème & intention.  
- Règles Joueur / Règles Système.  
- UI/UX.  
- KPIs & télémétrie.  
- Tests d’acceptation.

Priorité SDS (P0) :  
`Commandement`, `Élan`, `Logistique`, `Combat3Piliers`, `Espionnage`, `TerrainMeteo`, `UnitesFormations`, `Competences`.

### 2.3 TDD — Architecture & Données
- Composants, events, structure data-driven.  
- Fichiers JSON : `doctrines.json`, `orders.json`, `units.json`, `weather.json`, `logistics.json`.  
- IA assistante (interprétation et logs).

### 2.4 Plan de Test
- Definition of Ready / Done.  
- Tests d’acceptation (Given/When/Then).  
- Mesures de compréhension et télémétrie.

### 2.5 Télémétrie
- Événements : dépenses d’élan, résultats des piliers, ruptures logistiques, intentions espionnées.  
- Dash minimal : % victoires par pilier, heatmap d’ordres.

### 2.6 UX & Art Bible
- Lisibilité (tailles, contrastes).  
- Couleurs : Logistique = bleu, Élan = or, Danger = rouge.  
- Animation rapide (<200 ms).

### 2.7 ADR — Journal des Décisions
- Format court : Contexte / Décision / Conséquences / Alternatives.

### 2.8 Glossaire
Élan, Doctrine, Ordre, Zone logistique, Pilier, Ping, Posture, Inertie.

---

## 3. Ordre de Production (Vertical Slice)

| Semaine | Objectifs | Livrables |
|----------|------------|------------|
| 0–1 | GDD + SDS_Commandement + SDS_Elan | Sliders + Doctrine + Réservoir d’élan |
| 2–3 | SDS_Logistique + SDS_TerrainMeteo | Zones + pénalités + météo |
| 4–5 | SDS_Combat3Piliers + SDS_Espionnage | Résolution parallèle + pings |
| 6 | SDS_UnitesFormations + Télémétrie | Boucle complète jouable |

---

## 4. Templates de Documentation

### SDS_Template.md
But & Intention
Règles Joueur
Règles Système
UI/UX
Télémétrie
Tests d’acceptation
Risques & Mitigations

shell
Copier le code

### Test d’acceptation — Combat 3 Piliers
Given deux armées en Forêt
And A dépense 2 Élan
And B a un ping d’intention “défensive”
When je lance la résolution
Then les 3 jauges se comparent
And si A gagne ≥2, B recule d’une case, perd 1 moral

shell
Copier le code

### ADR_0001_Doctrines_sans_cartes.md
Contexte : besoin d’unifier stratégie et tactique sans cartes.
Décision : doctrines actives + ordres simples + inertie.
Conséquences : moins d’aléa, plus de lisibilité.
Alternatives : cartes numériques rejetées.

yaml
Copier le code

---

## 5. Étapes Suivantes
- Rédiger GDD 1 page + SDS_Commandement + SDS_Elan.  
- Définir schémas JSON initiaux.  
- Lancer prototype Vertical Slice.  