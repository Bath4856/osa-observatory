# OSA / ISA — P7Z PHASE 1 FOUNDATIONS

## Predictive Sovereign Intelligence — Fondations

Version: P7Z_V1  
Status: ACTIVE  
Scope: Fondations du moteur probabiliste souverain  
Dependencies:
- P7K V3 FROZEN (mg.isa_package_freeze_registry)
- ma.mv_isa_executive_master_board (predictive_gap_score, calibration_uncertainty_score)
- mg.isa_model_governance_policy
- mg.isa_view_lineage_registry

---

# 1. Purpose

P7Z Phase 1 pose les fondations du moteur probabiliste souverain OSA/ISA.

Il ne calcule pas encore de simulations complètes — c'est le rôle de P7Z Phase 2.
Il établit :
- la **baseline de référence** : snapshot des gaps prédictifs P7K V3 au lancement
- le **modèle de probabilité** : paramètres de convergence et fragilité par pilier
- la **gouvernance d'éligibilité** : règles définissant ce que P7Z peut calculer

P7Z Phase 1 répond à la question :
**Quelles interventions africaines sont prêtes pour une simulation probabiliste, et avec quel niveau de confiance ?**

---

# 2. Architecture P7Z

```text
RF  — paramètres scientifiques P7Z
      rf.isa_p7z_baseline_registry      (snapshot gaps P7K V3)
      rf.isa_p7z_probability_model      (paramètres probabilistes par pilier)

MG  — gouvernance P7Z
      mg.isa_p7z_governance_policy      (règles d'éligibilité)
      mg.v_p7z_simulation_eligibility   (vue des lignes éligibles)

MA  — Phase 2 (à venir)
      ma.mv_isa_p7z_execution_probability
      ma.v_isa_p7z_cascade_propagation
      ma.v_isa_p7z_fragility_engine
      ma.v_isa_p7z_sovereign_projection
```

### Ce que P7Z consomme depuis P7K V3

| Source P7K V3                  | Utilisé par P7Z pour |
|-------------------------------|---------------------|
| predictive_gap_score           | Variable cible de convergence |
| calibration_uncertainty_score  | Pénalité de probabilité |
| execution_maturity_score       | Seuil d'éligibilité |
| sovereign_execution_pressure   | Base fragilité systémique |
| predictive_execution_status    | Classification initiale |

---

# 3. rf.isa_p7z_baseline_registry

Snapshot immuable de l'état P7K V3 au lancement P7Z.

**Ne jamais modifier après insertion.**

```sql
-- Lire la baseline
SELECT pillar_code,
       ROUND(AVG(predictive_gap_score),3) AS avg_gap,
       ROUND(MIN(predictive_gap_score),3) AS min_gap
FROM rf.isa_p7z_baseline_registry
GROUP BY pillar_code
ORDER BY avg_gap;
```

---

# 4. rf.isa_p7z_probability_model

Paramètres du moteur probabiliste par pilier.

| Colonne                      | Description |
|-----------------------------|-------------|
| gap_decay_rate               | Vitesse naturelle de réduction du gap [0–1/an] |
| convergence_horizon_years    | Années estimées pour atteindre EXEC_READY_CAUTION |
| systemic_fragility_weight    | Poids dans la fragilité souveraine globale |
| cascade_failure_probability  | Probabilité de propagation à d'autres piliers |
| execution_probability_base   | Probabilité de base avant corrections |
| uncertainty_penalty          | Réduction par unité d'uncertainty |

### Valeurs V1 — synthèse

| Pilier | Decay | Conv. ans | Fragilité | Cascade |
|--------|-------|-----------|-----------|---------|
| PRES   | 0.080 | 3.1       | 0.15      | 0.25    |
| PMON   | 0.065 | 4.5       | 0.18      | 0.35    |
| PNUM   | 0.075 | 3.7       | 0.12      | 0.20    |
| PTRA   | 0.055 | 5.5       | 0.14      | 0.30    |
| PHUM   | 0.045 | 8.2       | 0.16      | 0.28    |
| PECO   | 0.050 | 6.9       | 0.17      | 0.32    |
| PENV   | 0.048 | 7.3       | 0.13      | 0.22    |
| PMIL   | 0.035 | 11.0      | 0.20      | 0.55    |
| PMIN   | 0.040 | 9.5       | 0.15      | 0.38    |
| PGEO   | 0.025 | 18.8      | 0.22      | 0.65    |

PGEO a la convergence la plus lente (18.8 ans) et la cascade la plus élevée (0.65) — cohérent avec le WGI le plus faible du continent.

---

# 5. Gouvernance P7Z — 3 classes d'éligibilité

| Classe                  | gap max | uncertainty max | maturity min | Modules activés |
|------------------------|---------|-----------------|--------------|-----------------|
| P7Z_SIMULATION_READY   | 0.15    | 0.30            | 0.55         | Tous (4/4) |
| P7Z_SIMULATION_PARTIAL | 0.35    | 0.50            | 0.40         | Convergence + Fragilité |
| P7Z_MONITORING_ONLY    | —       | —               | —            | Aucun |

### Modules P7Z Phase 2

| Module                     | Classe requise |
|---------------------------|----------------|
| Convergence modelling      | PARTIAL ou READY |
| Cascade failure modelling  | READY uniquement |
| Fragility scoring          | PARTIAL ou READY |
| ISA projection             | READY uniquement |

---

# 6. mg.v_p7z_simulation_eligibility

Vue principale de monitoring P7Z.

```sql
-- Distribution par pilier
SELECT pillar_code, p7z_eligibility_class, COUNT(*),
       ROUND(AVG(estimated_execution_probability),3) AS avg_prob
FROM mg.v_p7z_simulation_eligibility
GROUP BY pillar_code, p7z_eligibility_class
ORDER BY pillar_code;

-- Top candidats prêts
SELECT country_iso3, year, pillar_code,
       predictive_gap_score, estimated_execution_probability
FROM mg.v_p7z_simulation_eligibility
WHERE p7z_eligibility_class = 'P7Z_SIMULATION_READY'
ORDER BY estimated_execution_probability DESC;
```

---

# 7. Ordre d'exécution

```text
1. db/patch_db/patch_mg_check_helpers.sql    (fonctions helper pg_matviews)
2. db/patch_db/patch_p7z_phase1_foundations.sql
```

Script : `db/run/run_p7z_phase1_foundations.ps1`

---

# 8. Roadmap P7Z

| Phase | Contenu | Prérequis |
|-------|---------|-----------|
| Phase 1 (actuelle) | Baseline, probability model, governance | P7K V3 FROZEN |
| Phase 2 | Moteur probabiliste — execution probability MV | Phase 1 |
| Phase 3 | Cascade propagation + fragility engine | Phase 2 |
| Phase 4 | Sovereign projection multi-scénarios + P8 | Phase 3 |

---

# 9. Commit

```bash
git add db/patch_db/patch_mg_check_helpers.sql \
        db/patch_db/patch_p7z_phase1_foundations.sql \
        db/run/run_p7z_phase1_foundations.ps1 \
        README_p7z_phase1_foundations.md

git commit -m "feat(p7z): Phase 1 foundations — baseline registry, probability model, governance policy, simulation eligibility"

git push origin main
```
