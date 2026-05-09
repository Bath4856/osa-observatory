# OSA / ISA — Mapping Governance Workflow

## Objectif

Ce paquet met en place :

1. `rf.indicator_nature`
2. le patch P3 PRES/PTRA
3. la vue `ma.v_mapping_maturity`
4. le rapport SQL `audit/mapping_maturity_report.sql`
5. les exports Excel mapping analysis et maturity
6. les scripts PowerShell d'orchestration.

## Fichiers

```text
db/patch_db/patch_p3_physical_mapping.sql
db/views/ma/v_mapping_maturity.sql
db/run/run_p3_mapping.ps1
db/run/run_mapping_maturity.ps1
db/run/run_full_mapping_governance.ps1
mapping/activation/patch_p3_pres_ptra_fast.py
audit/mapping_maturity_report.sql
audit/scripts/export_mapping_analysis_v3.py
audit/scripts/export_mapping_maturity.py
```

## Exécution pas à pas

### 1. Appliquer le patch P3

```powershell
cd G:\osa-observatory
.\db\run\run_p3_mapping.ps1
```

### 2. Tester les APIs P3

```powershell
cd G:\osa-observatory
python mapping/activation/patch_p3_pres_ptra_fast.py
```

### 3. Réinstaller les vues mapping existantes

```powershell
cd G:\osa-observatory\db\run
.\run_mapping_views.ps1
```

### 4. Installer la vue maturité et lancer le rapport

```powershell
cd G:\osa-observatory\db\run
.\run_mapping_maturity.ps1
```

### 5. Relancer l'analyse qualité

```powershell
cd G:\osa-observatory\db\run
.\run_mapping_analysis.ps1
```

Choix : `2` puis `4`.

### 6. Exporter les fichiers Excel

```powershell
cd G:\osa-observatory
python audit/scripts/export_mapping_analysis_v3.py
python audit/scripts/export_mapping_maturity.py
```

## Exécution complète

```powershell
cd G:\osa-observatory
.\db\run\run_full_mapping_governance.ps1
```

## Git

```powershell
git add db/patch_db/patch_p3_physical_mapping.sql `
        db/views/ma/v_mapping_maturity.sql `
        db/run/run_p3_mapping.ps1 `
        db/run/run_mapping_maturity.ps1 `
        db/run/run_full_mapping_governance.ps1 `
        mapping/activation/patch_p3_pres_ptra_fast.py `
        audit/mapping_maturity_report.sql `
        audit/scripts/export_mapping_analysis_v3.py `
        audit/scripts/export_mapping_maturity.py `
        README_mapping_governance_workflow.md

git commit -m "feat(mapping): add P3 physical mapping and maturity governance"
git push origin main
```

## Résultat attendu

```text
Orphelins : 48 → environ 38
PRES      : hausse notable
PTRA      : hausse notable
```

`PTRA_RD_QUALITY` restera en WARN/PILOT car c'est une source WEF/GCI manuelle.
