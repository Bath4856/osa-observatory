# P8 V2 — Lot 0 + Lot 1

## Objet

Démarrer la transition contrôlée :

```text
P8 OPS → P8 V2 Institutional Public Observatory
```

Aucune suppression.  
P8OPS devient `LEGACY_ACTIVE`.  
P8V2 devient `ACTIVE_CANDIDATE`.

## Contenu

```text
audit/p8_ops_inventory.sql
audit/list_p8_v2_source_columns.sql
audit/p8_v2_foundation_report.sql

db/patch_db/patch_p8_v2_foundation.sql

db/run/run_p8_v2_foundation.ps1
db/run/test_p8_v2_foundation_dry_run.ps1
```

## Exécution

```powershell
cd G:\osa-observatory

.\db\run\run_p8_v2_foundation.ps1
.\db\run\test_p8_v2_foundation_dry_run.ps1
```

## Créations

Schemas :

```text
pub
archive
```

Tables :

```text
mg.release_registry
mg.asset_registry
mg.publication_registry
mg.api_contract_registry
mg.publication_audit_log
```

## Étape suivante

Lot 2 — vues publiques `pub.*`.
