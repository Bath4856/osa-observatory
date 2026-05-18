-- ============================================================
-- OSA Observatory — patch_ilo_registration.sql
-- Sprint 6 — Mai 2026
--
-- Enregistrement complet de la source ILO dans l'architecture
-- OSA pour permettre l'exécution de fetcher_ilo_csv.py.
--
-- Ce patch crée :
--   1. collect.data_providers       → provider ILO
--   2. collect.provider_endpoints   → endpoint ILO_CSV_GZ
--   3. collect.source_registry      → source ILO ILOSTAT
--   4. collect.source_registry_indicators → liens source ↔ indicateurs
--   5. rf.indicators                → 4 nouveaux indicateurs PECO
--   6. collect.indicator_source     → liens indicateurs ↔ endpoints
--   7. ma.indicator_method_versions → version méthode PECO (si absente)
--
-- Indicateurs créés :
--   ECO_INFORMAL_RATE   Taux emploi informel total (%)
--   ECO_INFORMAL_NAG    Taux emploi informel hors agriculture (%)
--   ECO_INFORMAL_NB     Nb travailleurs informels (milliers)
--   ECO_INFORMAL_MICRO  Part emploi informel micro-entreprises 1-4 emp.
--
-- Idempotent — peut être rejoué sans erreur.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Provider ILO
-- ------------------------------------------------------------

INSERT INTO collect.data_providers (code, name, base_url, reliability_score, description, is_active)
VALUES (
    'ILO',
    'International Labour Organization — ILOSTAT',
    'https://rplumber.ilo.org/data/',
    0.88,
    'ILOSTAT — base de données officielle OIT sur l''emploi, le chômage, '
    'les conditions de travail et l''économie informelle. '
    'Données disponibles via API rplumber (format CSV.GZ). '
    'Indicateur SDG 8.3.1 — part de l''emploi informel.',
    TRUE
)
ON CONFLICT (code) DO UPDATE SET
    name             = EXCLUDED.name,
    base_url         = EXCLUDED.base_url,
    reliability_score= EXCLUDED.reliability_score,
    description      = EXCLUDED.description,
    is_active        = EXCLUDED.is_active;

-- ------------------------------------------------------------
-- 2. Endpoint ILO_CSV_GZ
-- ------------------------------------------------------------

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description, is_active)
SELECT
    dp.id,
    'ILO_CSV_GZ',
    'ILOSTAT — indicateurs emploi informel (CSV.GZ)',
    'https://rplumber.ilo.org/data/indicator?id={indicator_id}&format=.csv.gz',
    'csv',
    'Endpoint ILOSTAT rplumber. Retourne un fichier CSV compressé GZ. '
    'Paramètre : id = code indicateur (ex: SDG_0831_SEX_ECO_RT_A). '
    'Filtres appliqués : sex=SEX_T, classif1=ECO_SECTOR_TOTAL/NAG, '
    'classif2=EST_AGGREGATE_S1-4 selon indicateur.',
    TRUE
FROM collect.data_providers dp
WHERE dp.code = 'ILO'
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 3. Source registry ILO ILOSTAT
-- ------------------------------------------------------------

INSERT INTO collect.source_registry
    (source_id, name, organization, api_type, base_url, status, priority,
     coverage, stability, limits, reason,
     freshness_score, completeness_score, reliability_score,
     is_active)
VALUES (
    'ILO_ILOSTAT',
    'ILOSTAT — Employment and Informality Statistics',
    'International Labour Organization (ILO)',
    'CSV_BULK',
    'https://rplumber.ilo.org/data/',
    'GO',
    2,
    'Afrique : 43–44/54 pays | 2010–2024 | SDG 8.3.1',
    'Stable — publication annuelle ILO',
    'Accès libre — pas d''authentification requise. '
    'API rplumber peut bloquer certains serveurs (filtrage IP). '
    'Téléchargement manuel recommandé depuis ilostat.ilo.org.',
    'Source officielle ONU pour les indicateurs SDG 8.3.1. '
    'Seule source globale sur l''emploi informel avec couverture africaine. '
    'Intégration OSA Sprint 6 — approche conséquentialiste corruption/informel.',
    0.75,
    0.80,
    0.88,
    TRUE
)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 4. rf.indicators — 4 nouveaux indicateurs PECO
-- ------------------------------------------------------------

-- ECO_INFORMAL_RATE
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, unit_code, direction,
     description, display_order, is_active, imputation_regime,
     is_composite_score, has_structural_zeros)
