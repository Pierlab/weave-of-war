# AGENTS – Guide pour assistants IA

Ce fichier fournit un cadre pour les assistants de codage (GitHub Copilot, ChatGPT, etc.) travaillant sur ce dépôt. En le lisant, l’IA obtient une vue d’ensemble du projet, des instructions d’installation et de test, des conventions de codage et des spécificités du domaine. L’objectif est d’assurer que l’IA produit un code cohérent avec notre architecture et nos standards.

## Aperçu du projet

- **Domaine** : simulateur NNFX (No Nonsense Forex) combinant un moteur Python, une API FastAPI et une interface Streamlit.

### Modules principaux

- **core/** : cœur du moteur (logger, paramètres, accès DB, génération de stratégies, signaux, risk/position, simulateurs).
- **strategies/** : modèles typés et générateur de combinaisons NNFX.
- **simulation/** : orchestration haut-niveau des backtests, import/export d’artefacts et scénarios multi-paires.
- **backend/** et **api/** : services FastAPI pour déclencher le pré-calcul des indicateurs, lancer des simulations mono/multi stratégies et exposer les résultats.
- **frontend/** : application Streamlit (pages Data, Strategy, Runner, Visualize, Reports, Logs, About) connectée à l’API.
- **docs/** : documentation centrale (voir `docs/overview/simulation_engine.md` pour la vision complète et actualisée de l’architecture).
- **scripts/** : tâches utilitaires (mise à jour des données, pré-calcul des signaux, maintenance de la base).
- **tests/** : couverture unitaire et intégration.

- **Objectif fonctionnel** : tester massivement des stratégies NNFX, comparer leurs métriques et documenter les configurations retenues.
- **Objectif technique** : garantir une architecture modulaire où chaque composant (indicateurs, stratégies, simulateur, UI) est extensible, testable et bien loggé.

### Phase actuelle : chaîne signaux → positions

Priorité à la cohérence bout-en-bout :

- s’assurer que les stratégies génèrent des **signaux consolidés** (`signal_final`, `exit_signal_final`) alignés avec les rôles NNFX ;
- vérifier l’ouverture de positions via `core.nnfx_simulator` (dimensionnement, SL/TP, trailing stop, ajustement d’exposition) ;
- suivre la vie des positions (fermeture par TP/SL ou signal de sortie) et mettre à jour la trésorerie/capital ;
- documenter toute évolution dans `docs/overview/simulation_engine.md` et tenir la base de connaissances synchronisée avec le code.

## Installation et environnement

L’assistant doit connaître les étapes de mise en place afin de fournir des commandes pertinentes :

1. Utiliser Python 3.10 ou supérieur et créer un environnement virtuel (`python -m venv .venv`, `source .venv/bin/activate`).
2. Installer les dépendances listées dans `requirements.txt` : `pandas`, `pandas_ta`, `sqlalchemy`, `psycopg2`, `fastapi`, `streamlit`, `pydantic`, `pytest`, `pytest-cov`, etc. Ajouter `ta-lib` si disponible.
3. Installer PostgreSQL et créer une base `forex_nnfx` avec un utilisateur dédié (voir `scripts/create_database.sql`).
4. Exécuter les migrations Alembic pour créer les tables (`pairs`, `prices`, `indicator_signals`, `strategy_configs`, `simulation_runs`, `simulation_metrics`, ...).
5. Renseigner la configuration (connexion DB, niveaux de log, paramètres par défaut) dans `.env` ou YAML.
6. Mettre à jour les données de marché (`python scripts/update_forex_data.py`) puis pré‑calculer les signaux (`python scripts/compute_signals.py`) avant toute simulation.
7. Démarrer l’API FastAPI : `uvicorn backend.main:app --reload`.
8. Lancer l’interface Streamlit : `streamlit run frontend/app.py`.

## Documentation et ressources

- `README.md` : présentation synthétique et journal des itérations (à tenir à jour).
- `docs/overview/simulation_engine.md` : référence de la vision (simulation, signaux, risk management, UI). Toute modification significative du moteur doit y être reflétée.
- `docs/schema_summary.md` : schéma de la base PostgreSQL.
- `docs/navigation_overhaul_checklist.md`, `archive/` : historiques et feuilles de route.
- `AGENTS.md` et déclinaisons par dossier : toujours synchroniser les consignes après modification.

## Index des fichiers AGENTS.md

Ce dépôt contient les fichiers `AGENTS.md` suivants :

- `AGENTS.md` (racine)
- `api/AGENTS_api.md`
- `backend/AGENTS_backend.md`
- `config/AGENTS_config.md`
- `core/AGENTS_core.md`
- `docs/AGENTS_docs.md`
- `frontend/AGENTS_frontend.md`
- `indicators/AGENTS_indicators.md`
- `lib/AGENTS_lib.md`
- `scripts/AGENTS_scripts.md`
- `simulation/AGENTS_simulation.md`
- `strategies/AGENTS_strategies.md`
- `tests/AGENTS_tests.md`
- `alembic/AGENTS_alembic.md`

Mettre à jour cette liste dès qu’un nouveau fichier `AGENTS.md` est créé ou supprimé.

## Conventions de codage

- **Style** : suivre PEP8 ; utiliser des noms explicites en anglais ; typer les fonctions ; ajouter des docstrings descriptives.
- **Structuration** : respecter l’architecture en couches (DB ↔ services ↔ API ↔ UI). Le simulateur consomme des signaux pré‑calculés.
- **Modularité** : chaque indicateur et rôle (baseline, confirmers, volume, exit) doit être encapsulé pour faciliter l’extension.
- **Gestion du risque** : appliquer les règles NNFX (risque global 2 %, ATR14 pour sizing, trailing stop sur la première moitié, matrice d’exposition pour les corrélations).
- **Logs** : utiliser `core/logger.py` et enrichir les messages avec le contexte (stratégie, paire, date).
- **Tests** : écrire des tests PyTest pour tout nouveau code ; vérifier que les simulations retournent des résultats cohérents ; tester l’API (FastAPI TestClient) et idéalement l’UI.

## Instructions spécifiques à l’IA

- **Focalisation métier** : illustrer le calcul des signaux, la création de stratégies NNFX et l’exécution de simulations paramétrables (paire, timeframe, stratégie).
- **Compréhension du domaine** : assimiler la méthode NNFX (baseline, ATR, confirmateurs, volume, exit, gestion du risque) avant de générer du code.
- **Réutilisation du code existant** : privilégier l’extension des modules actuels (`core/strategy_engine.py`, `core/nnfx_simulator.py`, etc.) plutôt que de réécrire depuis zéro.
- **Pré‑calcul et performances** : exploiter les signaux stockés (`indicator_signals`) et optimiser les boucles critiques (vectorisation, multiprocessing, numba si pertinent).
- **Sécurité et robustesse** : valider les paramètres utilisateurs via Pydantic, gérer les exceptions DB et protéger l’API.
- **Documentation** : mettre à jour docstrings et fichiers dans `docs/` après toute évolution notable.
- Avant toute modification du frontend, consulter `checklist_mvp1.md` ou `checklist_global.md` et s’assurer qu’aucune trace de l’ancienne UI ne subsiste.

## Maintenance continue

- Vérifier systématiquement si une évolution impacte un `AGENTS.md`, le `README.md` ou la documentation de `docs/` et mettre à jour les fichiers concernés.
- Tenir `docs/overview/simulation_engine.md` synchronisé avec la réalité du moteur et de l’UI.
- Compléter le journal des changements dans `README.md` lorsqu’une itération modifie le comportement utilisateur ou la vision produit.
- Maintenir `docs/navigation_overhaul_checklist.md` en phase avec l’avancement de la roadmap UI.

## Testing et validation

L’assistant doit orienter vers l’exécution de tests pour valider ses modifications :

- Exécuter `pytest` à la racine (`--override-ini=addopts=` si `pytest-cov` est absent).
- S’assurer qu’un serveur PostgreSQL local est actif pour les tests liés à la base.
- Tester l’API via FastAPI `TestClient`.
- Vérifier la couverture avec `pytest --cov` lorsque le plugin est installé.
- Lancer l’application Streamlit après modifications impactant l’UI et vérifier les graphiques.
- En cas de bug, écrire d’abord un test de régression qui échoue avant d’appliquer le correctif.

Respecter ces directives aidera l’assistant à produire un code de qualité, aligné sur la vision du projet et prêt à être intégré dans la base existante.
