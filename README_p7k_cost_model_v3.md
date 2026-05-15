# OSA / ISA — P7K COST MODEL V3

## Métrologie Souveraine — Couche de Calibration Scientifique

Version: P7K_COST_V3  
Status: PRODUCTION_READY  
Scope: Calibration scientifique du cost model exécutif  
Dependencies:
- P7K v1 FINAL (patch_p7k_executive_governance.sql)
- P7K Finalization (patch_p7k_master_governance_finalize.sql)
- rf.isa_intervention_family_registry
- ma.v_isa_executive_priority_portfolio
- ma.v_isa_decision_country_year

---

# 1. Purpose

P7K Cost Model V3 introduit une **métrologie souveraine traçable** sur la couche exécutive ISA.

Il corrige deux anomalies critiques de V1/V2 :
- `avg_pressure` et `avg_cost` NULL pour 9 piliers sur 10 (cost model incomplet)
- `predictive_ready_flag` toujours FALSE (COALESCE manquant + booléen insuffisant)

Il introduit trois extensions épistémologiques :
- `calibration_uncertainty_score` : niveau d'incertitude de chaque valeur proxy
- `calibration_review_due_date` : date limite de révision obligatoire
- `predictive_execution_status` : remplace le booléen par un statut à 3 valeurs

P7K Cost Model V3 ne modifie pas :
- les scores ISA observés (L1/L2/L3)
- les vues P7F, P7G, P7H, P7I, P7J
- les politiques de décision P7J v2

---

# 2. Architecture métrologique

```text
RF  — paramètres scientifiques
      rf.isa_executive_cost_model         (valeurs + calibration)
      rf.isa_cost_model_audit_log         (journal des révisions)
      fn_cost_model_audit_trigger()       (trigger automatique)

MG  — gouvernance institutionnelle des modèles
      mg.isa_model_governance_policy      (règles par statut)
      mg.v_cost_model_review_due          (révisions en retard)

MA  — calculs exécutifs
      ma.mv_isa_executive_master_board    (MV reconstruite V3)
```

### Séparation RF / MG

| Schéma | Rôle                                              |
|--------|---------------------------------------------------|
| RF     | Ce que la science dit (valeurs, sources, incertitude) |
| MG     | Ce que la gouvernance décide (règles, seuils, délais) |
| MA     | Ce que le moteur calcule (scores dérivés, statuts) |

### Dépendances V3

```text
rf.isa_executive_cost_model
        ↓
mg.isa_model_governance_policy
        ↓
ma.mv_isa_executive_master_board
        ↓
predictive_execution_status
```

---

# 3. rf.isa_executive_cost_model

## 3.1 Colonnes

| Colonne                        | Type         | Description |
|-------------------------------|--------------|-------------|
| intervention_family_code       | TEXT PK      | Code famille d'intervention |
| pillar_code                    | TEXT PK      | Code pilier ISA |
| executive_cost_score           | NUMERIC(5,3) | Coût relatif d'exécution [0–1] |
| implementation_complexity      | NUMERIC(5,3) | Complexité de mise en oeuvre [0–1] |
| execution_horizon_years        | INTEGER      | Horizon d'exécution en années [1–10] |
| execution_maturity_score       | NUMERIC(5,3) | Maturité institutionnelle d'exécution [0–1] |
| calibration_method             | TEXT         | EXPERT / LITERATURE / PROXY / DEFAULT |
| calibration_status             | TEXT         | VALIDATED / PROVISIONAL / REVIEW_REQUIRED |
| calibration_uncertainty_score  | NUMERIC(5,3) | Incertitude épistémique [0–1] |
| calibration_source             | TEXT         | Référence bibliographique complète |
| calibration_date               | DATE         | Date de calibration |
| calibration_review_due_date    | DATE         | Date limite de révision obligatoire |
| calibration_version            | TEXT         | Version du cost model (V3) |

## 3.2 Valeurs V3 — 10 familles

