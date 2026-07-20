# 05_API — API FastAPI

*Section de l'OSA Architecture Knowledge Base (AKB). Sources : `api.zip` (82 fichiers, 39 `.py`) et le sous-dossier `api/` dupliqué dans `portail.zip`. Établi le 14 juillet 2026. Détail des routes : `05_API_Catalog.xlsx`.*

---

## 1. Architecture générale (`main.py`)

FastAPI, `OSA ISA API` v2.0.0-candidate. Licence `CC-BY-NC-4.0`, portée déclarée : 54 États africains, 10 piliers comportementaux, données 2021-2024, approche factuelle (non fondée sur la perception) — cohérent mot pour mot avec la doctrine du Volume 0.

**Ordre des middlewares (documenté explicitement dans le code, FIFO)** :
1. `metrics` (Prometheus) — doit mesurer avant tout, y compris les rejets.
2. `rate_limit` — doit s'exécuter avant CORS.
3. `CORS`.

**`/metrics`** est exposé en sous-application ASGI Prometheus, protégé par `require_expert` (dépendance sur la clé `API_EXPERT_KEY`) — cohérent avec la rotation de secrets déjà connue.

## 2. Trois anomalies de code trouvées dans `main.py`

Aucune n'est bloquante en soi, mais toutes les trois valent une revue avant une prochaine évolution de l'API.

### a) Chemin Windows codé en dur
```python
sys.path.insert(0, "G:/python-packages")
```
Cette ligne, présente dans `main.py` lui-même, n'a de sens que sur le poste de développement Windows (cohérent avec `pip packages at G:\python-packages` déjà connu). En production sur le VPS Linux, ce chemin n'existe pas : l'instruction est inoffensive tant que `prometheus_client` est déjà installé dans l'environnement Python du conteneur, mais elle n'a aucune raison de figurer dans le code exécuté en production.

### b) Imports et inclusions de routeurs dupliqués
- `eparticipation_router` est importé **3 fois** et inclus **3 fois** (`app.include_router(eparticipation_router)` répété).
- `auth_affiliates_router` est importé **2 fois** et inclus **2 fois**.

FastAPI ne lève pas d'erreur dans ce cas, mais chaque route de ces routeurs apparaît en double dans le schéma OpenAPI (`/docs`), sans bénéfice fonctionnel.

### c) Code mort commenté conservé (`SPRINT14 DEPRECATED`)
Plusieurs imports et inclusions de routeurs (`early_warning_sprint7`, `decision_scenarios_sprint7`, `api_phase3_sprint8`) sont commentés avec la mention explicite `SPRINT14 DEPRECATED` plutôt que supprimés — traçabilité assumée d'une dépréciation, cohérente avec la doctrine de gouvernance (rien n'est supprimé sans laisser de trace), mais à faire disparaître définitivement si une nouvelle version de `main.py` est produite.

## 3. Huit fichiers de `routers/` non câblés dans `main.py`

Sur les 24 fichiers du dossier `routers/`, 8 ne sont **jamais importés dans `main.py`** — c'est-à-dire qu'ils n'existent pas du point de vue de l'API réellement exposée, même s'ils contiennent du code fonctionnel :

| Fichier | Nature | Constat |
|---|---|---|
| `opendata_FIXED.py` | Routeur complet (17 routes) | Variante alternative de `opendata.py`, jamais câblée — nom suggérant un correctif jamais intégré |
| `opendata_GENECO.py` | Routeur complet (19 routes) | Variante alternative, jamais câblée |
| `opendata_GENECO_v2.py` | Routeur complet (19 routes) | Deuxième variante alternative, jamais câblée non plus |
| `certification.py` | Routeur complet (1 route, `/api/v1/certification`) | Fonctionnel (interroge `ma.v_isa_certification_engine`), jamais câblé |
| `premium.py` | Routeur complet (1 route, `/api/v1/premium/feasibility`) | Fonctionnel (`ma.v_isa_premium_feasibility_triggers`), jamais câblé |
| `publication.py` | Routeur complet (2 routes, `/api/v1/publication/*`) | Fonctionnel (`ma.v_isa_open_data_catalog`, registre API), jamais câblé |
| `isa_public.py` | Routeur complet (4 routes, `/api/v1/isa/*`) | Fonctionnel (scores par pays/pilier/région, SWOT), jamais câblé |
| `onboard_founder.py` | **N'est pas un routeur** | Script CLI autonome (`onboard_founder.py`, cf. mémoire projet) rangé par erreur dans `routers/` — ne définit aucun `APIRouter` |

