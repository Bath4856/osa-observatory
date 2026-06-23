# OSA ISA – P8 Audit Automation V2

Cadre d'audit de production de l'Observatoire OSA ISA.

## Fonctionnalités

- Audits automatisés de la plateforme (19 modules)
- Calcul de l'IPRS (Indice de Publication et de Robustesse du Système)
- Décision de publication officielle via la Publication Gate
- Surveillance de la dérive scientifique entre publications
- Validation des indicateurs TRAJECTOIRE (Produit 3)
- Persistance dans le ledger OPS (PostgreSQL)
- Génération de rapports PDF
- Export Grafana (`latest_audit.json`)
- Notifications email

---

## Structure du projet

```
osa-observatory/
├── audit/
│   ├── audits/               ← 19 modules d'audit
│   │   ├── audit_api.py
│   │   ├── audit_api_contract_advanced.py
│   │   ├── audit_api_performance_advanced.py
│   │   ├── audit_api_permissions.py
│   │   ├── audit_api_schema.py
│   │   ├── audit_data_quality.py
│   │   ├── audit_database.py
│   │   ├── audit_dns.py
│   │   ├── audit_documentation.py
│   │   ├── audit_isa.py
│   │   ├── audit_methodology.py
│   │   ├── audit_openapi.py
│   │   ├── audit_p7i.py
│   │   ├── audit_performance.py
│   │   ├── audit_repository_structure.py
│   │   ├── audit_scientific_drift.py
│   │   ├── audit_security.py
│   │   ├── audit_swot.py
│   │   └── audit_trajectory.py
│   ├── core/                 ← composants transverses
│   │   ├── audit_runner.py
│   │   ├── audit_ledger.py
│   │   ├── email_sender.py
│   │   ├── grafana_export.py
│   │   ├── pdf_generator.py
│   │   ├── publication_gate.py
│   │   ├── scoring.py
│   │   └── signature.py
│   └── config/
│       ├── audit_config.yaml
│       ├── publication_rules.yaml
│       └── trajectory_rules.yaml
├── ops/                      ← orchestration et déploiement
│   ├── run_audit.py          ← point d'entrée CLI
│   ├── docker-compose.audit.yml
│   └── requirements.txt
├── reports/                  ← générés à l'exécution
│   ├── pdf/
│   └── grafana/
│       └── latest_audit.json
├── logs/
└── README.md
```

> **Pourquoi un dossier `ops/` séparé ?**
> `run_audit.py`, `docker-compose.audit.yml` et `requirements.txt` sont
> des fichiers d'orchestration et de déploiement, pas des modules d'audit.
> Les placer dans `audit/` les noie parmi les 19 modules. `ops/` offre
> une séparation claire : *ce qui audite* vs *ce qui orchestre*.

---

## Pipeline de données

```
L1 (collecte raw)
    → L2 (imputation MICE / imputer_v3)
    → L3 (normalisation min-max)
    → P7A–P7Z (intelligence souveraine)
    → P8 (API / publication)

Indicateurs TRAJECTOIRE : L1 → L2 → L3 → Produit 3 (direct, sans alimentation ISA)
```

---

## Architecture du runner

```
run_audit.py
    └── audit_runner.run_all(cfg)
            │
            ├── 19 modules d'audit (ThreadPoolExecutor, timeout 60 s)
            │
            ├── compute_publication_score()   → IPRS
            │
            ├── publication_decision()        → statut
            │
            └── Outputs
                    ├── ops.audit_runs        (PostgreSQL ledger)
                    ├── ops.audit_results
                    ├── ops.audit_publication_gate
                    ├── reports/pdf/          (ReportLab)
                    ├── reports/grafana/      (latest_audit.json)
                    └── email SMTP            (notifications)
```

---

## Modules d'audit

### Infrastructure / connectivité
| Module | Rôle |
|--------|------|
| `DNS` | Résolution DNS + HTTPS des 3 domaines OSA |
| `OPENAPI` | Validation du spec OpenAPI (`/openapi.json`) |
| `API` | Disponibilité et latence des endpoints publics |
| `API_CONTRACT_ADVANCED` | Contrat complet API (15 endpoints, 2 passes auth) |
| `API_SCHEMA` | Validation structurée des champs de réponse |
| `API_PERMISSIONS` | Contrôle d'accès (passe sans token + passe avec token) |
| `API_PERFORMANCE_ADVANCED` | Latence par endpoint avec labels severity |
| `DATABASE` | Inventaire PostgreSQL (rf/ma/ops/pub), ledger OPS |

### Cœur OPS
| Module | Rôle |
|--------|------|
| `ISA` | Scores ISA : 54 pays, couverture, confiance |
| `SWOT` | Signaux SWOT souverains par pilier |
| `P7I` | Early Warning Composite (AMAR) |
| `TRAJECTORY` | Indicateurs TRAJECTOIRE Produit 3 |
| `SCIENTIFIC_DRIFT` | Dérive ISA entre années de publication |

