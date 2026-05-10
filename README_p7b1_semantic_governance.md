# OSA / ISA — P7B1 Semantic Governance Matrix

## Objectif

P7B1 consolide le mapping sémantique P7A en une matrice centrale de gouvernance exploitable par ISA, l’imputation, les moteurs de risque, les vues analytiques et le futur ML.

## Livrables

- `db/patch_db/patch_p7b1_semantic_governance_matrix.sql`
- `db/views/ma/v_semantic_governance_engine.sql`
- `db/views/ma/v_semantic_governance_priority.sql`
- `audit/p7b1_semantic_governance_report.sql`
- `db/run/run_p7b1_semantic_governance.ps1`
- `db/run/test_p7b1_dry_run.ps1`

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7b1_semantic_governance.ps1
```

## Test à blanc

```powershell
.\db\run\test_p7b1_dry_run.ps1
```

## Principe

P7A classe les indicateurs.
P7B1 gouverne les familles sémantiques :

- confiance structurelle ;
- poids souveraineté ;
- volatilité ;
- forecastabilité ;
- politique d’imputation ;
- priorité ML ;
- profil de risque ;
- mode de gouvernance.

## Usage futur

Cette matrice devient la référence transversale pour :

- P7B2 Semantic Confidence Engine ;
- P7B3 Semantic Imputation Policy ;
- P7B4 Forecastability Engine ;
- P8 ML Sovereignty Models ;
- API et frontend OSA/ISA.
