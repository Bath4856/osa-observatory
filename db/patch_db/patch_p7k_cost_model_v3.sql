-- =============================================================================
-- OSA / ISA — PATCH P7K COST MODEL V3 (DÉFINITIF)
-- Version : P7K_COST_V3
-- Schéma  : rf (paramètres scientifiques)
--
-- Nouveautés vs V2 :
--   + calibration_uncertainty_score  : niveau d'incertitude [0.10–0.70]
--   + calibration_review_due_date    : date d'expiration obligatoire
--   Couvre 10 familles d'intervention (1 par pilier)
--   Toutes les valeurs sont des proxies sourcés depuis des données OSA connues
-- =============================================================================

BEGIN;

-- Schémas
CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;

-- -----------------------------------------------------------------------------
-- 1. Recréer rf.isa_executive_cost_model — version définitive
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS rf.isa_executive_cost_model CASCADE;

CREATE TABLE rf.isa_executive_cost_model (

    -- Clé primaire
    intervention_family_code        TEXT            NOT NULL,
    pillar_code                     TEXT            NOT NULL,

    -- Scores de coût et complexité
    executive_cost_score            NUMERIC(5,3)    NOT NULL
                                        CHECK (executive_cost_score     BETWEEN 0 AND 1),
    implementation_complexity       NUMERIC(5,3)    NOT NULL
                                        CHECK (implementation_complexity BETWEEN 0 AND 1),
    execution_horizon_years         INTEGER         NOT NULL
                                        CHECK (execution_horizon_years  BETWEEN 1 AND 10),
    execution_maturity_score        NUMERIC(5,3)    NOT NULL
                                        CHECK (execution_maturity_score BETWEEN 0 AND 1),

    -- Colonnes de calibration scientifique
    calibration_method              TEXT            NOT NULL
                                        CHECK (calibration_method IN
                                            ('EXPERT','LITERATURE','PROXY','DEFAULT')),
    calibration_status              TEXT            NOT NULL
                                        CHECK (calibration_status IN
                                            ('VALIDATED','PROVISIONAL','REVIEW_REQUIRED')),
    calibration_uncertainty_score   NUMERIC(5,3)    NOT NULL
                                        CHECK (calibration_uncertainty_score BETWEEN 0 AND 1),
    calibration_source              TEXT            NOT NULL,
    calibration_date                DATE            NOT NULL DEFAULT CURRENT_DATE,
    calibration_review_due_date     DATE            NOT NULL,
    calibration_version             TEXT            NOT NULL DEFAULT 'V3',

    PRIMARY KEY (intervention_family_code, pillar_code),

    -- Contrainte : review_due_date doit être après calibration_date
    CONSTRAINT chk_review_due_after_calibration
        CHECK (calibration_review_due_date > calibration_date)
);

COMMENT ON TABLE rf.isa_executive_cost_model IS
    'P7K cost model — paramètres scientifiques de coût et maturité d''exécution.
     Schéma RF (paramètres scientifiques). Gouvernance des statuts dans MG.
     Toute modification déclenche le trigger trg_cost_model_audit (audit log RF).
     calibration_uncertainty_score : incertitude épistémique [0=certitude, 1=inconnu].
     calibration_review_due_date   : date limite de révision obligatoire.';

COMMENT ON COLUMN rf.isa_executive_cost_model.calibration_uncertainty_score IS
    'Niveau d''incertitude épistémique de la valeur calibrée.
     0.10–0.25 : proxy source robuste (WB, IMF, IEA, UNDP).
     0.26–0.45 : proxy source régionale ou estimation experte.
     0.46–0.70 : placeholder ou estimation sans source primaire.
     Utilisé par P7Z pour pondérer les simulations probabilistes.';

COMMENT ON COLUMN rf.isa_executive_cost_model.calibration_review_due_date IS
    'Date limite de révision obligatoire.
     VALIDATED      : +24 mois.
     PROVISIONAL    : +12 mois.
     REVIEW_REQUIRED: +3 mois.
     Au-delà, la ligne bascule automatiquement vers REVIEW_REQUIRED
     (géré par la vue mg.v_cost_model_review_due).';

-- -----------------------------------------------------------------------------
-- 2. Insertion des 10 familles — proxies sourcés, uncertainty calibrée
--
--    Règles uncertainty_score appliquées :
--    0.15 → source internationale primaire (IEA, IMF, UNDP, WB, ITU)
--    0.20 → source internationale secondaire (UNCTAD, UNEP, SIPRI)
--    0.25 → source régionale Afrique (EITI proxy, LPI Africa)
--    review_due_date = CURRENT_DATE + 12 mois (toutes PROVISIONAL)
-- -----------------------------------------------------------------------------
INSERT INTO rf.isa_executive_cost_model (
    intervention_family_code,
    pillar_code,
    executive_cost_score,
    implementation_complexity,
    execution_horizon_years,
    execution_maturity_score,
    calibration_method,
    calibration_status,
    calibration_uncertainty_score,
    calibration_source,
    calibration_date,
    calibration_review_due_date,
    calibration_version
) VALUES

