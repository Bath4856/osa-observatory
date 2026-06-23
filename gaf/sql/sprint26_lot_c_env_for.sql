-- ============================================================
-- Sprint 26 — Lot C
-- Correction ENV_FOR + recalcul pipeline PENV complet
-- GAF finding #28 ENV_FOR_CORRECTION_PENDING
-- 23 juin 2026
-- ============================================================
-- SÉQUENCE D'EXÉCUTION (ordre impératif) :
--
--   Étape 1 — Ce fichier : correction L1 ENV_FOR
--     docker exec -i osa-db psql -U postgres -d osa_db \
--       < sprint26_lot_c_env_for.sql
--
--   Étape 2 — Recalcul L2/L3 ENV_FOR (imputer + normalize)
--     Sur le VPS, hors psql :
--     cd /mnt/data/osa-app/osa-observatory
--     python3 collectors/imputer_v3.py --indicator ENV_FOR
--     (ou via le pipeline : option [7] L3 mise à jour annuelle)
--
--   Étape 3 — Recalcul des computed_values PENV
--     docker exec -i osa-db psql -U postgres -d osa_db \
--       < sprint26_lot_c_recompute_penv.sql
--
--   Étape 4 — Vérification et clôture finding #28
--     Inclus en fin de sprint26_lot_c_recompute_penv.sql
--
-- PRÉ-REQUIS : vérifier que le diagnostic pré-patch confirme
--   val_max > 100 en L1 (bug unité actif)
-- ============================================================

-- ============================================================
-- FICHIER 1/2 : sprint26_lot_c_env_for.sql
-- Correction L1 : remplacement des 692 lignes ENV_FOR bugguées
-- par 147 observations réelles (ancres FAO 2010/2015/2020)
-- ============================================================

BEGIN;

-- Snapshot avant correction (pour audit trail)
DO $$
DECLARE
    v_count     INT;
    v_max_val   NUMERIC;
    v_min_val   NUMERIC;
BEGIN
    SELECT COUNT(*), MAX(value_raw), MIN(value_raw)
    INTO v_count, v_max_val, v_min_val
    FROM collect.raw_data
    WHERE indicator_code = 'ENV_FOR';

    RAISE NOTICE 'PRE-PATCH ENV_FOR -- lignes: %, val_min: %, val_max: %',
        v_count, v_min_val, v_max_val;

    IF v_max_val <= 100 THEN
        RAISE EXCEPTION
            'ABORT : ENV_FOR val_max = % -- Le patch semble déjà appliqué. '
            'Vérifier avant de continuer.', v_max_val;
    END IF;
END $$;

-- Suppression des 692 lignes avec bug d''unité (1000 ha)
DELETE FROM collect.raw_data WHERE indicator_code = 'ENV_FOR';

-- Insertion des 147 observations réelles
-- Source : FAO FRA item 6646 / element 7209 (% superficie couverte)
-- Ancres quinquennales : 2010, 2015, 2020
-- Les années intermédiaires seront produites par imputer_v3 (step1_duckdb)
-- avec FLAG_INTERPOLATED et confidence réduite (non ingérées en L1
-- conformément à la doctrine P7E : pas de données interpolées en L1)
INSERT INTO collect.raw_data
    (endpoint_id, indicator_code, country_iso3, year, value_raw, load_date)
