-- ============================================================
-- OSA Observatory — patch_reference_classifications.sql
-- Sprint 9 — Chantier 9B extension — Mai 2026
--
-- Création de collect.reference_classifications
-- Table générique de référentiels de classification évolutifs.
--
-- Remplace toutes les listes codées en dur dans les fetchers :
--   EITI     → statuts conformité (compliant, candidate, etc.)
--   SIPRI    → classifications régionales (Middle East, etc.)
--   IMF      → agrégats régionaux exclus
--   IMPUTER  → codes région pour KNN géopolitique
--   UA/CER   → membership organisations africaines (futur)
--   ACLED    → seuils de conflit par région (futur)
--
-- Principe : tout fetcher qui a des données de référence évolutives
-- lit depuis cette table. La mise à jour annuelle est un simple
-- UPDATE documenté, pas une modification de code.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Création de la table
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS collect.reference_classifications (
    id              SERIAL PRIMARY KEY,
    source_code     VARCHAR(20)  NOT NULL,  -- 'EITI', 'SIPRI', 'IMF', 'UA'...
    country_iso3    VARCHAR(3),             -- NULL si classification globale
    classification  VARCHAR(100) NOT NULL,  -- 'compliant', 'Middle East'...
    score_value     NUMERIC,                -- valeur numérique associée
    valid_from      SMALLINT     NOT NULL,  -- année de début de validité
    valid_to        SMALLINT,               -- NULL = toujours valide
    metadata        JSONB,                  -- infos complémentaires flexibles
    source_url      TEXT,                   -- URL de référence traçabilité
    updated_at      TIMESTAMP DEFAULT NOW(),
    updated_by      VARCHAR(50) DEFAULT 'OSA_PIPELINE',

    CONSTRAINT uq_ref_class
        UNIQUE (source_code, country_iso3, classification, valid_from),

    CONSTRAINT chk_valid_years
        CHECK (valid_to IS NULL OR valid_to >= valid_from),

    CONSTRAINT chk_iso3_format
        CHECK (country_iso3 IS NULL OR country_iso3 ~ '^[A-Z]{3}$')
);

COMMENT ON TABLE collect.reference_classifications IS
'Référentiels de classification évolutifs par source.
Remplace toutes les listes codées en dur dans les fetchers.
Chaque entrée est valide de valid_from à valid_to (NULL = toujours valide).
Sources : EITI (statuts), SIPRI (régions), IMF (agrégats), UA (membership).
Mise à jour annuelle via INSERT/UPDATE — aucune modification de code requise.';

COMMENT ON COLUMN collect.reference_classifications.source_code IS
'Code de la source : EITI, SIPRI, IMF_DOTS, UA, CER, ACLED_REGION...';

COMMENT ON COLUMN collect.reference_classifications.metadata IS
'Informations complémentaires flexibles.
Ex EITI : {"since": 2013, "status_label": "Compliant"}
Ex SIPRI : {"sipri_region": "sub-saharan africa", "sipri_subregion": "southern africa"}';

-- Index pour performance fetchers
CREATE INDEX IF NOT EXISTS idx_ref_class_source
    ON collect.reference_classifications (source_code, country_iso3);

CREATE INDEX IF NOT EXISTS idx_ref_class_validity
    ON collect.reference_classifications (source_code, valid_from, valid_to);

-- ------------------------------------------------------------
-- 2. Peuplement EITI — 32 pays (statuts 2024 comme base)
-- ------------------------------------------------------------

INSERT INTO collect.reference_classifications
    (source_code, country_iso3, classification, score_value, valid_from, valid_to, metadata, source_url)
