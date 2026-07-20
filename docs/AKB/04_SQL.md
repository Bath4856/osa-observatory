# 04_SQL — Base de données et pipeline analytique

*Section de l'OSA Architecture Knowledge Base (AKB). Source : `db.zip` (390 fichiers : 317 `.sql`, 72 `.ps1`, 1 `.sh`). Établi le 14 juillet 2026. Détail fichier par fichier : `04_SQL_Catalog.xlsx`.*

---

## 1. Les quatre schémas fondateurs

Le socle relationnel de l'OSA repose sur quatre schémas PostgreSQL, déployés dans un ordre de dépendance strict (`01` → `04`), chacun portant sa propre doctrine explicite en en-tête de fichier.

### `rf` — Référentiel canonique (`01_rf_schema.sql`)
**Doctrine déclarée : immuable après déploiement initial — toute modification = nouvelle version versionnée.**

Tables : `rf.regions`, `rf.countries`, `rf.country_blocs`, `rf.regional_blocs`, `rf.pillars`, `rf.units`, `rf.indicators`, `rf.meta_indicators`, `rf.indicator_meta_link`.

### `mm` — Modèle métier (`02_mm_schema.sql`)
Dépend de `rf` (`pillars`, `units`, `indicators`). Tables : `mm.dimensions` (10 axes d'analyse transversaux), `mm.categories`, `mm.super_categories`, `mm.indicator_groups`, `mm.indicator_group_links`, `mm.indicator_methods`, `mm.indicator_method_versions`, `mm.source_origins`.

### `collect` — Ingestion des données (`03_collect_schema.sql`)
**Doctrine déclarée : Python appelle les API, PL/pgSQL ne le fait JAMAIS. `raw_data` partitionné par année (2010 → N).**

Tables : `collect.data_providers`, `collect.provider_endpoints`, `collect.indicator_source`, `collect.raw_data` (+ partitions `raw_data_*`), `collect.ingestion_registry`.

### `ma` — Modèle analytique, pipeline L1→L7 (`04_ma_schema.sql`)
**Doctrine déclarée : toutes les valeurs intermédiaires L1→L7 sont conservées — auditabilité complète — versionné par `method_version_id`.** Note : tables PKI (signature, certificats X.509) désactivées dans ce schéma, activation prévue Phase 4 (Sprint 8).

Tables : `ma.indicator_meta`, `ma.indicator_meta_links`, `ma.indicator_methods`, `ma.indicator_method_versions`, `ma.indicator_values` (+ partitions), `ma.isa_index`, `ma.pillar_scores`.

> Ces quatre doctrines de schéma sont cohérentes avec le Volume 0 : `rf` immuable = Principe 4 (les méthodes constituent un patrimoine) ; `ma` versionné et intégral L1→L7 = Principe 2 (auditabilité) et Principe 5 (provenance des données) appliqués littéralement au niveau du schéma de données.

---

## 2. Le pipeline analytique P7 (A → Z)

Le dossier `patch_db/` (152 fichiers) est structuré autour d'une nomenclature à lettres, **P7A à P7Z**, qui n'apparaît nulle part ailleurs de façon aussi explicite dans les sources chargées. Chaque lettre correspond à une étape de maturation analytique, appliquée en général au-dessus des scores calculés dans `ma` :

| Code | Contenu | Fichiers |
|---|---|---|
| **P7A1-A3** | Taxonomie sémantique, règles de raffinement, finalisation | 3 |
| **P7B1-B6** | Gouvernance sémantique (matrice, moteur de confiance, politiques opérationnelles, prévisibilité, souveraineté, pondération stratégique) | 8 |
| **P7C** | Agrégation dynamique | 1 |
| **P7D** | Scores dynamiques | 1 |
| **P7E** | Publication des observés | 1 |
| **P7F** | Intelligence de diagnostic stratégique | 1 |
| **P7G** | Intelligence de prévision (forecast) | 1 |
| **P7H** | Simulation de scénarios | 1 |
| **P7I** | AMAR/GENECO (alertes, extension, notes méthodologiques, registre, early warning) | 7 |
| **P7J** | Aide à la décision / moteur de recommandation | 3 |
| **P7K** | Modèle de coût, gouvernance exécutive, couche matérialisée | 10 (le plus gros bloc) |
| **P7X** | Intelligence stratégique SWOT | 1 |
| **P7Z** | Fondations et moteur (Phase 1/2) | 2 |

> **P7E** correspond au principe déjà noté dans la mémoire du projet (« pas d'imputation MICE pour les indicateurs TRAJECTOIRE ; L1 doit être suffisamment complet avant de passer à L2 »). **P7I** est le socle SQL du moteur AMAR/GENECO documenté au Chapitre 6 du Volume 0. **P7Z** correspond à la couche prédictive dont l'activation est bloquée jusqu'en avril 2027 (validation du Comité scientifique) — les deux fichiers `p7z_phase1_foundations.sql` et `p7z_phase2_engine.sql` sont donc, à la date de cet inventaire, déployés en base mais **non activés en production**.

Le reste du dossier `patch_db/` (les fichiers ne portant pas de code P7x) couvre des correctifs ponctuels par sprint : modèle utilisateurs (`sprint30_lot_a_affiliates` — voir aussi `gaf.zip`), procédure d'amendement (`create_amendment_d26_sprint20`), classification d'indicateurs, tarification par palier d'affiliation, etc. Le détail complet est dans l'onglet `Patch_DB` du classeur joint.

## 3. Ingestion (`ingest/`, 9 fichiers)

Chargement de données externes vers `collect.raw_data` :

| Source | Fichier(s) | Portée |
|---|---|---|
| ACLED | `ingest_acled_pmin.sql` | Événements de sécurité dans un buffer de 50 km autour des sites miniers |
| Comtrade | `ingest_comtrade_minerals.sql` | Exportations minérales (PMIN) |
| FAO | `ingest_fao_forest.sql` | Foresterie (F3) |
| GFW (Global Forest Watch) | `ingest_gfw_forest.sql`, `ingest_gfw_cod_cog_civ_swz.sql`, `ingest_gfw_complement.sql` | Couverture forestière, complétée pays par pays (F4c/F4d) |
| USGS | `ingest_pmin_physical.sql`, `ingest_usgs_myb.sql` | Indicateurs physiques miniers (MIN_GEO, MIN_CRI, MIN_POT, MIN_RAR) |

Cohérent avec la remarque déjà connue sur `PENV_FOREST_SOVEREIGNTY` (interpolation linéaire Banque Mondiale entre les enquêtes FAO quinquennales, valeur aberrante AGO 2024) : les fichiers `ingest_fao_forest.sql`/`ingest_gfw_*.sql` sont la source SQL exacte de cette chaîne de collecte.

## 4. Vues analytiques (`views/`, 100 fichiers)

`views/ma/` (96 fichiers) concentre l'essentiel : vues et vues matérialisées construites au-dessus du pipeline P7 — gouvernance exécutive (`v_isa_governance_heatmap`), portefeuille de priorités (`v_isa_executive_priority_portfolio`), moteur de scénarios (`v_isa_scenario_policy_engine`), classification (`v_isa_classification`), tendances (`v_isa_trend_5y`), historique (`v_isa_history_analysis`)...

**Limite méthodologique à noter** : 32 des 96 fichiers de `views/ma/` (un tiers) ne portent aucun en-tête de commentaire — le fichier commence directement par `CREATE OR REPLACE VIEW`. Le nom de la vue reste en général suffisamment explicite (ex. `v_isa_governance_heatmap`), mais si le contenu exact d'une vue précise importe pour une décision, il faudra l'ouvrir individuellement plutôt que se fier à ce catalogue seul.

`views/mg/` (2 fichiers) porte les vues du schéma `mg` (gouvernance/identité — cohérent avec `mg.affiliates`, `mg.identity_events` déjà rencontrés en `03_ADR`).

## 5. Orchestration (`run/`, 72 scripts PowerShell)

Scripts Windows PowerShell qui exécutent, dans l'ordre, les patches SQL d'une phase donnée — préfixes récurrents : `p_foundation*`, `pa_semantic*`, `p_mapping*`, `p_full_governance*`, `p_trust_engine*`, `p_pmin*`, `p_zero_orphans*`, souvent accompagnés d'une variante `test_*` ou `*_dry_run` pour validation à sec avant exécution réelle. Cohérent avec la pratique déjà connue : Windows/PowerShell côté poste de travail (`G:\osa-observatory`), Docker/psql côté VPS.

## 6. Autres dossiers

- **`requete_db/`** (8 fichiers) — requêtes ad hoc, hors migration.
- **`to_indicator_value/`** (4), **`reports/`** (1) — utilitaires ponctuels de conversion/reporting.
- **`backup.sh`** — seul fichier `.sh` du dépôt ; script de sauvegarde, cohérent avec la routine documentée par ailleurs (`osa_backup.sh`, cron 02:00 UTC, rClone vers Infomaniak Swiss Backup).

## 7. Ce que cette section n'a pas fait

Avec 389 fichiers analysés automatiquement, cette section décrit l'architecture et catalogue chaque fichier (nom, taille, objets SQL créés, description extraite), mais **ne rejoue et ne valide aucun script**. Une revue fichier par fichier des 152 patches ou des 96 vues, pour vérifier leur cohérence mutuelle ou détecter d'éventuels conflits de nommage (comme celui déjà connu entre les deux tables homonymes de rate-limiting), resterait à faire séparément si nécessaire.