VALUES
    (1,'ENV_FOR','AGO',2010,56.88,now()),
    (1,'ENV_FOR','AGO',2015,54.83,now()),
    (1,'ENV_FOR','AGO',2020,52.79,now()),
    (1,'ENV_FOR','BDI',2010,7.55,now()),
    (1,'ENV_FOR','BDI',2015,10.89,now()),
    (1,'ENV_FOR','BDI',2020,10.89,now()),
    (1,'ENV_FOR','BEN',2010,37.82,now()),
    (1,'ENV_FOR','BEN',2015,31.10,now()),
    (1,'ENV_FOR','BEN',2020,29.44,now()),
    (1,'ENV_FOR','BFA',2010,18.40,now()),
    (1,'ENV_FOR','BFA',2015,16.21,now()),
    (1,'ENV_FOR','BFA',2020,14.02,now()),
    (1,'ENV_FOR','BWA',2010,27.75,now()),
    (1,'ENV_FOR','BWA',2015,27.75,now()),
    (1,'ENV_FOR','BWA',2020,27.76,now()),
    (1,'ENV_FOR','CAF',2010,73.41,now()),
    (1,'ENV_FOR','CAF',2015,73.13,now()),
    (1,'ENV_FOR','CAF',2020,72.76,now()),
    (1,'ENV_FOR','CIV',2010,15.72,now()),
    (1,'ENV_FOR','CIV',2015,13.99,now()),
    (1,'ENV_FOR','CIV',2020,13.14,now()),
    (1,'ENV_FOR','CMR',2010,44.21,now()),
    (1,'ENV_FOR','CMR',2015,43.62,now()),
    (1,'ENV_FOR','CMR',2020,41.73,now()),
    (1,'ENV_FOR','COD',2010,64.86,now()),
    (1,'ENV_FOR','COD',2015,62.64,now()),
    (1,'ENV_FOR','COD',2020,62.02,now()),
    (1,'ENV_FOR','COG',2010,64.47,now()),
    (1,'ENV_FOR','COG',2015,64.17,now()),
    (1,'ENV_FOR','COG',2020,63.79,now()),
    (1,'ENV_FOR','COM',2010,20.04,now()),
    (1,'ENV_FOR','COM',2015,18.57,now()),
    (1,'ENV_FOR','COM',2020,17.66,now()),
    (1,'ENV_FOR','CPV',2010,10.50,now()),
    (1,'ENV_FOR','CPV',2015,11.13,now()),
    (1,'ENV_FOR','CPV',2020,11.90,now()),
    (1,'ENV_FOR','DZA',2010,0.71,now()),
    (1,'ENV_FOR','DZA',2015,0.71,now()),
    (1,'ENV_FOR','DZA',2020,0.71,now()),
    (1,'ENV_FOR','EGY',2010,0.00,now()),
    (1,'ENV_FOR','EGY',2015,0.00,now()),
    (1,'ENV_FOR','EGY',2020,0.00,now()),
    (1,'ENV_FOR','ETH',2010,24.00,now()),
    (1,'ENV_FOR','ETH',2015,23.74,now()),
    (1,'ENV_FOR','ETH',2020,23.72,now()),
    (1,'ENV_FOR','GAB',2010,91.91,now()),
    (1,'ENV_FOR','GAB',2015,91.68,now()),
    (1,'ENV_FOR','GAB',2020,91.55,now()),
    (1,'ENV_FOR','GHA',2010,28.66,now()),
    (1,'ENV_FOR','GHA',2015,29.44,now()),
    (1,'ENV_FOR','GHA',2020,30.23,now()),
    (1,'ENV_FOR','GIN',2010,23.86,now()),
    (1,'ENV_FOR','GIN',2015,22.49,now()),
    (1,'ENV_FOR','GIN',2020,21.13,now()),
    (1,'ENV_FOR','GMB',2010,29.64,now()),
    (1,'ENV_FOR','GMB',2015,26.79,now()),
    (1,'ENV_FOR','GMB',2020,23.93,now()),
    (1,'ENV_FOR','GNB',2010,76.93,now()),
    (1,'ENV_FOR','GNB',2015,76.17,now()),
    (1,'ENV_FOR','GNB',2020,75.42,now()),
    (1,'ENV_FOR','GNQ',2010,90.29,now()),
    (1,'ENV_FOR','GNQ',2015,88.78,now()),
    (1,'ENV_FOR','GNQ',2020,87.29,now()),
    (1,'ENV_FOR','KEN',2010,6.81,now()),
    (1,'ENV_FOR','KEN',2015,5.93,now()),
    (1,'ENV_FOR','KEN',2020,6.18,now()),
    (1,'ENV_FOR','LBR',2010,79.11,now()),
    (1,'ENV_FOR','LBR',2015,73.05,now()),
    (1,'ENV_FOR','LBR',2020,67.79,now()),
    (1,'ENV_FOR','LBY',2010,0.12,now()),
    (1,'ENV_FOR','LBY',2015,0.12,now()),
    (1,'ENV_FOR','LBY',2020,0.12,now()),
    (1,'ENV_FOR','LSO',2010,1.14,now()),
    (1,'ENV_FOR','LSO',2015,1.14,now()),
    (1,'ENV_FOR','LSO',2020,1.14,now()),
    (1,'ENV_FOR','MAR',2010,12.76,now()),
    (1,'ENV_FOR','MAR',2015,12.75,now()),
    (1,'ENV_FOR','MAR',2020,12.76,now()),
    (1,'ENV_FOR','MDG',2010,20.54,now()),
    (1,'ENV_FOR','MDG',2015,19.16,now()),
    (1,'ENV_FOR','MDG',2020,18.12,now()),
    (1,'ENV_FOR','MLI',2010,9.82,now()),
    (1,'ENV_FOR','MLI',2015,9.41,now()),
    (1,'ENV_FOR','MLI',2020,9.00,now()),
    (1,'ENV_FOR','MOZ',2010,46.10,now()),
    (1,'ENV_FOR','MOZ',2015,44.40,now()),
    (1,'ENV_FOR','MOZ',2020,42.70,now()),
    (1,'ENV_FOR','MUS',2010,18.90,now()),
    (1,'ENV_FOR','MUS',2015,19.18,now()),
    (1,'ENV_FOR','MUS',2020,19.17,now()),
    (1,'ENV_FOR','MWI',2010,28.23,now()),
    (1,'ENV_FOR','MWI',2015,26.00,now()),
    (1,'ENV_FOR','MWI',2020,23.78,now()),
    (1,'ENV_FOR','NAM',2010,9.78,now()),
    (1,'ENV_FOR','NAM',2015,9.78,now()),
    (1,'ENV_FOR','NAM',2020,9.77,now()),
    (1,'ENV_FOR','NGA',2010,20.90,now()),
    (1,'ENV_FOR','NGA',2015,20.20,now()),
    (1,'ENV_FOR','NGA',2020,19.50,now()),
    (1,'ENV_FOR','RWA',2010,16.87,now()),
    (1,'ENV_FOR','RWA',2015,19.82,now()),
    (1,'ENV_FOR','RWA',2020,22.77,now()),
    (1,'ENV_FOR','SDN',2012,12.98,now()),
    (1,'ENV_FOR','SDN',2015,12.70,now()),
    (1,'ENV_FOR','SDN',2020,12.23,now()),
    (1,'ENV_FOR','SEN',2010,46.14,now()),
    (1,'ENV_FOR','SEN',2015,45.73,now()),
    (1,'ENV_FOR','SEN',2020,45.33,now()),
    (1,'ENV_FOR','SLE',2010,37.85,now()),
    (1,'ENV_FOR','SLE',2015,36.49,now()),
    (1,'ENV_FOR','SLE',2020,35.12,now()),
    (1,'ENV_FOR','SOM',2010,10.76,now()),
    (1,'ENV_FOR','SOM',2015,9.53,now()),
    (1,'ENV_FOR','SOM',2020,8.30,now()),
    (1,'ENV_FOR','SSD',2012,11.31,now()),
    (1,'ENV_FOR','SSD',2015,11.33,now()),
    (1,'ENV_FOR','SSD',2020,11.32,now()),
    (1,'ENV_FOR','SWZ',2010,26.49,now()),
    (1,'ENV_FOR','SWZ',2015,26.05,now()),
    (1,'ENV_FOR','SWZ',2020,25.61,now()),
    (1,'ENV_FOR','SYC',2010,64.76,now()),
    (1,'ENV_FOR','SYC',2015,62.39,now()),
    (1,'ENV_FOR','SYC',2020,60.02,now()),
    (1,'ENV_FOR','TCD',2010,4.39,now()),
    (1,'ENV_FOR','TCD',2015,3.88,now()),
    (1,'ENV_FOR','TCD',2020,3.38,now()),
    (1,'ENV_FOR','TGO',2010,22.78,now()),
    (1,'ENV_FOR','TGO',2015,22.51,now()),
    (1,'ENV_FOR','TGO',2020,22.23,now()),
    (1,'ENV_FOR','TUN',2010,4.53,now()),
    (1,'ENV_FOR','TUN',2015,4.54,now()),
    (1,'ENV_FOR','TUN',2020,4.50,now()),
    (1,'ENV_FOR','TZA',2010,56.56,now()),
    (1,'ENV_FOR','TZA',2015,54.29,now()),
    (1,'ENV_FOR','TZA',2020,51.64,now()),
    (1,'ENV_FOR','UGA',2010,14.46,now()),
    (1,'ENV_FOR','UGA',2015,13.21,now()),
    (1,'ENV_FOR','UGA',2020,12.51,now()),
    (1,'ENV_FOR','ZAF',2010,17.78,now()),
    (1,'ENV_FOR','ZAF',2015,18.14,now()),
    (1,'ENV_FOR','ZAF',2020,18.50,now()),
    (1,'ENV_FOR','ZMB',2010,62.81,now()),
    (1,'ENV_FOR','ZMB',2015,61.55,now()),
    (1,'ENV_FOR','ZMB',2020,61.02,now()),
    (1,'ENV_FOR','ZWE',2010,37.74,now()),
    (1,'ENV_FOR','ZWE',2015,36.97,now()),
    (1,'ENV_FOR','ZWE',2020,36.27,now());

-- Vérification post-insertion
DO $$
DECLARE
    v_total        INT;
    v_hors_plage   INT;
    v_pays         INT;
BEGIN
    SELECT COUNT(*), COUNT(*) FILTER (WHERE value_raw > 100),
           COUNT(DISTINCT country_iso3)
    INTO v_total, v_hors_plage, v_pays
    FROM collect.raw_data
    WHERE indicator_code = 'ENV_FOR';

    RAISE NOTICE 'POST-PATCH ENV_FOR -- lignes: %, pays: %, hors plage [0,100]: %',
        v_total, v_pays, v_hors_plage;

    IF v_hors_plage > 0 THEN
        RAISE EXCEPTION 'POST-PATCH INVALIDE : % valeur(s) hors plage [0,100]', v_hors_plage;
    END IF;

    IF v_total <> 147 THEN
        RAISE EXCEPTION 'POST-PATCH INVALIDE : % lignes insérées (attendu : 147)', v_total;
    END IF;

    RAISE NOTICE 'ENV_FOR L1 correction validée. Lancer imputer_v3 avant suite.';
END $$;

COMMIT;
