-- ============================================================
-- OSA Observatory — patch_imputer_metadata_sprint6.sql
-- Sprint 6 — Mai 2026
-- ============================================================
-- Mise à jour rf.indicators et rf.pillars pour les piliers
-- PRES, PMIL, PNUM ajoutés en Priorités 1, 2, 3.
--
-- Prérequis :
--   patch_imputer_metadata.sql (Sprint 5) déjà déployé.
--   rf.pillars.imputation_regime colonne existante.
--   collect.v_imputer_config vue existante.
--
-- Idempotent — peut être rejoué sans erreur.
-- ============================================================

BEGIN;

-- ── 1. Nouvelles colonnes rf.indicators ──────────────────

ALTER TABLE rf.indicators
    ADD COLUMN IF NOT EXISTS is_composite_score   BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS has_structural_zeros  BOOLEAN DEFAULT false;

COMMENT ON COLUMN rf.indicators.is_composite_score IS
    'True pour les scores agrégés (GCI, GTI, EGDI, WGI) → '
    'régime PHYSICAL — MICE non applicable.';

COMMENT ON COLUMN rf.indicators.has_structural_zeros IS
    'True si valeur = 0 peut être réelle (non-producteur, non-exportateur). '
    'L''imputer n''impute pas ces zéros.';

-- ── 2. Régime PHYSICAL pour PRES (pilier entier) ─────────

UPDATE rf.pillars
SET imputation_regime = 'PHYSICAL'
WHERE code = 'PRES';

-- ── 3. Nouveaux indicateurs PRES (si déjà insérés) ───────

INSERT INTO rf.indicators
    (code, pillar_code, name_fr, unit, direction,
     imputation_regime, is_composite_score, has_structural_zeros)
VALUES
    ('PRES_ENRG_USE_CAP',     'PRES', 'Conso. énergie par hab. (kg éq. pétrole)', 'KG_OE_CAP', '+', 'PHYSICAL', false, false),
    ('PRES_ENRG_PROD_IEA',    'PRES', 'Production électricité (kWh)', 'KWH', '+', 'PHYSICAL', false, false),
    ('PRES_RENEW_CAP_IRENA',  'PRES', 'Capacité élec. renouvelable (% total)', 'PCT_ELEC', '+', 'PHYSICAL', false, false),
    ('PRES_RENEW_SHARE_FEC',  'PRES', 'Renouvelables % consommation finale', 'PCT_FEC', '+', 'PHYSICAL', false, false),
    ('PRES_FOSSIL_RENTS_EIA', 'PRES', 'Rentes ressources naturelles (% PIB)', 'PCT_GDP', '+', 'PHYSICAL', false, false),
    ('PRES_OIL_RENTS',        'PRES', 'Rentes pétrolières (% PIB)', 'PCT_GDP', '+', 'PHYSICAL', false, true),
    ('PRES_GAS_RENTS',        'PRES', 'Rentes gaz naturel (% PIB)', 'PCT_GDP', '+', 'PHYSICAL', false, true),
    ('PRES_WATER_FRESH',      'PRES', 'Eau douce renouvelable par hab. (m³)', 'M3_CAP', '+', 'PHYSICAL', false, false),
    ('PRES_WATER_WITHDRAWAL', 'PRES', 'Prélèvements eau douce (% ressources)', 'PCT_H2O', '-', 'PHYSICAL', false, false),
    ('PRES_WATER_AGRI',       'PRES', 'Terres irriguées (% terres cultivées)', 'PCT_AGRI', '+', 'PHYSICAL', false, false)
ON CONFLICT (code) DO UPDATE
    SET imputation_regime    = EXCLUDED.imputation_regime,
        is_composite_score   = EXCLUDED.is_composite_score,
        has_structural_zeros = EXCLUDED.has_structural_zeros;

-- ── 4. Nouveaux indicateurs PMIL ─────────────────────────

INSERT INTO rf.indicators
    (code, pillar_code, name_fr, unit, direction,
     imputation_regime, is_composite_score, has_structural_zeros)
