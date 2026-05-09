# OSA / ISA — P5 Zero Orphans Workflow

## Objectif
Résoudre les 13 derniers indicateurs orphelins détectés après P4.

## Lots

- P5A : PMIL sécurité
- P5B : PHUM structurel
- P5C : hybrides finaux

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p5_zero_orphans.ps1
python mapping\activation\patch_p5_zero_orphans.py
```

Puis :

```powershell
cd G:\osa-observatory\db\run
.\run_mapping_views.ps1
.\run_mapping_maturity.ps1
.\run_mapping_analysis.ps1
```

Tester options :

```text
2
4
```

## Rapport SQL

```powershell
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -d osa_db -f "G:\osa-observatory\audit\orphan_resolution_report.sql"
```

## Export Excel

```powershell
cd G:\osa-observatory
python audit\scripts\export_orphan_resolution_report.py
```

## Git

```powershell
git add db/patch_db/patch_p5a_pmil_security.sql db/patch_db/patch_p5b_phum_structural.sql db/patch_db/patch_p5c_hybrids_final.sql db/views/ma/v_orphan_resolution_status.sql db/run/run_p5_zero_orphans.ps1 db/run/run_p5_full_governance.ps1 mapping/activation/patch_p5_zero_orphans.py mapping/activation/test_p5_zero_orphans_results.json audit/orphan_resolution_report.sql audit/scripts/export_orphan_resolution_report.py README_p5_zero_orphans_workflow.md
git commit -m "feat(mapping): resolve P5 zero orphan indicators"
git push origin main
```
