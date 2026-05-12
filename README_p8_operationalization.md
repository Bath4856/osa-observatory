# P8 — OSA / ISA Operationalization Layer

## Objet

P8 transforme les moteurs P7 en couche institutionnelle de production :

- certification,
- gouvernance de publication,
- snapshots immuables,
- open data,
- premium delivery,
- API registry,
- e-participation.

## Sous-packages

```text
P8A — Certification Engine
P8B — Publication Governance
P8C — Snapshot Freeze
P8D — Open Data Delivery
P8E — Premium Delivery
P8F — API Registry / Gateway Governance
P8G — E-participation
```

## Sources utilisées

P8 s’appuie sur les vues P7E/P7X validées :

```text
ma.v_isa_observed_scores_by_country_year
ma.v_isa_observed_scores_by_pillar
ma.v_isa_observed_scores_by_region_year
ma.v_isa_swot_signal_engine
ma.v_isa_project_opportunity_catalog
ma.v_isa_premium_feasibility_triggers
ma.v_isa_eparticipation_priorities
```

## Principe de robustesse v5

Cette version évite les erreurs de migration précédentes :

- les tables RF de politique P8 sont recréées proprement ;
- les tables MG d’audit/snapshot sont créées sans suppression ;
- les vues utilisent uniquement des colonnes confirmées ;
- aucune dépendance à `observation_confidence` ;
- `policy_code` est toujours explicitement alimenté ;
- dry-run avec contrôle des dépendances, NULL critiques et bornes.

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p8_operationalization.ps1
.\db\run\test_p8_dry_run.ps1
```

## Routes FastAPI incluses

```text
api/routes/isa_public.py
api/routes/premium.py
api/routes/eparticipation.py
api/routes/certification.py
api/routes/publication.py
```

## Commit recommandé

```powershell
git add `
  db/patch_db/patch_p8a_certification_engine.sql `
  db/patch_db/patch_p8b_publication_governance.sql `
  db/patch_db/patch_p8c_snapshot_freeze.sql `
  db/patch_db/patch_p8d_open_data_delivery.sql `
  db/patch_db/patch_p8e_premium_delivery.sql `
  db/patch_db/patch_p8f_api_registry.sql `
  db/patch_db/patch_p8g_eparticipation.sql `
  db/views/ma/v_isa_certification_engine.sql `
  db/views/ma/v_isa_publication_governance.sql `
  db/views/ma/v_isa_snapshot_registry.sql `
  db/views/ma/v_isa_open_data_catalog.sql `
  db/views/ma/v_isa_premium_catalog.sql `
  db/views/ma/v_isa_api_registry.sql `
  db/views/ma/v_isa_eparticipation_queue.sql `
  db/run/run_p8_operationalization.ps1 `
  db/run/test_p8_dry_run.ps1 `
  audit/list_p8_source_columns.sql `
  audit/p8_operationalization_report.sql `
  api/routes/isa_public.py `
  api/routes/premium.py `
  api/routes/eparticipation.py `
  api/routes/certification.py `
  api/routes/publication.py `
  README_p8_operationalization.md

git commit -m "feat(p8): add ISA operationalization layer"

git push origin main
```