**Trois vraies variantes d'`opendata` (54 KB de code à elles trois) et quatre routeurs fonctionnels autonomes (certification, premium, publication, ISA public) existent dans le dépôt sans jamais être exposés.** Si ces fonctionnalités sont censées être en service, il manque une ligne d'import dans `main.py` ; si elles sont volontairement mises de côté, ce sont 4 routeurs + 3 variantes qu'il serait sain de déplacer hors de `routers/` (ou de supprimer) pour éviter toute confusion lors d'une prochaine revue de code.

## 4. La divergence `admin_affiliates.py` / `auth_affiliates.py`

Conformément à la décision actée le 14 juillet 2026, les deux versions (issues respectivement de `api.zip` et de `portail.zip`) sont conservées et cataloguées comme variantes. La comparaison ligne à ligne (`diff`) donne cependant une indication claire, qu'il paraît utile de signaler plutôt que de la laisser de côté :

**Les deux fichiers de `api.zip` sont des sur-ensembles fonctionnels des fichiers correspondants de `portail.zip`, tous deux alignés sur une même décision datée du 11 juillet 2026 :**

- `admin_affiliates.py` (api.zip) : le mot de passe n'est **plus généré par l'administrateur** — l'affilié le choisit lui-même à la confirmation d'e-mail (commentaire explicite : *« fusionné dans confirm-email, décision du 11 juillet 2026 »*). La version `portail.zip` génère encore un mot de passe temporaire côté serveur (`generate_password()`, envoi en clair dans l'e-mail d'invitation, étape 2 distincte) — c'est le comportement *précédent* la décision du 11 juillet.
- `auth_affiliates.py` (api.zip) : contient en plus la logique de bandeau KYC (`kyc_complete`), et deux endpoints absents de la version `portail.zip` — `PATCH /me` (mise à jour de profil) et `PATCH /me/password` (changement de mot de passe avec vérification de l'ancien).

**Lecture proposée, à confirmer par vous plutôt qu'à trancher unilatéralement ici :** la version `api.zip` semble être la plus récente et la plus complète des deux — cohérente avec le fait qu'`api.zip` est la source directement câblée dans `main.py`. La version `portail.zip` ressemble à une copie de travail antérieure au 11 juillet, restée dans le dossier de transit du portail (cohérent avec la note déjà connue : `H:\doc\portail` est un dossier de transit, pas un clone Git). Les deux restent néanmoins cataloguées côte à côte dans `05_API_Catalog.xlsx`, sans suppression, en attendant votre arbitrage.

## 5. Catalogue des routes (voir `05_API_Catalog.xlsx`)

174 routes détectées automatiquement sur 24 fichiers routeurs (hors `onboard_founder.py`, qui n'en définit aucune). Chaque ligne indique le fichier, le module, si le routeur est câblé dans `main.py`, la méthode HTTP, le chemin de route et le résumé (`summary=` ou docstring) quand disponible.

Modules les plus riches : `eparticipation.py` (23 routes), `opendata.py` (22, + 58 dans les 3 variantes non câblées), `early_warning.py` (8), `tokens.py` et `tickets.py` (7 chacun).

## 6. Configuration et middleware

- **`config.py`** — `pydantic_settings`, lit `api/.env` (jamais le `.env` racine du dépôt). Ce fichier `.env` contient des secrets réels — voir l'avertissement de sécurité déjà noté en `01_Inventory`.
- **`db.py`** — SQLAlchemy, pool de connexions (`pool_size=10`, `max_overflow=20`), fonction `check_db_connection()` utilisée par `/health`.
- **`middleware/rate_limiter.py`** (le plus gros fichier du dossier middleware, 12,7 Ko) — cohérent avec la collision de tables déjà documentée en `03_ADR` (finding #37).
- **`middleware/metrics.py`, `middleware/telemetry.py`, `middleware/release_guard.py`** — non détaillés dans cette passe ; à ouvrir séparément si besoin.