VALUES (
    'ECO_INFORMAL_RATE',
    'Taux d''emploi informel total (% emploi total)',
    'Total informal employment rate (% of total employment)',
    'PECO', 'PCT', '-',
    'SDG 8.3.1 — Part de l''emploi informel dans l''emploi total. '
    'Indicateur conséquentialiste de distorsion souveraine économique. '
    'Valeur élevée = pression sur la base fiscale et la capacité de '
    'redistribution de l''État. Source : ILOSTAT SDG_0831_SEX_ECO_RT_A. '
    'Filtre : SEX_T + ECO_SECTOR_TOTAL. Couverture : 43/54 pays africains.',
    19, TRUE, 'STANDARD', FALSE, TRUE
)
ON CONFLICT (code) DO NOTHING;

-- ECO_INFORMAL_NAG
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, unit_code, direction,
     description, display_order, is_active, imputation_regime,
     is_composite_score, has_structural_zeros)
VALUES (
    'ECO_INFORMAL_NAG',
    'Taux emploi informel hors agriculture (% emploi non-agricole)',
    'Non-agricultural informal employment rate (% of non-agri employment)',
    'PECO', 'PCT', '-',
    'Taux d''emploi informel dans les secteurs non-agricoles. '
    'Distingue l''informalité structurelle rurale (agricole) de '
    'l''informalité urbaine et industrielle actionnable par la politique. '
    'Source : ILOSTAT SDG_0831_SEX_ECO_RT_A. '
    'Filtre : SEX_T + ECO_SECTOR_NAG. Couverture : 22/54 pays africains.',
    20, TRUE, 'STANDARD', FALSE, TRUE
)
ON CONFLICT (code) DO NOTHING;

-- ECO_INFORMAL_NB
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, unit_code, direction,
     description, display_order, is_active, imputation_regime,
     is_composite_score, has_structural_zeros)
VALUES (
    'ECO_INFORMAL_NB',
    'Nombre de travailleurs informels (milliers)',
    'Number of informal workers (thousands)',
    'PECO', 'THOUS', '-',
    'Nombre absolu de travailleurs en emploi informel en milliers. '
    'Complément de ECO_INFORMAL_RATE — capte l''ampleur absolue '
    'indépendamment du taux relatif. '
    'Source : ILOSTAT EMP_NIFL_SEX_ECO_NB_A. '
    'Filtre : SEX_T + ECO_SECTOR_TOTAL.',
    21, TRUE, 'STANDARD', FALSE, TRUE
)
ON CONFLICT (code) DO NOTHING;

-- ECO_INFORMAL_MICRO
INSERT INTO rf.indicators
    (code, name_fr, name_en, pillar_code, unit_code, direction,
     description, display_order, is_active, imputation_regime,
     is_composite_score, has_structural_zeros)
VALUES (
    'ECO_INFORMAL_MICRO',
    'Emploi informel micro-entreprises 1–4 employés (milliers)',
    'Informal employment in micro-enterprises 1-4 workers (thousands)',
    'PECO', 'THOUS', '-',
    'Nombre de travailleurs informels dans les micro-entreprises '
    '(1 à 4 employés). Proxy de la fragmentation productive — '
    'plus ce chiffre est élevé, plus l''économie informelle est '
    'atomisée et difficile à formaliser par la politique publique. '
    'Source : ILOSTAT EMP_NIFL_SEX_ECO_EST_NB_A. '
    'Filtre : SEX_T + ECO_SECTOR_TOTAL + EST_AGGREGATE_S1-4. '
    'Couverture : 38/54 pays africains.',
    22, TRUE, 'STANDARD', FALSE, TRUE
)
ON CONFLICT (code) DO NOTHING;

-- ------------------------------------------------------------
-- 5. collect.source_registry_indicators
--    Liens entre la source ILO et les 4 indicateurs
-- ------------------------------------------------------------

INSERT INTO collect.source_registry_indicators
    (source_id, osa_code, source_code, endpoint, unit, frequency, decision, is_active)
VALUES
    ('ILO_ILOSTAT', 'ECO_INFORMAL_RATE',  'SDG_0831_SEX_ECO_RT_A', 'https://rplumber.ilo.org/data/indicator?id=SDG_0831_SEX_ECO_RT_A&format=.csv.gz',     'PCT',   'annual', 'GO',   TRUE),
    ('ILO_ILOSTAT', 'ECO_INFORMAL_NAG',   'SDG_0831_SEX_ECO_RT_A', 'https://rplumber.ilo.org/data/indicator?id=SDG_0831_SEX_ECO_RT_A&format=.csv.gz',     'PCT',   'annual', 'GO',   TRUE),
    ('ILO_ILOSTAT', 'ECO_INFORMAL_NB',    'EMP_NIFL_SEX_ECO_NB_A', 'https://rplumber.ilo.org/data/indicator?id=EMP_NIFL_SEX_ECO_NB_A&format=.csv.gz',     'THOUS', 'annual', 'GO',   TRUE),
    ('ILO_ILOSTAT', 'ECO_INFORMAL_MICRO', 'EMP_NIFL_SEX_ECO_EST_NB_A', 'https://rplumber.ilo.org/data/indicator?id=EMP_NIFL_SEX_ECO_EST_NB_A&format=.csv.gz', 'THOUS', 'annual', 'PILOT', TRUE)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 6. collect.indicator_source