### Qualité / structure / sécurité
| Module | Rôle |
|--------|------|
| `METHODOLOGY` | Doublons `ma.indicator_values`, poids, gouvernance |
| `DATA_QUALITY` | Nulls, confiance négative, hors bornes (L3 uniquement) |
| `PERFORMANCE` | Latence API + DB vs seuils OPS |
| `DOCUMENTATION` | Présence et contenu des fichiers de config |
| `REPOSITORY_STRUCTURE` | Arborescence projet |
| `SECURITY` | Scan de patterns sensibles (fichiers non-.py) |

---

## Composants core

### Scoring — `scoring.py`
Calcule l'**IPRS** (0–100). Les modules infra/API (sans `coverage_pct` ni `total_rows`) contribuent à 100 % sur leur statut. Les modules de données appliquent une pondération tripartite (statut 50 %, couverture 30 %, volume 20 %).

### Publication Gate — `publication_gate.py`
| Condition | Statut |
|-----------|--------|
| Au moins 1 module FAIL | `REVIEW_REQUIRED` |
| Aucun module exécuté | `REVIEW_REQUIRED` |
| IPRS indisponible | `CONDITIONAL_PUBLICATION` |
| IPRS < 70 | `REVIEW_REQUIRED` |
| 70 ≤ IPRS < 90 | `CONDITIONAL_PUBLICATION` |
| IPRS ≥ 90 | `READY_FOR_PUBLICATION` |

### Ledger OPS — `audit_ledger.py`
Tables PostgreSQL :
```
ops.audit_runs
ops.audit_results
ops.audit_publication_gate
ops.v_audit_latest
```

### Signature — `signature.py`
Génère `report_hash` (SHA-256 du rapport) et `signature_hash` (SHA-256 du payload `{report_hash, git_commit, signed_at}`). Vérification via `verify_signature(report, signature_hash, signature_payload)`.

---

## Configuration

```
audit/config/
├── audit_config.yaml        ← config principale (DB, API, seuils, modules)
├── publication_rules.yaml   ← règles de publication (source de vérité des seuils)
└── trajectory_rules.yaml    ← règles TRAJECTOIRE (indicateurs, seuils, doctrine)
```

Les seuils IPRS sont définis dans `publication_rules.yaml` et répliqués dans `audit_config.yaml.publication`. **En cas de divergence, `publication_rules.yaml` fait foi.**

---

## Politique de publication

Conforme à `rf.publication_policy` :

| Statut données | Période |
|----------------|---------|
| `OFFICIAL` | 2020–2024 |
| `PRELIMINARY` | 2025 (rodage collecte) |
| `COLLECTING` | 2026 |

Première publication institutionnelle : **septembre 2027**.
Le cycle PV de validation déclenche les transitions de statut automatiquement
via `rf.register_publication_pv()` (4ème semaine d'août).

---

## Déploiement Docker

```bash
# Depuis la racine du repo
docker compose -f ops/docker-compose.audit.yml up -d

# Logs en temps réel
docker logs -f osa-audit

# Vérifier le statut
docker ps
```

Variables d'environnement sensibles à injecter (ne pas committer en clair) :
```bash
export DB_PASSWORD=<mot_de_passe>
export SMTP_USER=<cle_api>
export SMTP_PASSWORD=<cle_secrete>
```

---

## Exécution manuelle

```bash
# Depuis la racine du repo
python ops/run_audit.py
```

Le rapport JSON est sauvegardé dans `reports/audit_YYYYMMDD_HHMMSS.json`.
`reports/grafana/latest_audit.json` est écrasé à chaque run.

---

## Schémas PostgreSQL requis

```
rf    ← référentiels (pays, régions, blocs, indicateurs)
ma    ← méthodes et valeurs (indicator_values, indicator_meta)
ops   ← ledger OPS (audit_runs, audit_results, audit_publication_gate)
pub   ← publication (mv_trajectories, vues matérialisées)
```

---

## Monitoring Grafana

Trois dashboards (`ops/` → `reports/grafana/`) :

| Fichier | Contenu |
|---------|---------|
| `grafana_publication_readiness.json` | IPRS, statut publication, modules FAIL/WARNING |
| `grafana_scientific_alerts.json` | Dérive ISA entre publications successives |
| `grafana_trajectory.json` | Couverture et confiance des indicateurs TRAJECTOIRE |

Datasource : `marcusolsson-json-datasource` pointant sur `reports/grafana/latest_audit.json`.

---

## Sécurité

- Signatures SHA-256 sur chaque rapport
- Ledger immuable (PostgreSQL, pas de DELETE)
- Historique d'audit complet dans `ops.audit_runs`
- Credentials injectés par variables d'environnement (jamais en clair dans le repo)

Roadmap sécurité :
- Signatures X.509 PKI
- Chaînes de Merkle pour l'audit trail
- Certificats souverains de publication OSA

---

## Statut

| Champ | Valeur |
|-------|--------|
| Statut | Production |
| Environnement | OSA Observatory – VPS Infomaniak (Suisse) |
| Plateforme | OSA ISA |
| Version | P8 OPS V2 |
| Sprint actuel | 22 (clôturé) |
| Prochain sprint | 23 – indicateurs TRAJECTOIRE PENV + SMUGGLING_VALUE |

---

## Mainteneur

**OSA Observatory** – Africa Sovereignty Intelligence Platform  
`contact@osa-observatory.africa`
