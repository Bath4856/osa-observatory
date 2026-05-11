# P7B6 — Semantic Strategic Weighting Engine

## Objectif

P7B6 transforme les sorties P7B1→P7B5 en pondérations stratégiques dynamiques :

- poids ISA dynamique ;
- poids ML dynamique ;
- poids forecast dynamique ;
- poids souveraineté dynamique ;
- poids de vulnérabilité systémique.

La logique cible devient :

```text
ISA = Σ(indicateur × poids_stratégique_dynamique)
```

et non plus :

```text
ISA = Σ(indicateur × poids_fixe)
```

## Dépendance unique principale

P7B6 s'appuie sur le contrat validé :

```text
ma.v_semantic_sovereignty_engine
```

Ce choix évite les colonnes incertaines issues de couches plus anciennes.

## Livrables

```text
db/patch_db/patch_p7b6_semantic_strategic_weighting.sql
db/views/ma/v_semantic_strategic_weighting_engine.sql
db/views/ma/v_isa_dynamic_weighting_readiness.sql
audit/p7b6_semantic_strategic_weighting_report.sql
db/run/run_p7b6_semantic_strategic_weighting.ps1
db/run/test_p7b6_dry_run.ps1
README_p7b6_semantic_strategic_weighting.md
```

## Installation

```powershell
cd G:\osa-observatory
.\db\run\run_p7b6_semantic_strategic_weighting.ps1
```

## Test

```powershell
.\db\run\test_p7b6_dry_run.ps1
```

Le runner effectue un pré-test des dépendances et des colonnes minimales avant de créer les vues métier.

## Sorties principales

### `ma.v_semantic_strategic_weighting_engine`

Produit, par indicateur :

- `isa_dynamic_weight`
- `ml_dynamic_weight`
- `forecast_dynamic_weight`
- `sovereignty_dynamic_weight`
- `systemic_vulnerability_weight`
- `strategic_weighting_class`
- `isa_weighting_decision`
- `ml_weighting_decision`
- `forecast_weighting_decision`

### `ma.v_isa_dynamic_weighting_readiness`

Produit, par pilier et famille sémantique :

- moyenne des poids dynamiques ;
- nombre de signaux core, monitored, vulnerability, locked gap ;
- statut de préparation à la pondération dynamique ISA.

## Doctrine

P7B6 ne supprime aucun signal. Il transforme chaque signal en poids opérationnel :

- signal souverain fort → poids ISA central ;
- signal contrôlé → poids ISA contrôlé ;
- signal verrouillé → poids de gap structurel ;
- événement / pression / dépendance → poids de vulnérabilité ;
- signal non forecastable → poids forecast nul, mais signal contextuel conservé.
