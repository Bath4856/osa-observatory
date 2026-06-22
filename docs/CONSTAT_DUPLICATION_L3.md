# CONSTAT — Duplication massive en L3 (ma.indicator_values) et impact sur les scores ISA publiés

**Découvert** : Sprint 23, lors de la correction ENV_FOR (effet de bord, hors périmètre initial)
**Statut** : non corrigé — document de constat uniquement, aucune action engagée sur ce sujet
**Sévérité** : CRITIQUE — impact direct suspecté sur les scores SOV_* publiés en accès anticipé 2010-2024

---

## 1. Résumé

La table `ma.indicator_values` contient, pour la couche L3 (normalisation, `layer_id=3`),
un nombre de lignes largement supérieur à la grille attendue (54 pays × 15 années = 810
combinaisons par indicateur). Les doublons portent des valeurs identiques pour un même
`(indicator_code, country_iso3, year)`.

La fonction `ma.compute_pillar_score` agrège ces lignes via :

```sql
SUM(iv.processed_value * ml.weight) AS score
```

`SUM` n'est pas idempotent face aux doublons : chaque ligne dupliquée est comptée une
fois de plus dans la somme. Le résultat est ensuite tronqué par :

```sql
LEAST(1.0, GREATEST(0.0, SUM(...)))
```

Le `LEAST(1.0, ...)` **masque silencieusement** toute sur-sommation : un score qui
devrait être, par exemple, 1.8 (du fait d'une duplication ~2x) ou 6.4 (duplication
~6x) est ramené à 1.0 sans aucune trace de l'anomalie sous-jacente.

## 2. Preuves chiffrées

### 2.1 Ampleur de la duplication (L3, tous indicateurs)

Requête exécutée sur `osa_db` (Sprint 23) :

```sql
SELECT indicator_code, layer_id, COUNT(*) AS total,
       COUNT(*) - COUNT(DISTINCT (country_iso3,year)) AS doublons_estimes
FROM ma.indicator_values
GROUP BY indicator_code, layer_id
HAVING COUNT(*) - COUNT(DISTINCT (country_iso3,year)) > 0
ORDER BY doublons_estimes DESC
LIMIT 15;
```

Résultat (extrait, 15 indicateurs les plus touchés, tous en `layer_id=3`) :

| indicator_code        | total  | doublons_estimes | ratio approx. |
|------------------------|--------|-------------------|----------------|
| MIN_PRD_ALU            | 19 915 | 19 105            | ~24.6x         |
| PTRA_LOG_LPI           | 19 704 | 18 894            | ~24.3x         |
| MIN_PRD_GOL            | 19 685 | 18 875            | ~24.3x         |
| HUM_POV                | 18 408 | 17 598            | ~22.7x         |
| MIN_PRD_IRN            | 14 825 | 14 015            | ~18.3x         |
| PMIL_HOMICIDE_RATE     | 14 159 | 13 349            | ~17.5x         |
| MIN_PMIN_SITE          | 13 710 | 12 900            | ~16.9x         |
| GEO_SOVEREIGN_MARGIN   | 13 473 | 12 663            | ~16.6x         |
| ECO_PUBLIC_LEAKAGE     | 13 473 | 12 663            | ~16.6x         |
| PNUM_TERTIARY_ENROLL   | 13 197 | 12 387            | ~16.3x         |
| MIN_PRD_CHR            | 12 555 | 11 745            | ~15.5x         |
| MIN_VAL                | 12 515 | 11 705            | ~15.4x         |
| ECO_TAX_EFFICIENCY     | 12 217 | 11 422            | ~15.1x         |
| ECO_EXB                | 11 678 | 10 868            | ~14.4x         |
| MIN_PRD_COP            | 11 550 | 10 740            | ~14.2x         |

Pour comparaison, ENV_FOR (cas ayant déclenché la découverte) :

| layer_id | total | combos distincts (54×15=810 attendu) | ratio |
|----------|-------|----------------------------------------|-------|
| 1        | 797   | 797                                     | 1.0x (sain) |
| 2        | 1662  | 810                                     | ~2.05x |
| 3        | 5244  | 810                                     | ~6.47x |

