# OSA / ISA — P7Z PHASE 2 ENGINE

## Predictive Sovereign Intelligence — Moteur Probabiliste

Version: P7Z_V2  
Status: ACTIVE  
Scope: Moteur probabiliste souverain — exécution, convergence, cascade, fragilité  
Dependencies:
- P7Z Phase 1 (rf.isa_p7z_baseline_registry, rf.isa_p7z_probability_model)
- P7K V3 FROZEN (ma.mv_isa_executive_master_board)
- P7H (ma.v_isa_scenario_simulation_engine)
- P7J v2 (ma.v_isa_decision_priority_engine)
- MG Lineage (mg.isa_view_lineage_registry)

---

# 1. Purpose

P7Z Phase 2 est le moteur probabiliste souverain d'OSA/ISA.

Il répond à quatre questions fondamentales :

1. **Quelle est la probabilité qu'une intervention soit exécutée avec succès ?**
   → `ma.mv_isa_p7z_execution_probability`

2. **En combien d'années un pays peut-il atteindre EXEC_READY_CAUTION ?**
   → `ma.v_isa_p7z_convergence_engine`

3. **Si un pilier défaille, comment la défaillance se propage-t-elle ?**
   → `ma.v_isa_p7z_cascade_propagation`

4. **Quel est le niveau de fragilité souveraine nationale ?**
   → `ma.v_isa_p7z_fragility_engine`

---

# 2. Architecture P7Z Phase 2

```text
RF (paramètres)
  rf.isa_p7z_baseline_registry      ← Phase 1, immuable
  rf.isa_p7z_probability_model      ← Phase 1, calibration par pilier

MG (gouvernance)
  mg.isa_p7z_governance_policy      ← Phase 1, éligibilité
  mg.v_p7z_simulation_eligibility   ← Phase 1, classification
  mg.v_p7z_phase2_readiness         ← Phase 2 NEW, monitoring moteur

MA (calculs — ordre refresh)
  [60] mv_isa_p7z_execution_probability  ← Phase 2 NEW, MV principale
  [70] v_isa_p7z_convergence_engine      ← Phase 2 NEW, lit MV
  [70] v_isa_p7z_cascade_propagation     ← Phase 2 NEW, lit MV
  [80] v_isa_p7z_fragility_engine        ← Phase 2 NEW, lit cascade
```

---

# 3. mv_isa_p7z_execution_probability

MV principale — probabilité d'exécution multi-facteurs.

## 3.1 Composantes de calcul

```text
execution_probability =
    prob_base_corrected        (base - gap*0.40 - uncertainty*penalty + maturity*0.15)
  + prob_scenario_signal       (central_delta*0.50 + stress_delta*0.25 + confidence*0.05)
  + prob_decision_signal       (CRITICAL+0.08 / HIGH+0.04 / STANDARD+0.01 / MONITOR-0.02)
  + prob_pressure_penalty      ((pressure-0.60)*(-0.15) si pressure > 0.60)

Bornes : [0.0, 1.0]
```

## 3.2 Classes de probabilité

| Classe | Seuil | Signification |
|--------|-------|---------------|
| HIGH_PROBABILITY | >= 0.60 | Intervention hautement exécutable |
| MEDIUM_PROBABILITY | >= 0.40 | Exécution probable avec conditions |
| LOW_PROBABILITY | >= 0.20 | Exécution difficile — support requis |
| VERY_LOW_PROBABILITY | < 0.20 | Exécution très incertaine |

## 3.3 Intervalle de confiance

```sql
probability_confidence_interval = calibration_uncertainty_score * 0.25
-- ex: uncertainty=0.20 → IC = ±0.05
-- ex: uncertainty=0.50 → IC = ±0.125
```

---

# 4. v_isa_p7z_convergence_engine

Modélisation temporelle de la convergence vers EXEC_READY_CAUTION.

| Classe | Horizon | Action |
|--------|---------|--------|
| CONVERGENCE_IMMINENT | < 2 ans | Préparer simulation complète |
| CONVERGENCE_SHORT_TERM | < 5 ans | Planifier intervention P7K |
| CONVERGENCE_MEDIUM_TERM | < 10 ans | Programme structurel |
| CONVERGENCE_LONG_TERM | >= 10 ans | Réforme institutionnelle profonde |

```sql
estimated_convergence_years = predictive_gap_score / gap_decay_rate
```

---

# 5. v_isa_p7z_cascade_propagation

Propagation des défaillances entre piliers.

```text
cascade_impact_score = failure_probability * cascade_failure_probability * fragility_weight
pillar_resilience_score = 1 - cascade_impact_score
```

| Classe | Seuil | Signification |
|--------|-------|---------------|
| CASCADE_CRITICAL | >= 0.15 | Intervention systémique urgente |
| CASCADE_HIGH | >= 0.08 | Surveillance renforcée |
| CASCADE_MODERATE | >= 0.04 | Monitoring standard |
| CASCADE_LOW | < 0.04 | Risque contenu |

---

# 6. v_isa_p7z_fragility_engine

Fragilité souveraine nationale agrégée.

```text
sovereign_fragility_index = Σ(cascade_impact_score * fragility_weight) / Σ(fragility_weight)
```

| Classe | Seuil | Signification |
|--------|-------|---------------|
| SOVEREIGN_FRAGILE | >= 0.12 | Intervention systémique nationale urgente |
| SOVEREIGN_VULNERABLE | >= 0.07 | Surveillance nationale renforcée |
| SOVEREIGN_MODERATE | >= 0.03 | Risque modéré — programmes ciblés |
| SOVEREIGN_RESILIENT | < 0.03 | Système souverain absorbant |

---

# 7. Lineage P7Z Phase 2

Phase 2 ajoute 8 entrées dans `mg.isa_view_lineage_registry` (refresh_order 60-80).

```sql
-- Avant tout DROP sur mv_isa_p7z_execution_probability :
SELECT dependent_objects
FROM mg.v_lineage_cascade_risk
WHERE at_risk_object = 'ma.mv_isa_p7z_execution_probability';
-- Retourne : v_isa_p7z_convergence_engine, v_isa_p7z_cascade_propagation
```

---

# 8. Ordre d'exécution

```text
1. db/patch_db/patch_p7z_phase2_engine.sql
```

Scripts :
- `db/run/run_p7z_phase2_engine.ps1`
- `db/run/test_p7z_phase2_dry_run.ps1`

---

# 9. Roadmap P7Z

| Phase | Statut | Contenu |
|-------|--------|---------|
| Phase 1 | ✅ ACTIVE | Baseline, probability model, governance |
| Phase 2 | ✅ ACTIVE | Execution probability, convergence, cascade, fragility |
| Phase 3 | À venir | Sovereign projection multi-scénarios ISA |
| Phase 4 | À venir | Intégration P8 publication layer |

---

# 10. Commit

```bash
git add db/patch_db/patch_p7z_phase2_engine.sql \
        db/run/run_p7z_phase2_engine.ps1 \
        db/run/test_p7z_phase2_dry_run.ps1 \
        README_p7z_phase2_engine.md

git commit -m "feat(p7z): Phase 2 engine — execution probability MV, convergence, cascade propagation, fragility engine"

git push origin main
```
