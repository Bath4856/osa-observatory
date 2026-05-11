# P7B3 — Semantic Operational Policies

## Objectif

P7B3 transforme la gouvernance sémantique P7B1 et la confiance dynamique P7B2 en décisions opérationnelles ISA :

- inclusion ISA sans exclusion abusive ;
- règles L2 d'imputation ;
- règles de normalisation et agrégation ;
- pondération ISA sémantique ;
- priorisation ML ;
- verrouillage des signaux physiques non certifiés.

## Fichiers

```text
db/patch_db/patch_p7b3_semantic_operational_policies.sql
db/views/ma/v_semantic_operational_policy_engine.sql
db/views/ma/v_isa_semantic_operations.sql
audit/p7b3_semantic_operational_report.sql
db/run/run_p7b3_semantic_operational.ps1
db/run/test_p7b3_dry_run.ps1
README_p7b3_semantic_operational_policies.md
```

## Dépendances

P7B3 suppose que ces objets existent :

```text
ma.v_semantic_confidence_engine
rf.semantic_governance_matrix
rf.semantic_confidence_policy
```

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7b3_semantic_operational.ps1
.\db\run\test_p7b3_dry_run.ps1
```

## Philosophie

P7B3 ne supprime aucun indicateur. Il transforme les signaux faibles en décisions :

- `ISA_INCLUDE_AS_GAP_LOCKED`
- `ISA_INCLUDE_AS_WEAK_SIGNAL`
- `ISA_INCLUDE_CONFIDENCE_WEIGHTED`
- `NO_IMPUTATION_CERTIFICATION_REQUIRED`
- `ML_USE_AS_CONTEXT_ONLY`
- `ML_FEATURE_HIGH_PRIORITY`

## Commit recommandé

```powershell
git add `
  db/patch_db/patch_p7b3_semantic_operational_policies.sql `
  db/views/ma/v_semantic_operational_policy_engine.sql `
  db/views/ma/v_isa_semantic_operations.sql `
  db/run/run_p7b3_semantic_operational.ps1 `
  db/run/test_p7b3_dry_run.ps1 `
  audit/p7b3_semantic_operational_report.sql `
  README_p7b3_semantic_operational_policies.md

git commit -m "feat(p7): add semantic operational policies"
git push origin main
```
