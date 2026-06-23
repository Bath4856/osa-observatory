-- ============================================================
-- Sprint 26 — Lot A
-- Préservation sémantique du signal WKN : data_availability
-- GAF-P7I-WKN-SEMANTICS-001 (finding_id = 25)
-- 23 juin 2026
-- ============================================================
-- EXÉCUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db < sprint26_lot_a.sql
--
-- SÉQUENCE :
--   Étape 1 — Ajout colonne data_availability sur table mère
--   Étape 2 — Backfill sur les 9 665 lignes existantes
--   Étape 3 — Passage NOT NULL avec DEFAULT 'OBSERVED'
--   Étape 4 — Index de monitoring
--   Étape 5 — Vérifications
-- ============================================================

BEGIN;

-- ============================================================
-- ÉTAPE 1 — Ajout colonne (nullable en premier pour le backfill)
-- Table partitionnée : la colonne se propage aux 11 partitions.
-- ============================================================

ALTER TABLE ma.computed_values
    ADD COLUMN IF NOT EXISTS data_availability VARCHAR(20)
    CHECK (data_availability IN ('OBSERVED', 'ESTIMATED', 'MISSING'));

COMMENT ON COLUMN ma.computed_values.data_availability IS
    'Disponibilité du signal calculé. '
    'OBSERVED  : value IS NOT NULL AND confidence > 0 — valeur calculée et fiable. '
    'ESTIMATED : value calculée par imputation MICE en amont (L2). '
    'MISSING   : value IS NULL OR confidence = 0 — absence de donnée source. '
    'Préserve la distinction sémantique NULL vs 0 à travers les transformations COALESCE. '
    'Ref : GAF-P7I-WKN-SEMANTICS-001 (ops.audit_findings finding_id = 25).';

-- ============================================================
-- ÉTAPE 2 — Backfill : règles de mapping
--
-- Règle 1 — MISSING  : value IS NULL OR confidence = 0
--   Couvre les 25 cas identifiés (1 value_null + 24 conf_zero).
--   SDN 2024 WKN_PENV est ici (value=NULL, confidence=0.000).
--
-- Règle 2 — ESTIMATED : value IS NOT NULL
--                       AND confidence > 0
--                       AND confidence < 0.90
--   Seuil 0.90 : en dessous, la valeur provient typiquement
--   de MICE (imputer_v3.py insère confidence=0.700 pour IMPUTED).
--   Les valeurs observées ont confidence >= 0.90 ou = 1.000.
--   NOTE : ce seuil est conservateur — si la politique de
--   confidence MICE change, ajuster ici.
--
-- Règle 3 — OBSERVED  : tout le reste
--   value IS NOT NULL AND confidence >= 0.90
-- ============================================================

UPDATE ma.computed_values
SET data_availability = CASE
    WHEN value IS NULL OR confidence = 0               THEN 'MISSING'
    WHEN confidence > 0 AND confidence < 0.90          THEN 'ESTIMATED'
    ELSE                                                    'OBSERVED'
END
WHERE data_availability IS NULL;

-- ============================================================
-- ÉTAPE 3 — Passage NOT NULL + DEFAULT
-- Sécurisé seulement après backfill complet (zéro NULL restant).
-- ============================================================

ALTER TABLE ma.computed_values
    ALTER COLUMN data_availability SET DEFAULT 'OBSERVED',
    ALTER COLUMN data_availability SET NOT NULL;

-- ============================================================
-- ÉTAPE 4 — Index de monitoring sur les cas MISSING
-- Partiel : ne couvre que les lignes MISSING (faible cardinalité).
-- Permet les requêtes ops.v_data_availability_audit en < 10ms.
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_cv_data_availability_missing
    ON ma.computed_values (indicator_code, country_iso3, year)
    WHERE data_availability = 'MISSING';

-- ============================================================
-- ÉTAPE 5 — VÉRIFICATIONS
-- ============================================================

-- 5.1 Distribution data_availability — attendu : 0 NULL
SELECT
    data_availability,
    COUNT(*) AS nb,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM ma.computed_values
GROUP BY data_availability
ORDER BY data_availability;

-- 5.2 Détail des cas MISSING — attendu : 25 lignes
SELECT
    indicator_code,
    country_iso3,
    year,
    value,
    confidence,
    data_availability
FROM ma.computed_values
WHERE data_availability = 'MISSING'
ORDER BY indicator_code, country_iso3, year;

-- 5.3 Cas SDN 2024 WKN_PENV confirmé
SELECT
    indicator_code,
    country_iso3,
    year,
    value,
    confidence,
    data_availability
FROM ma.computed_values
WHERE indicator_code = 'WKN_PENV'
  AND country_iso3   = 'SDN'
  AND year           = 2024;

-- 5.4 Aucun NULL résiduel sur data_availability
SELECT COUNT(*) AS null_residuels
FROM ma.computed_values
WHERE data_availability IS NULL;

-- 5.5 Vérification propagation aux partitions
SELECT
    inhrelid::regclass AS partition,
    COUNT(*) AS nb_rows
FROM pg_inherits
JOIN ma.computed_values ON true
WHERE inhparent = 'ma.computed_values'::regclass
GROUP BY inhrelid::regclass
ORDER BY partition;

COMMIT;