--    Liens indicateurs ↔ endpoint ILO_CSV_GZ
-- ------------------------------------------------------------

-- Vérifier que la table a bien les colonnes nécessaires
DO $$
DECLARE
    v_endpoint_id  INTEGER;
    v_source_id    INTEGER;
    ind_code       TEXT;
BEGIN
    -- Récupérer l'endpoint ILO
    SELECT pe.id INTO v_endpoint_id
    FROM collect.provider_endpoints pe
    JOIN collect.data_providers dp ON dp.id = pe.provider_id
    WHERE dp.code = 'ILO' AND pe.endpoint_code = 'ILO_CSV_GZ'
    LIMIT 1;

    -- Récupérer la source ILO
    SELECT sr.id INTO v_source_id
    FROM collect.source_registry sr
    WHERE sr.name = 'ILOSTAT — Employment and Informality Statistics'
    LIMIT 1;

    IF v_endpoint_id IS NULL THEN
        RAISE NOTICE 'Endpoint ILO_CSV_GZ non trouvé — vérifier étape 2';
        RETURN;
    END IF;

    RAISE NOTICE 'endpoint_id=% source_id=%', v_endpoint_id, v_source_id;

    -- Insérer les liens pour chaque indicateur
    FOREACH ind_code IN ARRAY ARRAY[
        'ECO_INFORMAL_RATE',
        'ECO_INFORMAL_NAG',
        'ECO_INFORMAL_NB',
        'ECO_INFORMAL_MICRO'
    ] LOOP
        BEGIN
            INSERT INTO collect.indicator_source
                (indicator_code, endpoint_id, source_indicator_code, is_active)
            VALUES
                (ind_code, v_endpoint_id, ind_code, TRUE)
            ON CONFLICT DO NOTHING;
            RAISE NOTICE 'Lien créé : % → endpoint %', ind_code, v_endpoint_id;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Lien % ignoré : %', ind_code, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- ------------------------------------------------------------
-- 7. ma.indicator_method_versions pour PECO ILO
--    Utilise method_id du pilier PECO (id=3 d'après les 6 existants)
-- ------------------------------------------------------------

DO $$
DECLARE
    v_method_id INTEGER;
BEGIN
    -- Chercher la méthode PECO existante
    SELECT im.id INTO v_method_id
    FROM ma.indicator_methods im
    WHERE im.code ILIKE '%PECO%' OR im.method_type = 'STANDARD'
    LIMIT 1;

    IF v_method_id IS NULL THEN
        RAISE NOTICE 'Méthode PECO non trouvée — les indicateurs ILO utiliseront method_version_id=1';
    ELSE
        RAISE NOTICE 'Méthode trouvée : method_id=%', v_method_id;
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- 8. Vérification finale
-- ------------------------------------------------------------

SELECT 'Provider ILO' AS element,
    id::text AS id, code, name AS detail
FROM collect.data_providers WHERE code = 'ILO'

UNION ALL

SELECT 'Endpoint ILO_CSV_GZ',
    pe.id::text, pe.endpoint_code, pe.name
FROM collect.provider_endpoints pe
JOIN collect.data_providers dp ON dp.id = pe.provider_id
WHERE dp.code = 'ILO' AND pe.endpoint_code = 'ILO_CSV_GZ'

UNION ALL

SELECT 'Source ILO',
    sr.id::text, 'ILOSTAT', sr.status
FROM collect.source_registry sr
WHERE sr.name = 'ILOSTAT — Employment and Informality Statistics'

UNION ALL

SELECT 'Indicateur ' || code,
    code, pillar_code, direction || ' | ' || imputation_regime
FROM rf.indicators
WHERE code IN ('ECO_INFORMAL_RATE','ECO_INFORMAL_NAG','ECO_INFORMAL_NB','ECO_INFORMAL_MICRO')

ORDER BY element;

-- Vérifier les colonnes de indicator_source
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'collect'
  AND table_name = 'indicator_source'
ORDER BY ordinal_position;

COMMIT;