ENV_FOR est donc dans la fourchette **basse** des indicateurs affectés — la liste ci-dessus
montre des ratios bien supérieurs (jusqu'à ~24.6x).

### 2.2 Cas détaillé — AGO / ENV_FOR / 2010

```sql
SELECT layer_id, source_id, method_version_id, COUNT(*)
FROM ma.indicator_values
WHERE indicator_code = 'ENV_FOR' AND country_iso3='AGO' AND year=2010
GROUP BY layer_id, source_id, method_version_id;
```

| layer_id | source_id | method_version_id | count |
|----------|-----------|---------------------|-------|
| 1        | 11        | NULL                | 1     |
| 2        | 11        | NULL                | 1     |
| 2        | NULL      | NULL                | 1     |
| 3        | NULL      | NULL                | 6     |

### 2.3 Impact sur les scores publiés — `ma.pillar_scores`

```sql
SELECT pillar_code, year, COUNT(*) AS nb_pays,
       COUNT(*) FILTER (WHERE score >= 0.999) AS nb_a_1,
       ROUND(AVG(score),3) AS score_moyen
FROM ma.pillar_scores
WHERE method_version_id = 1
GROUP BY pillar_code, year
ORDER BY pillar_code, year;
```

Synthèse (150 lignes, 10 piliers × 15 années) :

| Pilier | Comportement observé 2010-2024 |
|--------|----------------------------------|
| PENV   | score moyen 0.996–1.000, 52–54/54 pays à ≥0.999 — **plafonné quasi systématiquement** |
| PHUM   | score moyen ~1.000, 52–54/54 pays — **plafonné quasi systématiquement** |
| PMIL   | score moyen 0.991–1.000, tendance croissante vers 54/54 — **plafonné** |
| PMON   | score moyen ~1.000, 53–54/54 pays — **plafonné quasi systématiquement** |
| PMIN   | score moyen 0.995–1.000, 51–54/54 pays — **plafonné quasi systématiquement** |
| PRES   | score moyen 0.994–1.000, 52–54/54 pays — **plafonné quasi systématiquement** |
| PTRA   | score moyen 0.997–1.000, 52–54/54 pays — **plafonné quasi systématiquement** |
| PNUM   | score moyen 0.720 (2010) → 1.000 (2021-2024) — **convergence progressive vers le plafond** |
| PECO   | score moyen 0.952–0.975, 45–49/54 pays à ≥0.999 — proche du plafond mais pas systématique |
| PGEO   | score moyen 0.44–0.52, **0 pays à ≥0.999** — semble épargné |

**8 piliers sur 10** présentent un comportement de plafonnement quasi-systématique sur
tout ou partie de la période 2010-2024. Un score de souveraineté moyen de 1.000 sur
54/54 pays pendant 15 ans est incompatible avec la définition même de l'ISA
(hétérogénéité attendue entre 54 états sur 10 dimensions comportementales).

PGEO (et dans une moindre mesure PECO) semblent ne pas atteindre le plafond — à
vérifier si ces piliers ont des indicateurs moins/pas affectés par la duplication L3,
ou si leurs poids (`ml.weight`) sont suffisamment faibles pour que même une
sur-sommation ×2 à ×6 reste sous 1.0. Leur apparente normalité ne garantit donc PAS
qu'ils soient indemnes du même défaut structurel.

## 3. Cause racine identifiée

### 3.1 Contrainte UNIQUE inopérante

```sql
-- db/04_ma_schema.sql
CREATE TABLE IF NOT EXISTS ma.indicator_values (
    ...
    method_version_id   INT REFERENCES ma.indicator_method_versions(id),
    ...
    UNIQUE (indicator_code, country_iso3, year, layer_id, method_version_id)
)
```

En PostgreSQL (norme SQL), `NULL` n'est jamais égal à `NULL`. Une contrainte `UNIQUE`
portant sur un jeu de colonnes incluant une colonne `NULL` **n'empêche pas les
doublons** sur cette colonne : chaque ligne avec `method_version_id IS NULL` est
traitée comme distincte, quelle que soit la valeur des autres colonnes.

Or les lignes L3 dupliquées ont systématiquement `method_version_id IS NULL`
(cf. §2.2). La contrainte `UNIQUE` est donc **silencieusement inopérante** pour ces
lignes.

### 3.2 `ON CONFLICT DO NOTHING` sans effet

`db/fix_normalize_indicator_v2.sql` (et probablement d'autres scripts produisant L3)
utilisent `ON CONFLICT DO NOTHING` pour l'insertion en L3. Comme la contrainte UNIQUE
ne se déclenche jamais pour `method_version_id IS NULL`, `ON CONFLICT DO NOTHING`
**ne protège jamais contre les doublons** dans ce cas. Chaque exécution du script
de normalisation L3 pour un indicateur donné **ajoute un nouveau lot complet** de
810 lignes (54×15), au lieu de les remplacer ou de ne rien faire.

### 3.3 Précédent — Sprint 8, déduplication L1 seule

`db/patch_db/patch_deduplicate_l1_only.sql` (Sprint 8, mai 2026) documente déjà
**106 884 doublons supprimés en L1** ("Nettoyage 106 884 doublons L1 + ECO_GDP L2").
Ce patch ne traite QUE `layer_id = 1` (et un cas particulier ECO_GDP en L2). La même
cause racine (contrainte UNIQUE inopérante sur `method_version_id IS NULL`) a
continué de produire des doublons en L2/L3 depuis, sans correctif équivalent.

### 3.4 Outil d'audit existant — angle mort

`collectors/check_l3.py` (10 contrôles C1-C10) ne contient **aucun contrôle de
duplication/cardinalité** des lignes L3. Les contrôles existants (bornes [0,1],
NaN, direction, couverture, etc.) sont tous individuellement satisfaits par des
lignes dupliquées identiques — la duplication est donc invisible à cet audit.

## 4. Questions ouvertes / décisions nécessaires (hors périmètre de ce constat)

1. **Ampleur exacte par pilier** : quantifier, pour chaque pilier et chaque année
   2010-2024, l'écart entre le score actuellement stocké dans `ma.pillar_scores`
   (post-`LEAST(1.0,...)`) et le score qui serait obtenu avec des lignes L3
   dédupliquées (`SUM(DISTINCT ...)` n'existe pas en SQL pour des tuples — nécessite
   une déduplication préalable ou un recalcul).

2. **PGEO/PECO** : déterminer si ces deux piliers sont réellement épargnés ou
   simplement sous le seuil de plafonnement visible.

3. **Stratégie de correction** : (a) dédupliquer L3 (`DELETE` sur lignes
   redondantes, à l'image de `patch_deduplicate_l1_only.sql` mais étendu à L2/L3),
   (b) corriger la contrainte UNIQUE (ex. `method_version_id` avec valeur par
   défaut non-NULL, ou retrait de cette colonne de la contrainte, ou index partiel
   `WHERE method_version_id IS NULL`), (c) corriger `compute_pillar_score` pour
   être idempotent face aux doublons (`SUM(DISTINCT ...)` impossible directement —
   nécessiterait un `GROUP BY` intermédiaire), (d) ajouter un contrôle de
   cardinalité à `check_l3.py`.

4. **Recalcul des scores publiés** : si la correction change les scores SOV_*
   2010-2024 (statut OFFICIAL), implications sur la communication/gouvernance (P9)
   étant donné l'accès anticipé déjà ouvert.

5. **Origine temporelle** : identifier depuis quel sprint/commit cette duplication
   L3 s'accumule (corrélation probable avec le nombre d'exécutions de
   `fix_normalize_indicator_v2.sql` ou équivalent par indicateur).

## 5. Statut du sprint ENV_FOR (Sprint 23) au moment de cette découverte

La correction L1 d'ENV_FOR (`collect.raw_data`, 147 lignes, observations
2010/2015/2020 + SDN/SSD 2012/2015/2020, item FAO 6646/élément 7209) est
**complète, validée, committée** — acquis indépendant de ce constat.

La suite (propagation vers `ma.indicator_values` L1/L2/L3 pour ENV_FOR,
`imputer_v3`, recalcul `SOV_PENV`) est **suspendue** dans l'attente d'une décision
sur le traitement de la duplication L3 globale, pour ne pas ajouter de données
propres dans une table dont l'état est actuellement incertain à grande échelle.
