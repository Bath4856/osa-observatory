# OSA / ISA — P4 PMIN INDUSTRIEL

## Objectif

Le chantier P4 transforme PMIN en pilier industriel robuste :

- P4A : USGS physique
- P4B : réserves / potentiel
- P4C : criticité / composites
- P4D : souveraineté extractive

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p4_pmin.ps1
python mapping\activation\patch_p4_pmin_industrial.py
```

Puis recalcul gouvernance :

```powershell
cd G:\osa-observatory\db\run
.\run_mapping_views.ps1
.\run_mapping_maturity.ps1
.\run_mapping_analysis.ps1
```

Choix :
```text
2
4
```

## Export Excel

```powershell
cd G:\osa-observatory
python audit\scripts\export_pmin_industrial_report.py
```
