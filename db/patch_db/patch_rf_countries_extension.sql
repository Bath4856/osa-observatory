-- ============================================================
-- OSA Observatory — patch_rf_countries_extension.sql
-- Sprint 9 — Mai 2026
--
-- Extension de rf.countries :
--   1. is_active BOOLEAN — pays dans le périmètre OSA
--   2. aliases   JSONB   — noms de pays par source (ACLED, SIPRI, WB...)
--
-- Après ce patch :
--   Ajouter un pays = 1 INSERT dans rf.countries
--   Tous les fetchers le voient automatiquement au prochain run
--
-- Doctrine OSA : rf.countries est la source de vérité unique
--   pour la liste des pays et leurs noms dans les sources externes.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Ajouter les colonnes
-- ------------------------------------------------------------

ALTER TABLE rf.countries
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

ALTER TABLE rf.countries
ADD COLUMN IF NOT EXISTS aliases JSONB DEFAULT '{}';

COMMENT ON COLUMN rf.countries.is_active IS
'TRUE = pays dans le périmètre OSA actif.
FALSE = pays historiquement présent mais exclu du périmètre actuel.
Ajouter un pays : INSERT + is_active=TRUE.
Tous les fetchers qui lisent depuis rf.countries le verront automatiquement.';

COMMENT ON COLUMN rf.countries.aliases IS
'Noms alternatifs du pays par source externe.
Format : {"SOURCE": "nom dans la source", ...}
Ex: {"ACLED": "Democratic Republic of the Congo",
     "SIPRI": "Congo, DR",
     "WB": "Congo, Dem. Rep.",
     "IMF": "Congo, Democratic Republic of the",
     "COMTRADE": "180",
     "FAO": "249"}
Utilisé par les fetchers pour résoudre les noms → ISO3
sans listes codées en dur.';

-- ------------------------------------------------------------
-- 2. Initialiser is_active = TRUE pour les 54 pays actuels
-- ------------------------------------------------------------

UPDATE rf.countries SET is_active = TRUE WHERE is_active IS NULL;

-- ------------------------------------------------------------
-- 3. Peupler aliases pour les pays avec noms complexes dans les sources
--    (cas les plus fréquents de mismatch détectés dans les fetchers)
-- ------------------------------------------------------------

UPDATE rf.countries SET aliases = aliases || '{"ACLED": "Democratic Republic of the Congo", "SIPRI": "Congo, DR", "WB": "Congo, Dem. Rep.", "IMF": "Congo, Democratic Republic of the", "COMTRADE": "180", "FAO": "249"}'::jsonb WHERE iso3 = 'COD';
UPDATE rf.countries SET aliases = aliases || '{"ACLED": "Republic of the Congo", "SIPRI": "Congo, Rep.", "WB": "Congo, Rep.", "IMF": "Congo, Republic of", "COMTRADE": "178"}'::jsonb WHERE iso3 = 'COG';
UPDATE rf.countries SET aliases = aliases || '{"ACLED": "Central African Republic", "SIPRI": "Central African Rep.", "WB": "Central African Republic", "IMF": "Central African Republic", "COMTRADE": "140"}'::jsonb WHERE iso3 = 'CAF';
UPDATE rf.countries SET aliases = aliases || '{"ACLED": "South Sudan", "SIPRI": "South Sudan", "WB": "South Sudan", "IMF": "South Sudan, Republic of", "COMTRADE": "728", "FAO": "277"}'::jsonb WHERE iso3 = 'SSD';
UPDATE rf.countries SET aliases = aliases || '{"ACLED": "Sudan", "SIPRI": "Sudan", "WB": "Sudan", "IMF": "Sudan", "COMTRADE": "729", "UNCTAD_FR": "Soudan", "UNCTAD_FR_OLD": "Soudan (...2011)"}'::jsonb WHERE iso3 = 'SDN';
UPDATE rf.countries SET aliases = aliases || '{"ACLED": "Tanzania", "SIPRI": "Tanzania", "WB": "Tanzania", "IMF": "Tanzania, United Republic of", "COMTRADE": "834"}'::jsonb WHERE iso3 = 'TZA';
UPDATE rf.countries SET aliases = aliases || '{"ACLED": "Ivory Coast", "SIPRI": "Cote d Ivoire", "WB": "Cote d Ivoire", "IMF": "Cote d Ivoire", "UNCTAD_FR": "Cote d Ivoire"}'::jsonb WHERE iso3 = 'CIV';
UPDATE rf.countries SET aliases = aliases || '{"ACLED": "Eswatini", "SIPRI": "Eswatini", "WB": "Eswatini", "IMF": "Eswatini", "OLD_NAME": "Swaziland"}'::jsonb WHERE iso3 = 'SWZ';
UPDATE rf.countries SET aliases = aliases || '{"ACLED": "Cape Verde", "SIPRI": "Cabo Verde", "WB": "Cabo Verde", "ALT": "Cape Verde"}'::jsonb WHERE iso3 = 'CPV';
UPDATE rf.countries SET aliases = aliases || '{"ACLED": "Egypt", "SIPRI": "Egypt", "SIPRI_REGION": "Middle East", "WB": "Egypt, Arab Rep.", "IMF": "Egypt"}'::jsonb WHERE iso3 = 'EGY';
UPDATE rf.countries SET aliases = aliases || '{"ACLED": "Gambia", "WB": "Gambia, The", "IMF": "Gambia, The"}'::jsonb WHERE iso3 = 'GMB';
UPDATE rf.countries SET aliases = aliases || '{"ACLED": "Libya", "SIPRI_REGION": "Middle East", "WB": "Libya", "IMF": "Libya"}'::jsonb WHERE iso3 = 'LBY';