VALUES
    -- WB / STANDARD
    ('PMIL_DEF_BUDGET_GDP', 'PMIL', 'Dépenses militaires (% PIB)',            'PCT_GDP',  '+', 'STANDARD', false, false),
    ('PMIL_DEF_BUDGET_GOV', 'PMIL', 'Dépenses militaires (% dépenses gov.)',  'PCT_GOV',  '+', 'STANDARD', false, false),
    ('PMIL_ARMED_FORCES',   'PMIL', 'Personnel forces armées',                'COUNT_N',  '+', 'STANDARD', false, false),
    ('PMIL_HOMICIDE_RATE',  'PMIL', 'Taux homicides (pour 100 000 hab.)',     'RATE_100K','-', 'STANDARD', false, false),
    -- Scores composites / PHYSICAL
    ('PMIL_STABILITY_WGI',  'PMIL', 'Stabilité politique (WGI)',              'SCORE_NORM','+','PHYSICAL', true,  false),
    -- CSV natifs
    ('PMIL_ARMS_IMPORT',    'PMIL', 'Importations armements (TIV SIPRI)',     'USD_M_CONST','+','PHYSICAL', true,  false),
    ('PMIL_ARMS_EXPORT',    'PMIL', 'Exportations armements (TIV SIPRI)',     'USD_M_CONST','+','PHYSICAL', true,  true),
    ('PMIL_GTI_TERROR',     'PMIL', 'Indice terrorisme GTI',                  'SCORE_0_10','-','PHYSICAL', true,  false),
    ('PMIL_GCI_CYBER',      'PMIL', 'Cybersécurité défense (ITU GCI)',        'SCORE_0_100','+','PHYSICAL',true,  false)
ON CONFLICT (code) DO UPDATE
    SET imputation_regime    = EXCLUDED.imputation_regime,
        is_composite_score   = EXCLUDED.is_composite_score,
        has_structural_zeros = EXCLUDED.has_structural_zeros;

-- ── 5. Nouveaux indicateurs PNUM ─────────────────────────

INSERT INTO rf.indicators
    (code, pillar_code, name_fr, unit, direction,
     imputation_regime, is_composite_score, has_structural_zeros)
VALUES
    -- WB / STANDARD
    ('PNUM_INTERNET_USERS',   'PNUM', 'Utilisateurs internet (% pop.)',           'PCT_POP',  '+', 'STANDARD', false, false),
    ('PNUM_BROADBAND_FIXED',  'PNUM', 'Haut débit fixe (pour 100 hab.)',          'PER_100',  '+', 'STANDARD', false, false),
    ('PNUM_BROADBAND_MOBILE', 'PNUM', 'Haut débit mobile (pour 100 hab.)',        'PER_100',  '+', 'STANDARD', false, false),
    ('PNUM_MOBILE_SUBSCRIPTIONS','PNUM','Abonnements mobile (pour 100 hab.)',      'PER_100',  '+', 'STANDARD', false, false),
    ('PNUM_SECURE_SERVERS',   'PNUM', 'Serveurs sécurisés (pour 1M hab.)',        'PER_1M',   '+', 'STANDARD', false, false),
    ('PNUM_TERTIARY_ENROLL',  'PNUM', 'Scolarisation supérieur (%)',              'PCT_POP',  '+', 'STANDARD', false, false),
    -- Scores composites / PHYSICAL
    ('PNUM_GOV_EFFECTIVENESS','PNUM', 'Efficacité gouvernementale (WGI)',         'SCORE_NORM','+','PHYSICAL', true,  false),
    ('PNUM_ITU_REG_ENV',      'PNUM', 'Environnement réglementaire TIC (ITU)',    'SCORE_0_5', '+', 'PHYSICAL', true,  false),
    ('PNUM_GCI_DIGITAL',      'PNUM', 'Cybersécurité numérique (ITU GCI)',        'SCORE_0_100','+','PHYSICAL',true,  false),
    ('PNUM_EGDI_EGOV',        'PNUM', 'Développement e-gouvernement (EGDI)',      'SCORE_0_1', '+', 'PHYSICAL', true,  false),
    ('PNUM_EGDI_ONLINE_SVC',  'PNUM', 'Services en ligne (EGDI-OSI)',             'SCORE_0_1', '+', 'PHYSICAL', true,  false),
    ('PNUM_EGDI_HUMAN_CAP',   'PNUM', 'Capital humain numérique (EGDI-HCI)',      'SCORE_0_1', '+', 'PHYSICAL', true,  false)
