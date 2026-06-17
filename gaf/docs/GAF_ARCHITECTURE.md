# OSA ISA – Sprint 24 GAF
# Governance of Audit Findings

## Vue d'ensemble

Le GAF transforme les findings bruts des audits OPS en un système de gouvernance continu. Là où l'audit détecte, le GAF oriente, décide, corrige et mesure.

---

## Architecture Zachman / Merise

### WHAT — Objet central
Le **Finding** est l'unité de connaissance produite par les audits. Chaque finding est atomique, traçable, assignable et mesurable dans le temps.

### WHY — Objectifs
- Capitaliser les anomalies détectées
- Documenter les recommandations
- Assurer la traçabilité des décisions
- Mesurer la trajectoire de correction (Audit Resolution Rate, MTTC)

### WHO — Acteurs
| Acteur | Rôle |
|--------|------|
| `audit_runner` | Produit les findings bruts |
| `orientation_engine` | Classifie et oriente automatiquement |
| `DATA_STEWARD` | Traite les anomalies de données |
| `METHODOLOGY_COMMITTEE` | Traite les anomalies méthodologiques |
| `OPS_ADMINISTRATOR` | Traite les anomalies infra/API |

### WHEN — Cycle de vie d'un finding
```
OPEN → ORIENTED → IN_PROGRESS → RESOLVED → CLOSED
              ↓
           DEFERRED
```

### WHERE — Stockage
```
PostgreSQL (schéma ops)
  ops.audit_findings
  ops.audit_recommendations
  ops.audit_decisions
  ops.audit_corrections
  ops.v_findings_open      (vue travail)
  ops.v_findings_dashboard (vue Grafana)
```

---

## Structure du dossier `gaf/`

```
gaf/
├── __init__.py
├── run_gaf.py                      ← point d'entrée CLI
├── config/
│   └── gaf_config.yaml             ← configuration GAF
├── core/
│   ├── __init__.py
│   ├── orientation_engine.py       ← Lot B : 12 règles d'orientation
│   ├── gaf_ledger.py               ← Lot C : persistance PostgreSQL
│   └── gaf_runner.py               ← orchestrateur A+B+C
├── sql/
│   ├── 001_create_gaf_tables.sql   ← Lot A : migration DB
│   └── 003_rollback.sql            ← rollback propre
├── tests/
│   └── test_orientation.py         ← 14 tests unitaires
└── docs/
    └── GAF_ARCHITECTURE.md         ← ce fichier
```

---

## Flux de données

```
audit_runner.run_all(cfg)
    │  results[] : {module, status, findings[], warnings[]}
    ▼
OrientationEngine.orient_run(results)
    │  findings structurés : {finding_code, severity, object_type,
    │                          object_code, recommended_action,
    │                          priority, owner, sprint_target}
    ▼
GAFLedger.save_findings(audit_id, oriented)
    │
    ├── ops.audit_findings        (constat)
    └── ops.audit_recommendations (orientation automatique)
    ▼
Comité humain
    ├── ops.audit_decisions   (ACCEPT / DEFER / REJECT)
    └── ops.audit_corrections (correction + vérification)
    ▼
Trigger : fermeture automatique si correction vérifiée
```

---

## Règles d'orientation (12 règles)

| Code | Finding | Sévérité | Owner | Sprint |
|------|---------|----------|-------|--------|
| R01 | `method_version_id IS NULL` | CRITICAL | DATA_STEWARD | Sprint 24 |
| R02 | Doublons `ma.indicator_values` | CRITICAL | DATA_STEWARD | Sprint 24 |
| R03 | Poids incohérents | HIGH | METHODOLOGY_COMMITTEE | Sprint 24 |
| R04 | Indicateur non lié | HIGH | METHODOLOGY_COMMITTEE | Sprint 24 |
| R05 | Endpoint API manquant | HIGH | OPS_ADMINISTRATOR | Sprint 24 |
| R06 | Timeout endpoint | MEDIUM | OPS_ADMINISTRATOR | Sprint 25 |
| R07 | Latence élevée | MEDIUM | OPS_ADMINISTRATOR | Sprint 25 |
| R08 | Valeurs nulles | MEDIUM | DATA_STEWARD | Sprint 25 |
| R09 | Indicateur TRAJECTOIRE inactif | MEDIUM | METHODOLOGY_COMMITTEE | Sprint 25 |
| R10 | Fichiers sensibles | LOW | OPS_ADMINISTRATOR | Sprint 25 |
| R11 | Pays manquant | LOW | DATA_STEWARD | Sprint 26 |
| R12 | Token non configuré | INFO | OPS_ADMINISTRATOR | Sprint 25 |

---

## Tables PostgreSQL

### `ops.audit_findings`
Constat atomique. Statuts : `OPEN → ORIENTED → IN_PROGRESS → RESOLVED → DEFERRED → CLOSED`.

Clés importantes :
- `finding_id` BIGSERIAL PK
- `audit_id` FK → `ops.audit_runs`
- `severity` CHECK IN ('CRITICAL','HIGH','MEDIUM','LOW','INFO')
- `raw_finding` JSONB — finding brut pour auditabilité complète

### `ops.audit_recommendations`
Orientation automatique. Liée au finding par `finding_id`.

### `ops.audit_decisions`
Décision humaine. `decision` CHECK IN ('ACCEPT','DEFER','REJECT','ESCALATE').

### `ops.audit_corrections`
Correction réalisée. Inclut `git_commit` pour traçabilité Git complète.
Trigger : ferme automatiquement le finding si `verified=TRUE AND finding_resolved=TRUE`.

---

## KPIs GAF

| KPI | Formule |
|-----|---------|
| **Audit Resolution Rate** | findings CLOSED / total findings |
| **MTTC** | avg(correction_date - detected_at) |
| **Recommendation Closure Rate** | recommandations traitées / émises |
| **CRITICAL Open** | COUNT findings CRITICAL non clôturés |

---

## Déploiement

```bash
# 1. Migration DB
psql -h 172.18.0.3 -U postgres -d osa_db -f gaf/sql/001_create_gaf_tables.sql

# 2. Tests
python3 gaf/tests/test_orientation.py

# 3. Run à sec (sans écriture DB)
python3 gaf/run_gaf.py --dry-run

# 4. Run complet
python3 gaf/run_gaf.py

# 5. Rollback si nécessaire
psql -h 172.18.0.3 -U postgres -d osa_db -f gaf/sql/003_rollback.sql
```

---

## Problème critique : `audit_id` dans le rapport

Le rapport JSON produit par `audit_runner` contient `audit_id: null`
car `audit_ledger.save_full_audit()` n'est pas encore appelé dans le pipeline.

**Correction Sprint 24** : intégrer `audit_ledger` dans `run_audit.py` pour
persister le run dans `ops.audit_runs` et injecter l'`audit_id` dans le rapport
avant de le passer à `run_gaf`.

---

## Feuille de route GAF

| Lot | Sprint | Contenu |
|-----|--------|---------|
| A | Sprint 24 | Tables DB + migrations |
| B | Sprint 24 | orientation_engine.py + 12 règles |
| C | Sprint 24 | gaf_ledger.py + run_gaf.py |
| D | Sprint 25 | Interface décisions (API ou CLI) |
| E | Sprint 25 | Dashboard Grafana GAF |
| F | Sprint 26 | MTTC + Recommendation Closure Rate |