| Pilier | Famille                      | Maturity | Uncertainty | Source proxy                    |
|--------|------------------------------|----------|-------------|---------------------------------|
| PRES   | ENERGY_WATER_CERTIFICATION   | 0.55     | 0.15        | IEA Africa Energy Outlook 2023  |
| PMON   | MONETARY_FINANCIAL_RESILIENCE| 0.58     | 0.15        | IMF WEO 2023                    |
| PHUM   | HUMAN_CAPITAL                | 0.62     | 0.15        | UNDP HDR 2023                   |
| PECO   | ECONOMIC_DIVERSIFICATION     | 0.52     | 0.20        | UNCTAD TDR 2023                 |
| PENV   | ENVIRONMENTAL_RESILIENCE     | 0.48     | 0.20        | UNEP NDC Report 2023            |
| PMIL   | SECURITY_RESILIENCE          | 0.42     | 0.20        | SIPRI MED 2023                  |
| PMIN   | MINING_VALUE_CHAIN           | 0.50     | 0.25        | EITI Africa Reports 2022        |
| PGEO   | GOVERNANCE_AND_STABILITY     | 0.38     | 0.15        | World Bank WGI 2022             |
| PNUM   | DIGITAL_SOVEREIGNTY          | 0.62     | 0.15        | ITU IDI 2023                    |
| PTRA   | TRANSPORT_LOGISTICS          | 0.55     | 0.25        | World Bank LPI 2023             |

## 3.3 Règles calibration_uncertainty_score

| Plage       | Signification                                      | Exemple |
|-------------|---------------------------------------------------|---------|
| 0.10 – 0.20 | Proxy source internationale primaire robuste       | IEA, IMF, UNDP, WB WGI, ITU |
| 0.21 – 0.30 | Proxy source secondaire ou régionale               | UNCTAD, UNEP, SIPRI |
| 0.31 – 0.50 | Proxy estimé, couverture partielle                 | EITI proxy, LPI Africa |
| 0.51 – 0.70 | Placeholder ou estimation sans source primaire     | À éviter — REVIEW_REQUIRED |

---

# 4. Gouvernance MG

## 4.1 mg.isa_model_governance_policy

| Status           | Usable MV | Predictive eligible | predictive_execution_value | Uncertainty max | Révision   |
|------------------|-----------|--------------------|-----------------------------|-----------------|------------|
| VALIDATED        | OUI       | OUI                | EXEC_READY                  | 0.30            | 24 mois    |
| PROVISIONAL      | OUI       | OUI                | EXEC_READY_CAUTION          | 0.50            | 12 mois    |
| REVIEW_REQUIRED  | OUI*      | NON                | EXEC_BLOCKED_REVIEW         | 1.00            | 3 mois     |

*Visible à titre diagnostique uniquement — exclu du predictif.

## 4.2 predictive_execution_status — logique

```text
executive_cost_score IS NULL            → EXEC_BLOCKED_REVIEW
eligible_predictive_execution = FALSE   → EXEC_BLOCKED_REVIEW
uncertainty > uncertainty_threshold_max → EXEC_BLOCKED_REVIEW

priority >= 0.75
  AND maturity >= 0.60
  AND status = VALIDATED
  AND uncertainty <= 0.30              → EXEC_READY

priority >= 0.75
  AND maturity >= 0.60
  AND status = PROVISIONAL
  AND uncertainty <= threshold_max     → EXEC_READY_CAUTION

tous les autres cas                    → EXEC_BLOCKED_REVIEW
```

## 4.3 mg.v_cost_model_review_due

Vue de monitoring des révisions. À interroger régulièrement.

```sql
SELECT * FROM mg.v_cost_model_review_due
WHERE review_status IN ('OVERDUE', 'DUE_SOON');
```

| review_status  | Signification                              | Action requise |
|----------------|--------------------------------------------|----------------|
| OVERDUE        | Date de révision dépassée                  | Réviser immédiatement |
| DUE_SOON       | Révision dans les 30 prochains jours       | Planifier la révision |
| ON_TRACK       | Dans les délais                            | Aucune action |

---

# 5. mv_isa_executive_master_board V3

## 5.1 Colonnes nouvelles vs V2

| Colonne V3                      | Remplace / Ajoute          | Description |
|---------------------------------|---------------------------|-------------|
| predictive_execution_status     | predictive_ready_flag (BOOLEAN) | EXEC_READY / EXEC_READY_CAUTION / EXEC_BLOCKED_REVIEW |
| calibration_uncertainty_score   | —                         | Incertitude propagée depuis RF |
| calibration_review_due_date     | —                         | Date de révision propagée depuis RF |
| cost_calibration_status         | —                         | Statut de calibration de la ligne |
| cost_model_coverage_flag        | —                         | Diagnostic couverture cost model |
| review_due_flag                 | —                         | REVIEW_OVERDUE / DUE_SOON / ON_TRACK / NO_DUE_DATE |

## 5.2 cost_model_coverage_flag

| Valeur                      | Signification |
|-----------------------------|---------------|
| COST_MODEL_VALIDATED        | Valeur validée — plein usage |
| COST_MODEL_PROVISIONAL      | Valeur proxy — usage avec flag |
| COST_MODEL_HIGH_UNCERTAINTY | Uncertainty > seuil MG — dégradé |
| COST_MODEL_REVIEW_REQUIRED  | Révision requise — exclu du prédictif |
| COST_MODEL_NOT_COVERED      | Famille non couverte par le cost model |

