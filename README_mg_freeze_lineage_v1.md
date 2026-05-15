# OSA / ISA — MG FREEZE & LINEAGE V1

## Gouvernance Institutionnelle des Modèles

Version: MG_V1  
Status: PRODUCTION_READY  
Scope: Freeze P7K V3 + Lineage des dépendances MA/RF/MG  
Dependencies:
- P7K V3 (patch_p7k_cost_model_v3.sql)
- P7K Views Restore V3 (patch_p7k_views_restore_v3.sql)
- rf.package_lifecycle
- ma.mv_isa_executive_master_board

---

# 1. Purpose

MG Freeze & Lineage V1 introduit deux mécanismes de gouvernance institutionnelle :

**Freeze** : garantit l'intégrité de la baseline P7K V3. Un package FROZEN ne peut être modifié sans UNFREEZE explicite et traçable.

**Lineage** : documente toutes les dépendances entre objets MA/RF/MG. Permet de déterminer l'ordre de recréation sûr et d'identifier les objets à risque DROP CASCADE avant toute intervention.

---

# 2. Architecture MG

```text
mg.isa_package_freeze_registry      — état de gel des packages
mg.isa_view_lineage_registry        — dépendances entre objets
mg.v_lineage_dependency_chain       — navigation des chaînes
mg.v_lineage_refresh_order          — ordre de recalcul sûr
mg.v_lineage_cascade_risk           — objets à risque DROP CASCADE
```

---

# 3. Freeze P7K V3

## 3.1 mg.isa_package_freeze_registry

| Colonne               | Description |
|-----------------------|-------------|
| package_code          | Code package (P7K) |
| package_version       | Version gelée (V3) |
| freeze_status         | FROZEN / UNFROZEN / DEPRECATED |
| freeze_date           | Date et heure du gel |
| frozen_by             | Auteur du gel |
| freeze_note           | Description de la baseline gelée |
| snapshot_rows         | Lignes MV au moment du freeze |
| snapshot_countries    | Pays couverts au freeze |
| snapshot_audit_status | Statut audit au freeze (AUDIT_OK) |

## 3.2 Snapshot P7K V3 gelé

| Métrique           | Valeur |
|--------------------|--------|
| rows               | 8091   |
| countries          | 54     |
| years              | 15     |
| pillars            | 10     |
| audit_status       | AUDIT_OK |
| min_predictive_gap | 0.050  |

## 3.3 Procédure UNFREEZE

À utiliser uniquement pour corrections critiques ou upgrade vers V4.

```sql
-- 1. Enregistrer le motif de dégel
UPDATE mg.isa_package_freeze_registry
SET
    freeze_status  = 'UNFROZEN',
    unfrozen_date  = NOW(),
    freeze_note    = freeze_note || ' | UNFROZEN: <motif>'
WHERE package_code = 'P7K'
  AND package_version = 'V3';

-- 2. Mettre à jour package_lifecycle
UPDATE rf.package_lifecycle
SET package_status = 'ACTIVE',
    updated_at     = NOW()
WHERE package_code = 'P7K';
```

Après modifications, regeler avec une version incrémentée (V4).

---

# 4. Lineage MG

## 4.1 Principe

Chaque ligne de `mg.isa_view_lineage_registry` représente une dépendance directe entre deux objets. Le `refresh_order` définit l'ordre de recréation sûr.

| refresh_order | Niveau           | Objets |
|---------------|-----------------|--------|
| 1–9           | Tables RF base   | isa_executive_cost_model, trigger |
| 10–19         | Sources P7K      | v_p7k_executive_source |
| 20–29         | Portfolio        | v_isa_executive_priority_portfolio |
| 30            | MV centrale      | mv_isa_executive_master_board |
| 40–49         | Vues dép. MV     | v_isa_executive_cost_projection, v_isa_executive_master_board |
| 50–59         | Vues dép. niveau 5 | v_isa_predictive_readiness_registry |

## 4.2 Objets à risque CASCADE HIGH

```sql
-- Avant tout DROP, consulter :
SELECT * FROM mg.v_lineage_cascade_risk
ORDER BY nb_dependents DESC;
```

| Objet à risque                        | Victimes CASCADE |
|---------------------------------------|-----------------|
| mv_isa_executive_master_board         | 3 vues          |
| v_isa_executive_priority_portfolio    | 6 vues          |
| v_isa_executive_master_board          | 1 vue           |

## 4.3 Ordre de recréation sûr

```sql
-- Ordre complet de recréation après DROP
SELECT refresh_order, schema_name, object_name, object_type, depends_on
FROM mg.v_lineage_refresh_order
ORDER BY refresh_order;
```

## 4.4 Protocole DROP sécurisé

Avant tout DROP sur un objet P7K :

```sql
-- Étape 1 : identifier les victimes CASCADE
SELECT dependent_objects
FROM mg.v_lineage_cascade_risk
WHERE at_risk_object = 'ma.<objet_à_dropper>';

-- Étape 2 : noter le refresh_order max des victimes
SELECT MAX(refresh_order)
FROM mg.v_lineage_dependency_chain
WHERE target_object_full = 'ma.<objet_à_dropper>';

-- Étape 3 : recréer dans l'ordre après DROP
-- Suivre mg.v_lineage_refresh_order
```

---

# 5. Vues MG de navigation

### v_lineage_dependency_chain
Toutes les dépendances triées par refresh_order.
```sql
SELECT * FROM mg.v_lineage_dependency_chain
WHERE cascade_risk = 'HIGH';
```

### v_lineage_refresh_order
Ordre de recréation sûr avec liste des dépendances.
```sql
SELECT * FROM mg.v_lineage_refresh_order;
```

### v_lineage_cascade_risk
Objets dont le DROP entraîne un CASCADE.
```sql
SELECT * FROM mg.v_lineage_cascade_risk;
```

---

# 6. Ordre d'exécution

```text
1. db/patch_db/patch_mg_freeze_lineage_v1.sql
```

Script d'orchestration : `db/run/run_mg_freeze_lineage_v1.ps1`

---

# 7. Commit

```bash
git add db/patch_db/patch_mg_freeze_lineage_v1.sql \
        db/run/run_mg_freeze_lineage_v1.ps1 \
        README_mg_freeze_lineage_v1.md

git commit -m "feat(mg): freeze P7K V3 baseline + view lineage registry with cascade risk and refresh order"

git push origin main
```

---

# 8. Extension future

Le lineage V1 couvre P7K. Les sprints suivants ajouteront :

| Sprint | Extension lineage |
|--------|-------------------|
| P7Z    | Dépendances simulations probabilistes |
| P8     | Dépendances publication pub.* |
| MG V2  | Lineage automatique via pg_depend |