VALUES
-- Statut actuel (valid_from = année d'adhésion, valid_to = NULL = toujours valide)
('EITI', 'CMR', 'compliant',           90.0, 2013, NULL, '{"since":2013}', 'https://eiti.org/cameroon'),
('EITI', 'CAF', 'meaningful progress', 70.0, 2008, NULL, '{"since":2008}', 'https://eiti.org/central-african-republic'),
('EITI', 'TCD', 'meaningful progress', 70.0, 2010, NULL, '{"since":2010}', 'https://eiti.org/chad'),
('EITI', 'COG', 'compliant',           90.0, 2013, NULL, '{"since":2013}', 'https://eiti.org/republic-of-congo'),
('EITI', 'COD', 'meaningful progress', 70.0, 2010, NULL, '{"since":2010}', 'https://eiti.org/democratic-republic-of-congo'),
('EITI', 'CIV', 'compliant',           90.0, 2012, NULL, '{"since":2012}', 'https://eiti.org/cote-divoire'),
('EITI', 'GHA', 'compliant',           90.0, 2010, NULL, '{"since":2010}', 'https://eiti.org/ghana'),
('EITI', 'GIN', 'compliant',           90.0, 2012, NULL, '{"since":2012}', 'https://eiti.org/guinea'),
('EITI', 'LBR', 'compliant',           90.0, 2009, NULL, '{"since":2009}', 'https://eiti.org/liberia'),
('EITI', 'MDG', 'compliant',           90.0, 2014, NULL, '{"since":2014}', 'https://eiti.org/madagascar'),
('EITI', 'MLI', 'meaningful progress', 70.0, 2008, NULL, '{"since":2008}', 'https://eiti.org/mali'),
('EITI', 'MRT', 'compliant',           90.0, 2012, NULL, '{"since":2012}', 'https://eiti.org/mauritania'),
('EITI', 'MOZ', 'meaningful progress', 70.0, 2009, NULL, '{"since":2009}', 'https://eiti.org/mozambique'),
('EITI', 'NER', 'compliant',           90.0, 2011, NULL, '{"since":2011}', 'https://eiti.org/niger'),
('EITI', 'NGA', 'compliant',           90.0, 2007, NULL, '{"since":2007}', 'https://eiti.org/nigeria'),
('EITI', 'RWA', 'compliant',           90.0, 2009, NULL, '{"since":2009}', 'https://eiti.org/rwanda'),
('EITI', 'SLE', 'compliant',           90.0, 2009, NULL, '{"since":2009}', 'https://eiti.org/sierra-leone'),
('EITI', 'SEN', 'compliant',           90.0, 2013, NULL, '{"since":2013}', 'https://eiti.org/senegal'),
('EITI', 'TZA', 'compliant',           90.0, 2012, NULL, '{"since":2012}', 'https://eiti.org/tanzania'),
('EITI', 'TGO', 'compliant',           90.0, 2013, NULL, '{"since":2013}', 'https://eiti.org/togo'),
('EITI', 'UGA', 'meaningful progress', 70.0, 2008, NULL, '{"since":2008}', 'https://eiti.org/uganda'),
('EITI', 'ZMB', 'meaningful progress', 70.0, 2009, NULL, '{"since":2009}', 'https://eiti.org/zambia'),
('EITI', 'KEN', 'meaningful progress', 70.0, 2015, NULL, '{"since":2015}', 'https://eiti.org/kenya'),
('EITI', 'GAB', 'meaningful progress', 70.0, 2022, NULL, '{"since":2022}', 'https://eiti.org/gabon'),
('EITI', 'NAM', 'meaningful progress', 70.0, 2022, NULL, '{"since":2022}', 'https://eiti.org/namibia'),
-- Candidats
('EITI', 'DZA', 'candidate',           50.0, 2020, NULL, '{"since":2020}', 'https://eiti.org/algeria'),
('EITI', 'AGO', 'candidate',           50.0, 2021, NULL, '{"since":2021}', 'https://eiti.org/angola'),
('EITI', 'BEN', 'candidate',           50.0, 2023, NULL, '{"since":2023}', 'https://eiti.org/benin'),
('EITI', 'EGY', 'candidate',           50.0, 2016, NULL, '{"since":2016}', 'https://eiti.org/egypt'),
('EITI', 'ETH', 'candidate',           50.0, 2014, NULL, '{"since":2014}', 'https://eiti.org/ethiopia'),
('EITI', 'GNB', 'candidate',           50.0, 2018, NULL, '{"since":2018}', 'https://eiti.org/guinea-bissau'),
('EITI', 'ZWE', 'candidate',           50.0, 2019, NULL, '{"since":2019}', 'https://eiti.org/zimbabwe'),
-- Suspendu
('EITI', 'BFA', 'suspended',           20.0, 2016, NULL, '{"since":2016}', 'https://eiti.org/burkina-faso')
ON CONFLICT (source_code, country_iso3, classification, valid_from) DO NOTHING;

-- ------------------------------------------------------------
-- 3. Peuplement SIPRI — classifications régionales
-- ------------------------------------------------------------

-- Cas particulier Égypte classée "Middle East" par SIPRI (fix Sprint 8)
INSERT INTO collect.reference_classifications
    (source_code, country_iso3, classification, valid_from, metadata, source_url)
VALUES
('SIPRI', 'EGY', 'Middle East', 2010, '{"sipri_original":"Middle East","osa_region":"Africa","note":"SIPRI classifie EGY en Middle East — OSA force Africa"}', 'https://www.sipri.org/databases/milex'),
('SIPRI', 'SDN', 'Africa',      2010, '{"sipri_subregion":"north africa"}', 'https://www.sipri.org/databases/milex'),
('SIPRI', 'SSD', 'Africa',      2011, '{"sipri_subregion":"sub-saharan africa","note":"indépendance 2011"}', 'https://www.sipri.org/databases/milex')
ON CONFLICT (source_code, country_iso3, classification, valid_from) DO NOTHING;

-- ------------------------------------------------------------
-- 4. Vérification
-- ------------------------------------------------------------

DO $$
DECLARE
    v_eiti  INTEGER;
    v_sipri INTEGER;
    v_total INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_eiti  FROM collect.reference_classifications WHERE source_code = 'EITI';
    SELECT COUNT(*) INTO v_sipri FROM collect.reference_classifications WHERE source_code = 'SIPRI';
    SELECT COUNT(*) INTO v_total FROM collect.reference_classifications;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'collect.reference_classifications créée';
    RAISE NOTICE '  EITI  : % entrées', v_eiti;
    RAISE NOTICE '  SIPRI : % entrées', v_sipri;
    RAISE NOTICE '  TOTAL : % entrées', v_total;
    RAISE NOTICE '--------------------------------------------';
    RAISE NOTICE 'Sources à migrer vers cette table :';
    RAISE NOTICE '  fetcher_eiti_csv.py   → EITI_AFRICAN_MEMBERS';
    RAISE NOTICE '  fetcher_sipri_csv.py  → SIPRI_REGION_LABELS';
    RAISE NOTICE '  fetcher_sipri_milex.py → SUBREGIONS';
    RAISE NOTICE '  imputer_v3.py         → region_code (KNN)';
    RAISE NOTICE '============================================';
END;
$$;

COMMIT;
