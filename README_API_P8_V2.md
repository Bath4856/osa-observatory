# OSA ISA API — P8 V2 FOUNDATION

## Procédure d'exécution complète

### Prérequis
- Python 3.11+
- PostgreSQL 16 avec pub.* installé (patch_p8_v2_foundation_v2.sql)
- mg.api_usage_registry et mg.api_key_registry installés (patch_mg_api_registries.sql)

---

### Étape 1 — Base de données

```bash
# Installer les registries API
psql -h 127.0.0.1 -p 5432 -U postgres -d osa_db \
  -f db/patch_db/patch_mg_api_registries.sql

# Insérer une clé expert (SHA-256)
psql -h 127.0.0.1 -p 5432 -U postgres -d osa_db -c "
INSERT INTO mg.api_key_registry (api_key_hash, owner_label, access_class)
VALUES (encode(sha256('votre-clé-secrète'::bytea), 'hex'), 'Admin', 'EXPERT');"
```

### Étape 2 — Configuration

```bash
cp api/.env.example api/.env
# Éditer api/.env avec vos valeurs :
#   DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
#   API_EXPERT_KEY (même valeur que la clé insérée en base)
#   CORS_ORIGINS (restreindre en production)
```

### Étape 3 — Installation locale

```bash
pip install -r api/requirements.txt
```

### Étape 4 — Lancement

```bash
# Depuis la racine du repo osa-observatory
uvicorn api.main:app --reload --port 8000
```

### Étape 5 — Dry run

```powershell
.\db\run\test_api_p8_v2_dry_run.ps1
```

### Étape 6 — Docker (production)

```bash
docker-compose -f api/docker-compose.yml up -d
```

### Étape 7 — OpenAPI export

```bash
curl http://localhost:8000/openapi.json -o OPENAPI_P8_V2.json
```

---

## Endpoints disponibles

| Endpoint | Accès | Auth |
|----------|-------|------|
| GET / | PUBLIC | Non |
| GET /health | PUBLIC | Non |
| GET /api/v2/release | PUBLIC | Non |
| GET /api/v2/countries | PUBLIC | Non |
| GET /api/v2/countries/{iso3} | PUBLIC | Non |
| GET /api/v2/countries/{iso3}/history | PUBLIC | Non |
| GET /api/v2/countries/{iso3}/pillars | PUBLIC | Non |
| GET /api/v2/rankings/latest | PUBLIC | Non |
| GET /api/v2/rankings/year/{year} | PUBLIC | Non |
| GET /api/v2/predictive/readiness | PUBLIC | Non |
| GET /api/v2/predictive/readiness/{iso3} | PUBLIC | Non |
| GET /api/v2/predictive/fragility | PUBLIC | Non |
| GET /api/v2/predictive/signals | EXPERT | **Oui** — X-API-Key header |
| GET /api/v2/opportunities | PUBLIC_LIMITED | Non |
| GET /api/v2/methodology | PUBLIC | Non |

---

## Structure des fichiers

```
api/
├── __init__.py
├── main.py              — Bootstrap FastAPI + CORS + routers
├── config.py            — Settings Pydantic (.env)
├── db.py                — SQLAlchemy engine + get_db()
├── security.py          — validate_expert_access (SHA-256)
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── middleware/
│   ├── __init__.py
│   ├── release_guard.py — validate_release_status()
│   └── telemetry.py     — register_api_usage() async
└── routers/
    ├── __init__.py
    ├── countries.py     — /api/v2/countries/*
    ├── rankings.py      — /api/v2/rankings/*
    ├── predictive.py    — /api/v2/predictive/*
    ├── release.py       — /api/v2/release
    └── opportunities.py — /api/v2/opportunities + /api/v2/methodology

db/
├── patch_db/
│   └── patch_mg_api_registries.sql
└── run/
    └── test_api_p8_v2_dry_run.ps1

audit/
└── audit_api_p8_v2.sql
```

---

## Corrections vs blueprint originale

| Problème blueprint | Correction |
|---|---|
| `api_key_hash` comparé sans hash | SHA-256 via `hashlib` dans `security.py` |
| `release_guard.py` sans `db.close()` | `finally: db.close()` ajouté |
| `telemetry.py` async + SessionLocal sync | `asyncio.to_thread` pour compatibilité |
| `audit_api_contracts.sql` → `pub.api_contract_registry` | Corrigé → `mg.api_contract_registry` |
| `allow_methods=["*"]` en production | `allow_methods=["GET"]` — lecture seule |
