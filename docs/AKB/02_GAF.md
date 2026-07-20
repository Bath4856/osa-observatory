# 02_GAF — Governance Audit Findings

*Section de l'OSA Architecture Knowledge Base (AKB). Source : `gaf.zip` (100 fichiers). Établi le 14 juillet 2026.*

---

## 1. Ce qu'est le GAF

Le GAF (Governance Audit Findings) transforme les findings bruts produits par les audits OPS en un système de gouvernance continu. Là où l'audit *détecte*, le GAF *oriente, décide, corrige et mesure* — c'est le mécanisme opérationnel qui donne corps, dans le code, aux Chapitres 8 et 9 du Volume 0 (gouvernance des actifs scientifiques, système d'audit).

Cette section reprend et complète `gaf/docs/GAF_ARCHITECTURE.md`, qui est déjà, en l'état, un document d'architecture de très bonne qualité (structuré selon la grille Zachman : WHAT/WHY/WHO/WHEN/WHERE). Le contenu ci-dessous ne le réécrit pas : il l'organise pour l'AKB et le complète avec le catalogue réel des findings extraits des 56 fichiers SQL du dossier `gaf/sql/`.

## 2. Architecture (Zachman)

| Axe | Contenu |
|---|---|
| **WHAT** | Le *Finding* : unité de connaissance atomique, traçable, assignable et mesurable dans le temps, produite par les audits. |
| **WHY** | Capitaliser les anomalies détectées, documenter les recommandations, assurer la traçabilité des décisions, mesurer la trajectoire de correction (Audit Resolution Rate, MTTC). |
| **WHO** | `audit_runner` (produit les findings bruts) → `orientation_engine` (classifie et oriente automatiquement) → `DATA_STEWARD` / `METHODOLOGY_COMMITTEE` / `OPS_ADMINISTRATOR` (traitent selon la nature de l'anomalie). |
| **WHEN** | Cycle de vie d'un finding : `OPEN → ORIENTED → IN_PROGRESS → RESOLVED → CLOSED`, avec embranchement possible vers `DEFERRED`. |
| **WHERE** | PostgreSQL, schéma `ops` : `audit_findings`, `audit_recommendations`, `audit_decisions`, `audit_corrections`, + vues `v_findings_open` et `v_findings_dashboard` (Grafana). |

## 3. Pipeline d'automatisation

```
audit_runner.run_all(cfg)
    │  results[] : {module, status, findings[], warnings[]}
    ▼
OrientationEngine.orient_run(results)      ← core/orientation_engine.py (12 règles, R01-R12)
    │  findings structurés : finding_code, severity, object_type, object_code,
    │                         recommended_action, priority, owner, sprint_target
    ▼
GAFLedger.save_findings(audit_id, oriented) ← core/gaf_ledger.py
    │
    ├── ops.audit_findings        (constat)
    └── ops.audit_recommendations (orientation automatique)
    ▼
Comité humain
    ├── ops.audit_decisions   (ACCEPT / DEFER / REJECT / ESCALATE)
    └── ops.audit_corrections (correction + vérification, avec git_commit pour traçabilité)
    ▼
Trigger : fermeture automatique si correction vérifiée
```

Point d'entrée CLI : `run_gaf.py` (orchestrateur A+B+C). `ops_run_audit.py` exécute l'audit lui-même en amont.

### Les 12 règles d'orientation actives (`gaf_config.yaml`)

| Code | Finding | Sévérité | Owner | Sprint cible |
|---|---|---|---|---|
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

Seuils de gouvernance (`gaf_config.yaml`) : un finding **CRITICAL bloque la publication** ; un **HIGH déclenche une alerte immédiate** ; un **MEDIUM** est traité au sprint suivant.

### KPIs GAF

| KPI | Formule |
|---|---|
| Audit Resolution Rate | findings CLOSED / total findings |
| MTTC (Mean Time To Correction) | avg(correction_date − detected_at) |
| Recommendation Closure Rate | recommandations traitées / émises |
| CRITICAL Open | COUNT findings CRITICAL non clôturés |

## 4. Ce que révèle le catalogue réel des 56 fichiers `gaf/sql/`

L'extraction automatique (voir `02_GAF_Findings_Catalog.xlsx`) distingue deux populations bien distinctes, mélangées dans le même dossier :

- **31 fichiers sont de véritables findings GAF** — des `INSERT`/`UPDATE` sur `ops.audit_findings`, avec (quand détecté) un `finding_code`, une sévérité et un statut.
- **25 fichiers sont des scripts d'implémentation** liés à un sprint donné (migrations de schéma, backfills, correctifs) qui vivent dans `gaf/sql/` sans être eux-mêmes des findings — par exemple `sprint30_lot_a_affiliates.sql` (modèle utilisateurs) ou `create_founder_account_preprod.sql`.

Cette distinction n'était pas visible dans l'inventaire de la section 01 : elle n'apparaît qu'en lisant le contenu SQL de chaque fichier plutôt que son seul nom.

### Limite méthodologique à noter

L'extraction automatique du `finding_code` et de la `Severite` échoue sur 35 des 56 fichiers (63 %) : plusieurs findings anciens (sprints ≤ 23) ou multi-étapes (ex. `gaf_finding_20_update_*.sql`, cinq fichiers qui mettent tous à jour le même `finding_id = 20`) n'utilisent pas le motif `INSERT` simple attendu par l'extracteur. Le champ `Extrait_Description` reste néanmoins renseigné pour la quasi-totalité des fichiers via l'en-tête de commentaire ou le premier bloc `$doc$`, et donne une idée fiable du contenu même quand les champs structurés n'ont pas pu être isolés automatiquement.

Deux findings identifiés méritent une mention explicite dans l'AKB, au-delà du tableau :

- **ADR-001** (`gaf_finding_adr001_identity_sync.sql`, sévérité INFO, statut ORIENTED) — décision d'architecture complète et exploitable telle quelle (voir `03_ADR`).
- **ADR-002 / défauts latents** (`gaf_finding_adr002_e2e_validation_defects.sql`, sévérité HIGH) — 5 défauts découverts le 12 juillet 2026 lors de la première exécution réelle du cycle de synchronisation d'identité (nginx `/api/` manquant en prod, table `mg.password_reset_tokens` absente, etc.). Traité en détail en `03_ADR`.

## 5. Ce qui manque encore pour clore cette section

- Certains fichiers (`gaf_finding_20_update_*.sql`) documentent un même finding (#20, dominance WKN/THR dans AMAR) enrichi à cinq reprises — un historique de raisonnement scientifique remarquable (cause racine, lecture doctrinale, simulation, statistiques, poids), mais qui mériterait d'être consolidé en une seule fiche de synthèse plutôt que cinq fragments chronologiques, si cette section devait servir de référence de consultation rapide.
- Le dashboard Grafana (`dashboards/grafana_gaf_governance.json`) n'a pas été analysé dans cette passe — à ouvrir séparément si vous voulez que l'AKB documente aussi les KPIs visualisés, pas seulement calculés.