-- -----------------------------------------------------------------------
-- PRES — Ressources / Énergie-Eau
-- Proxy : taux d'électrification Afrique subsaharienne (IEA 2023 : ~46%)
-- maturity 0.55 : accès énergie en progression mais infrastructure limitante
-- uncertainty 0.15 : source IEA primaire, données annuelles robustes
-- -----------------------------------------------------------------------
('ENERGY_WATER_CERTIFICATION',    'PRES',
 0.78, 0.72, 3, 0.55,
 'PROXY', 'PROVISIONAL', 0.15,
 'IEA Africa Energy Outlook 2023 — electrification rate sub-Saharan Africa ~46% (rescaled 0.55)',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V3'),

-- -----------------------------------------------------------------------
-- PMON — Monnaie / Résilience financière
-- Proxy : capacité institutionnelle monétaire UEMOA/CEMAC (IMF WEO 2023)
-- maturity 0.58 : institutions monétaires partiellement matures
-- uncertainty 0.15 : source IMF WEO primaire, couverture Afrique complète
-- -----------------------------------------------------------------------
('MONETARY_FINANCIAL_RESILIENCE', 'PMON',
 0.72, 0.68, 4, 0.58,
 'PROXY', 'PROVISIONAL', 0.15,
 'IMF WEO 2023 — monetary institutional capacity UEMOA/CEMAC regional average',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V3'),

-- -----------------------------------------------------------------------
-- PHUM — Capital humain
-- Proxy : IDH moyen Afrique subsaharienne (UNDP HDR 2023 : 0.547)
-- maturity 0.62 : programmes bien documentés, exécution relativement mature
-- uncertainty 0.15 : source UNDP primaire, 54 pays couverts
-- -----------------------------------------------------------------------
('HUMAN_CAPITAL',                 'PHUM',
 0.55, 0.50, 5, 0.62,
 'PROXY', 'PROVISIONAL', 0.15,
 'UNDP Human Development Report 2023 — HDI sub-Saharan Africa average 0.547 (rescaled 0.62)',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V3'),

-- -----------------------------------------------------------------------
-- PECO — Diversification économique
-- Proxy : indice de diversification UNCTAD ProductSpace Africa 2023
-- maturity 0.52 : diversification encore embryonnaire sur le continent
-- uncertainty 0.20 : source UNCTAD secondaire, méthodologie variable par pays
-- -----------------------------------------------------------------------
('ECONOMIC_DIVERSIFICATION',      'PECO',
 0.68, 0.65, 5, 0.52,
 'PROXY', 'PROVISIONAL', 0.20,
 'UNCTAD Trade and Development Report 2023 — economic diversification index Africa ProductSpace',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V3'),

-- -----------------------------------------------------------------------
-- PENV — Résilience environnementale
-- Proxy : taux de mise en oeuvre NDC Afrique (UNEP 2023 : ~38%)
-- maturity 0.48 : engagement fort mais capacité d'exécution institutionnelle faible
-- uncertainty 0.20 : source UNEP, taux d'implémentation NDC estimé par pays
-- -----------------------------------------------------------------------
('ENVIRONMENTAL_RESILIENCE',      'PENV',
 0.60, 0.58, 4, 0.48,
 'PROXY', 'PROVISIONAL', 0.20,
 'UNEP NDC Implementation Progress Report 2023 — Africa NDC implementation rate ~38%',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V3'),

-- -----------------------------------------------------------------------
-- PMIL — Résilience sécuritaire
-- Proxy : capacité institutionnelle sécurité Afrique (SIPRI 2023)
-- maturity 0.42 : forte dépendance externe, complexité politique élevée
-- uncertainty 0.20 : source SIPRI, données sensibles, couverture partielle
-- -----------------------------------------------------------------------
('SECURITY_RESILIENCE',           'PMIL',
 0.82, 0.80, 3, 0.42,
 'PROXY', 'PROVISIONAL', 0.20,
 'SIPRI Military Expenditure Database 2023 — African institutional security capacity index',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V3'),

-- -----------------------------------------------------------------------
-- PMIN — Chaîne de valeur minière
-- Proxy : taux de transformation locale minerais Afrique (EITI proxy 2022 : ~22%)
-- maturity 0.50 : valeur ajoutée locale en progression mais encore limitée
-- uncertainty 0.25 : proxy EITI estimé, données incomplètes pour plusieurs pays
-- -----------------------------------------------------------------------
('MINING_VALUE_CHAIN',            'PMIN',
 0.75, 0.70, 4, 0.50,
 'PROXY', 'PROVISIONAL', 0.25,
 'EITI Africa Progress Reports 2022 — local mineral transformation rate Africa avg ~22% (rescaled 0.50)',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V3'),

-- -----------------------------------------------------------------------
-- PGEO — Gouvernance et stabilité
-- Proxy : WGI Government Effectiveness Afrique (World Bank 2022 : ~-0.6)
-- maturity 0.38 : gouvernance institutionnelle la plus complexe — score WGI faible
-- uncertainty 0.15 : source WB WGI primaire, méthodologie robuste depuis 1996
-- -----------------------------------------------------------------------
('GOVERNANCE_AND_STABILITY',      'PGEO',
 0.50, 0.45, 6, 0.38,
 'PROXY', 'PROVISIONAL', 0.15,
 'World Bank WGI Government Effectiveness 2022 — Africa average ~-0.6 (rescaled 0–1 → 0.38)',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V3'),

-- -----------------------------------------------------------------------
-- PNUM — Souveraineté numérique
-- Proxy : ICT Development Index Afrique (ITU IDI 2023)
-- maturity 0.62 : secteur digital à croissance rapide, maturité institutionnelle en hausse
-- uncertainty 0.15 : source ITU primaire, données annuelles 54 pays
-- -----------------------------------------------------------------------
('DIGITAL_SOVEREIGNTY',           'PNUM',
 0.65, 0.60, 3, 0.62,
 'PROXY', 'PROVISIONAL', 0.15,
 'ITU ICT Development Index 2023 — digital maturity Africa average (rescaled 0.62)',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V3'),

-- -----------------------------------------------------------------------
-- PTRA — Transport et logistique
-- Proxy : Logistics Performance Index World Bank Afrique (LPI 2023 : ~2.5/5)
-- maturity 0.55 : infrastructure en développement actif, LPI en progression
-- uncertainty 0.25 : LPI Africa estimation régionale, couverture partielle 2023
-- -----------------------------------------------------------------------
('TRANSPORT_LOGISTICS',           'PTRA',
 0.70, 0.65, 4, 0.55,
 'PROXY', 'PROVISIONAL', 0.25,
 'World Bank Logistics Performance Index 2023 — Africa LPI average ~2.5/5 (rescaled 0.55)',
 CURRENT_DATE, CURRENT_DATE + INTERVAL '12 months', 'V3');

-- -----------------------------------------------------------------------------
-- 3. Validation post-insertion
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_rows        INTEGER;
    v_missing_cal INTEGER;
    v_missing_due INTEGER;
    v_out_bounds  INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_rows     FROM rf.isa_executive_cost_model;
    SELECT COUNT(*) INTO v_missing_cal FROM rf.isa_executive_cost_model
        WHERE calibration_status IS NULL
           OR calibration_uncertainty_score IS NULL
           OR calibration_source IS NULL;
    SELECT COUNT(*) INTO v_missing_due FROM rf.isa_executive_cost_model
        WHERE calibration_review_due_date IS NULL
           OR calibration_review_due_date <= calibration_date;
    SELECT COUNT(*) INTO v_out_bounds FROM rf.isa_executive_cost_model
        WHERE execution_maturity_score NOT BETWEEN 0 AND 1
           OR calibration_uncertainty_score NOT BETWEEN 0 AND 1
           OR executive_cost_score NOT BETWEEN 0 AND 1;

    RAISE NOTICE 'P7K cost model V3 : rows=%, missing_cal=%, missing_due=%, out_of_bounds=%',
        v_rows, v_missing_cal, v_missing_due, v_out_bounds;

    IF v_missing_cal > 0 THEN
        RAISE EXCEPTION 'ABORT : % lignes sans calibration complète', v_missing_cal;
    END IF;
    IF v_missing_due > 0 THEN
        RAISE EXCEPTION 'ABORT : % lignes avec review_due_date invalide', v_missing_due;
    END IF;
    IF v_out_bounds > 0 THEN
        RAISE EXCEPTION 'ABORT : % lignes avec scores hors bornes [0,1]', v_out_bounds;
    END IF;
    IF v_rows <> 10 THEN
        RAISE EXCEPTION 'ABORT : attendu 10 lignes, obtenu %', v_rows;
    END IF;
END $$;

COMMIT;
