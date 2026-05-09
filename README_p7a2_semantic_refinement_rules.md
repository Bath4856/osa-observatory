# OSA / ISA — P7A2 Semantic Refinement Rules

## Objectif

P7A2 affine la classification sémantique produite par P7A1.

P7A1 garantit qu'aucun indicateur ne reste sans classe sémantique.
P7A2 transforme les classifications faibles `PILLAR_DEFAULT_HEURISTIC` en règles métier ISA explicites.

## Livrables

- `db/patch_db/patch_p7a2_semantic_refinement_rules.sql`
- `db/views/ma/v_signal_semantic_engine_v2.sql`
- `db/run/run_p7a2_semantic_refinement.ps1`
- `db/run/test_p7a2_dry_run.ps1`
- `audit/p7a2_semantic_refinement_report.sql`

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7a2_semantic_refinement.ps1
```

## Test à blanc

```powershell
cd G:\osa-observatory
.\db\run\test_p7a2_dry_run.ps1
```

## Principe

La priorité des classifications devient :

1. Règle explicite P7A2
2. Nature gouvernée RF
3. Pattern code P7A1
4. Défaut pilier P7A1

## Objectif attendu

Réduire :

```text
REVIEW_RECOMMENDED : 143 → < 80
```

P7A2 ne supprime aucune information. Il améliore la sémantique et la confiance du signal.