ON CONFLICT (code) DO UPDATE
    SET imputation_regime    = EXCLUDED.imputation_regime,
        is_composite_score   = EXCLUDED.is_composite_score,
        has_structural_zeros = EXCLUDED.has_structural_zeros;

-- ── 6. Mise à jour collect.v_imputer_config ───────────────
-- Ajouter is_composite_score et has_structural_zeros à la vue.

CREATE OR REPLACE VIEW collect.v_imputer_config AS
SELECT
    p.code                          AS pillar_code,
    p.imputation_regime,
    i.code                          AS indicator_code,
    i.is_port_indicator,
    i.is_composite_score,
    i.has_structural_zeros,
    c.iso3                          AS landlocked_iso3
FROM rf.pillars p
JOIN rf.indicators i ON i.pillar_code = p.code
CROSS JOIN (
    SELECT iso3 FROM rf.countries WHERE is_landlocked = true
) c;

-- ── 7. Index sur nouvelles colonnes ──────────────────────

CREATE INDEX IF NOT EXISTS idx_indicators_composite
    ON rf.indicators (pillar_code)
    WHERE is_composite_score = true;

CREATE INDEX IF NOT EXISTS idx_indicators_struct_zeros
    ON rf.indicators (pillar_code)
    WHERE has_structural_zeros = true;

-- ── 8. Vérifications finales ──────────────────────────────
DO $$
DECLARE
    v_pres_physical   INT;
    v_pmil_standard   INT;
    v_pmil_physical   INT;
    v_pnum_standard   INT;
    v_pnum_physical   INT;
    v_composite_total INT;
    v_zero_total      INT;
BEGIN
    SELECT COUNT(*) INTO v_pres_physical
        FROM rf.indicators
        WHERE pillar_code = 'PRES' AND imputation_regime = 'PHYSICAL';

    SELECT COUNT(*) INTO v_pmil_standard
        FROM rf.indicators
        WHERE pillar_code = 'PMIL' AND imputation_regime = 'STANDARD';

    SELECT COUNT(*) INTO v_pmil_physical
        FROM rf.indicators
        WHERE pillar_code = 'PMIL' AND imputation_regime = 'PHYSICAL';

    SELECT COUNT(*) INTO v_pnum_standard
        FROM rf.indicators
        WHERE pillar_code = 'PNUM' AND imputation_regime = 'STANDARD';

    SELECT COUNT(*) INTO v_pnum_physical
        FROM rf.indicators
        WHERE pillar_code = 'PNUM' AND imputation_regime = 'PHYSICAL';

    SELECT COUNT(*) INTO v_composite_total
        FROM rf.indicators WHERE is_composite_score = true;

    SELECT COUNT(*) INTO v_zero_total
        FROM rf.indicators WHERE has_structural_zeros = true;

    RAISE NOTICE 'PATCH METADATA SPRINT6 ————————————————————————';
    RAISE NOTICE '  PRES PHYSICAL    : % indicateurs', v_pres_physical;
    RAISE NOTICE '  PMIL STANDARD    : % indicateurs', v_pmil_standard;
    RAISE NOTICE '  PMIL PHYSICAL    : % indicateurs', v_pmil_physical;
    RAISE NOTICE '  PNUM STANDARD    : % indicateurs', v_pnum_standard;
    RAISE NOTICE '  PNUM PHYSICAL    : % indicateurs', v_pnum_physical;
    RAISE NOTICE '  Scores composites: % total', v_composite_total;
    RAISE NOTICE '  Zéros structurels: % indicateurs', v_zero_total;

    IF v_pres_physical < 5 THEN
        RAISE EXCEPTION 'PRES PHYSICAL insuffisant : %', v_pres_physical;
    END IF;
    IF v_composite_total < 8 THEN
        RAISE EXCEPTION 'Scores composites insuffisants : %', v_composite_total;
    END IF;

    RAISE NOTICE 'PATCH METADATA SPRINT6 OK';
END;
$$;

COMMIT;