---

# 6. Trigger trg_cost_model_audit

Le trigger `trg_cost_model_audit` est attaché sur `rf.isa_executive_cost_model`.  
Il trace automatiquement chaque modification de ces champs :

- executive_cost_score
- implementation_complexity
- execution_horizon_years
- execution_maturity_score
- calibration_uncertainty_score
- calibration_status
- calibration_review_due_date
- calibration_source

### Lire le journal

```sql
-- Dernières révisions
SELECT * FROM rf.isa_cost_model_audit_log
ORDER BY revision_date DESC
LIMIT 20;

-- Historique d'un pilier
SELECT * FROM rf.isa_cost_model_audit_log
WHERE pillar_code = 'PGEO'
ORDER BY revision_date DESC;

-- Transitions de statut
SELECT * FROM rf.isa_cost_model_audit_log
WHERE field_revised = 'calibration_status'
ORDER BY revision_date DESC;
```

---

# 7. Procédure de révision

### Quand review_status = OVERDUE

```sql
-- 1. Identifier les lignes à réviser
SELECT * FROM mg.v_cost_model_review_due
WHERE review_status = 'OVERDUE';

-- 2. Mettre à jour la valeur (le trigger logue automatiquement)
UPDATE rf.isa_executive_cost_model
SET
    execution_maturity_score       = <nouvelle_valeur>,
    calibration_uncertainty_score  = <nouvelle_incertitude>,
    calibration_source             = '<nouvelle_source>',
    calibration_status             = 'PROVISIONAL',
    calibration_method             = 'PROXY',
    calibration_date               = CURRENT_DATE,
    calibration_review_due_date    = CURRENT_DATE + INTERVAL '12 months',
    calibration_version            = 'V4'
WHERE intervention_family_code = '<famille>'
  AND pillar_code               = '<pilier>';

-- 3. Rafraîchir la MV
REFRESH MATERIALIZED VIEW ma.mv_isa_executive_master_board;
```

### Passer PROVISIONAL → VALIDATED

Conditions requises :
- Source primaire vérifiée (EXPERT ou LITERATURE)
- `calibration_uncertainty_score` ≤ 0.30
- Révision documentée dans `calibration_source`

```sql
UPDATE rf.isa_executive_cost_model
SET
    calibration_status             = 'VALIDATED',
    calibration_method             = 'EXPERT',   -- ou LITERATURE
    calibration_uncertainty_score  = <valeur_révisée>,
    calibration_source             = '<référence_primaire>',
    calibration_date               = CURRENT_DATE,
    calibration_review_due_date    = CURRENT_DATE + INTERVAL '24 months',
    calibration_version            = 'V4'
WHERE intervention_family_code = '<famille>'
  AND pillar_code               = '<pilier>';
```

---

# 8. Ordre d'exécution

```text
1. db/patch_db/patch_p7k_cost_model_v3.sql
2. db/patch_db/patch_p7k_cost_model_audit_log_v3.sql
3. db/patch_db/patch_p7k_materialized_layer_v3.sql
4. audit/audit_p7k_cost_model_v3.sql
```

Script d'orchestration : `db/run/run_p7k_cost_model_v3.ps1`  
Script de test continu : `db/run/test_p7k_cost_model_v3_dry_run.ps1`

---

# 9. Commit

```bash
git add db/patch_db/patch_p7k_cost_model_v3.sql \
        db/patch_db/patch_p7k_cost_model_audit_log_v3.sql \
        db/patch_db/patch_p7k_materialized_layer_v3.sql \
        audit/audit_p7k_cost_model_v3.sql \
        db/run/run_p7k_cost_model_v3.ps1 \
        db/run/test_p7k_cost_model_v3_dry_run.ps1 \
        README_p7k_cost_model_v3.md

git commit -m "feat(p7k): metrological calibration layer — uncertainty, review_due, predictive_execution_status, MG governance"

git push origin main
```

---

# 10. Transition vers P7Z

P7K Cost Model V3 prépare explicitement P7Z :

- `calibration_uncertainty_score` → pondération des simulations probabilistes
- `predictive_execution_status = EXEC_READY_CAUTION` → candidats P7Z avec intervalle de confiance
- `mg.v_cost_model_review_due` → signal de mise à jour avant lancement P7Z

P7Z devra lire `rf.isa_executive_cost_model` directement  
et propager `calibration_uncertainty_score` dans ses intervalles de confiance.
