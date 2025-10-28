# Agent Enablement Blueprint

This blueprint consolidates every mechanism currently used in the Forex Simulator Web project to onboard and guide coding agents. Use it as a checklist when recreating the same collaboration model for a new repository (for example, a Godot-based strategy game).

## 1. Repository-wide guardrails
- **Central AGENTS charter** – `AGENTS.md` in the repository root defines the simulator's domain, high-level modules, installation steps, documentation duties, and mandatory testing commands. It also keeps an index of every scoped `AGENTS_*.md` file that agents must obey before touching code or docs. Mirror this file in the new project to describe architecture, phase priorities, and coding conventions upfront.
- **Change journal in `README.md`** – Instead of a traditional overview, the root README acts as a running changelog. Every contribution must add a dated entry summarising impacted areas and referencing updated documents or tests. Recreate this ritual so agents always document their work history.

## 2. Scoped AGENTS guides
Each top-level package contains its own `AGENTS_*.md` with expectations tailored to that domain. When reproducing the setup, create equivalent guides alongside the Godot project's directories so agents immediately understand local constraints.

| Scope | Key focus areas |
| --- | --- |
| `api/AGENTS_api.md` | Plans a reusable FastAPI package, emphasising router/schema structure, parity with backend endpoints, and doc updates when refactoring. |
| `backend/AGENTS_backend.md` | Documents async FastAPI patterns, endpoint responsibilities, logging, validation, and integration tests via `TestClient`. |
| `config/AGENTS_config.md` | Explains YAML schema hygiene, documentation updates, and validation tests for configuration files. |
| `core/AGENTS_core.md` | Covers engine modules (logging, signal consolidation, risk management) and insists on dataclasses, logging discipline, and ATR-based sizing. |
| `docs/AGENTS_docs.md` | Sets documentation style, Markdown standards, and a reminder to keep architecture narratives synced with code. |
| `frontend/AGENTS_frontend.md` | Guides Streamlit UX work, navigation checklists, and coordination with backend contracts. |
| `indicators/AGENTS_indicators.md` | Details indicator normalisation, role/type separation, and deterministic signal outputs. |
| `lib/AGENTS_lib.md` | Governs shared utilities and reusability requirements. |
| `scripts/AGENTS_scripts.md` | Defines expectations for operational scripts, database maintenance, and CLI ergonomics. |
| `simulation/AGENTS_simulation.md` | Directs higher-level orchestration, ensuring simulations consume precomputed signals and respect risk logic. |
| `strategies/AGENTS_strategies.md` | Formalises NNFX strategy models, registries, and generator determinism. |
| `tests/AGENTS_tests.md` | Specifies PyTest layout, fixture usage, `slow` markers, regression rules, and commands to execute the suite. |
| `alembic/AGENTS_alembic.md` | Captures migration conventions, upgrade/downgrade coverage, and schema documentation duties. |

## 3. Documentation ecosystem
- **Theme-based documentation tree** – `docs/README.md` explains the curated folders (`overview/`, `data_model/`, `indicators/`, `frontend/`, `operations/`) and links to each sub-README so contributors can quickly locate references. Replicate this hub to avoid fragmented knowledge.
- **Operational runbooks** – `docs/operations/testing.md` details how to run PyTest (including the `--override-ini=addopts=` flag, `--runslow` marker, and PostgreSQL prerequisites). Other files in `operations/` handle installation, deployment, logging, and troubleshooting, forming a complete support library.
- **Documentation audit** – `docs/documentation_audit.md` tracks the freshness of each document and outstanding follow-ups. Maintain a similar audit to keep the knowledge base reliable.
- **Architecture canon** – `docs/overview/simulation_engine.md` (and related overview docs) describe the simulator pipeline, NNFX roles, and ongoing priorities. Use an equivalent architecture narrative for the Godot project to align agents on system design.

## 4. Testing and development workflows
- **PyTest suite expectations** – Agents must run `pytest --override-ini=addopts=` by default and optionally `--runslow` for heavier coverage. Tests rely on a PostgreSQL instance and respect fast vs. slow markers.
- **Development shortcuts** – The root `Makefile` bundles commands to launch the FastAPI backend, Streamlit UI, or both. Provide comparable make targets (or scripts) in the new repo so agents share the same workflows.
- **Bug protocol** – Tests instructions insist on writing regression cases before fixes, keeping coverage high across indicators, strategies, and simulations. Adopt the same rule set for Godot gameplay tests.

## 5. Project rituals and checklists
- **Project review & cleanup** – The repository includes `PROJECT_REVIEW_CHECKLIST.md`, `PROJECT_CLEANUP_CHECKLIST.md`, and `PROJECT_REVIEW_NOTES.md` to steer milestone audits and housekeeping. Carry over these templates to structure periodic reviews.
- **Data & operations scripts** – Utilities under `scripts/` (with their own agent guide) handle database setup, data refresh, and maintenance tasks referenced in the installation section of `AGENTS.md`. Equivalent tooling will help automate recurring chores in the new environment.

## 6. Steps to replicate for a new Godot strategy game
1. Draft a root `AGENTS.md` describing the game's architecture, priority focus, coding standards, documentation rules, and required tests.
2. Create per-directory `AGENTS_*.md` files mirroring the table above, tailored to Godot subsystems (e.g., `core/`, `scenes/`, `ai/`, `ui/`, `tests/`).
3. Replace the traditional README with a changelog journal so every agent records their impact chronologically.
4. Build a `docs/` tree with themed folders, an index README, and domain-specific references (architecture overview, gameplay systems, asset pipeline, operations runbooks).
5. Establish testing guides (unit/integration scenarios for Godot, CI expectations) and flag slow suites similarly to the existing PyTest markers.
6. Provide helper scripts or make targets to launch the Godot editor, run headless tests, and start any auxiliary servers.
7. Maintain review and cleanup checklists so contributors can track large milestones and housekeeping work.

Following this blueprint will give the new project the same structured guidance and accountability that this repository provides to coding agents.