-- ------------------------------------------------------------
-- 4. Créer une vue utilitaire pour les fetchers
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW rf.v_country_aliases AS
SELECT
    iso3,
    iso2,
    name_fr,
    name_en,
    region_code,
    is_active,
    aliases,
    -- Extraire les alias les plus utilisés comme colonnes directes
    aliases->>'ACLED'     AS name_acled,
    aliases->>'SIPRI'     AS name_sipri,
    aliases->>'WB'        AS name_wb,
    aliases->>'IMF'       AS name_imf,
    aliases->>'COMTRADE'  AS name_comtrade,
    aliases->>'FAO'       AS name_fao,
    aliases->>'UNCTAD_FR' AS name_unctad_fr,
    aliases->>'SIPRI_REGION' AS sipri_region_override
FROM rf.countries
WHERE is_active = TRUE;

COMMENT ON VIEW rf.v_country_aliases IS
'Vue utilitaire pour les fetchers — liste des pays OSA actifs
avec leurs noms alternatifs par source.
Usage : SELECT iso3, name_acled FROM rf.v_country_aliases';

-- ------------------------------------------------------------
-- 5. Vérification
-- ------------------------------------------------------------

DO $$
DECLARE
    v_total    INTEGER;
    v_active   INTEGER;
    v_aliases  INTEGER;
    v_sipri_override INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total  FROM rf.countries;
    SELECT COUNT(*) INTO v_active FROM rf.countries WHERE is_active = TRUE;
    SELECT COUNT(*) INTO v_aliases FROM rf.countries WHERE aliases != '{}';
    SELECT COUNT(*) INTO v_sipri_override
    FROM rf.countries WHERE aliases->>'SIPRI_REGION' IS NOT NULL;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'rf.countries — extension Sprint 9';
    RAISE NOTICE '  Total pays         : %', v_total;
    RAISE NOTICE '  Pays actifs OSA    : %', v_active;
    RAISE NOTICE '  Avec aliases       : %', v_aliases;
    RAISE NOTICE '  SIPRI region override : %', v_sipri_override;
    RAISE NOTICE '--------------------------------------------';
    RAISE NOTICE 'Vue rf.v_country_aliases créée';
    RAISE NOTICE 'Ajouter un pays = 1 INSERT + is_active=TRUE';
    RAISE NOTICE '============================================';
END;
$$;

COMMIT;
