-- ============================================================
-- OSA / ISA — P7X
-- Patch: SWOT Strategic Intelligence Engine
-- Purpose:
--   Create RF policies and compatibility views for SWOT intelligence.
--   This patch is intentionally defensive: it does not assume the
--   internal column names of ma.computed_values or P7E views.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.swot_signal_policy (
    swot_type VARCHAR(10) PRIMARY KEY,
    swot_label TEXT NOT NULL,
    strategic_role TEXT NOT NULL,
    default_action TEXT NOT NULL,
    open_data_policy TEXT NOT NULL,
    premium_policy TEXT NOT NULL,
    eparticipation_policy TEXT NOT NULL,
    priority_weight NUMERIC(5,3) NOT NULL DEFAULT 0.700,
    notes TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

TRUNCATE TABLE rf.swot_signal_policy;
INSERT INTO rf.swot_signal_policy
(swot_type, swot_label, strategic_role, default_action, open_data_policy, premium_policy, eparticipation_policy, priority_weight, notes)
VALUES
('WKN','Weakness','WEAKNESS_TO_FIX','ATTENUATE_WEAKNESS','PUBLISH_OPPORTUNITY_STUDY','TRIGGER_FEASIBILITY_IF_HIGH','OPEN_COMMENTS_AND_EXPERT_REVIEW',0.900,'Faiblesses observées à atténuer par projets structurants.'),
('THR','Threat','THREAT_TO_MITIGATE','MITIGATE_THREAT','PUBLISH_RISK_OPPORTUNITY_STUDY','TRIGGER_URGENT_FEASIBILITY_IF_HIGH','OPEN_RISK_REVIEW_AND_EVIDENCE',0.950,'Menaces et risques observés à réduire.'),
('STR','Strength','STRENGTH_TO_SCALE','SCALE_STRENGTH','PUBLISH_SCALING_OPPORTUNITY_STUDY','TRIGGER_SCALING_FEASIBILITY','OPEN_BENCHMARK_DISCUSSION',0.750,'Forces observées à consolider et amplifier.'),
('OPP','Opportunity','OPPORTUNITY_TO_ACCELERATE','ACCELERATE_OPPORTUNITY','PUBLISH_INVESTMENT_OPPORTUNITY_STUDY','TRIGGER_PROTOTYPE_OR_POC','OPEN_CO_DESIGN_DISCUSSION',0.800,'Opportunités observées à accélérer.'),
('OBS','Observed Gap','OBSERVATION_GAP','DOCUMENT_AND_REVIEW','PUBLISH_DATA_GAP_NOTE','TRIGGER_DATA_CERTIFICATION_IF_CRITICAL','OPEN_DATA_QUALITY_REVIEW',0.650,'Signal de gap lorsque SWOT est absent mais la publication révèle une faiblesse.');

CREATE TABLE IF NOT EXISTS rf.structuring_project_catalog (
    project_family_code VARCHAR(40) PRIMARY KEY,
    pillar_code VARCHAR(10),
    project_family_label TEXT NOT NULL,
    strategic_objective TEXT NOT NULL,
    open_data_deliverable TEXT NOT NULL,
    premium_deliverable TEXT NOT NULL,
    default_priority NUMERIC(5,3) DEFAULT 0.700,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO rf.structuring_project_catalog
(project_family_code, pillar_code, project_family_label, strategic_objective, open_data_deliverable, premium_deliverable, default_priority)
VALUES
('GOVERNANCE_CAPACITY','PGEO','Renforcement gouvernance / stabilité','Réduire les risques institutionnels et géopolitiques','Note d’opportunité gouvernance souveraine','Étude de faisabilité institutionnelle + prototype dashboard',0.900),
('DIGITAL_SOVEREIGNTY','PNUM','Souveraineté numérique','Réduire les gaps numériques et cyber','Note d’opportunité numérique souveraine','Étude de faisabilité GovTech / cyber / data platform',0.850),
('ENERGY_WATER_CERTIFICATION','PRES','Certification énergie-eau','Certifier les données physiques PRES et structurer les projets ressource','Note d’opportunité énergie/eau','Étude de faisabilité énergie/eau + prototype observatoire',0.950),
('TRANSPORT_LOGISTICS','PTRA','Transport et logistique souveraine','Renforcer réseaux, hubs et corridors','Note d’opportunité transport/logistique','Étude de faisabilité corridor/hub/logistique',0.800),
('MINING_VALUE_CHAIN','PMIN','Chaîne de valeur minière','Transformer l’avantage physique en souveraineté économique','Note d’opportunité chaîne minière','Étude de faisabilité SNCTM/FST/industrialisation',0.900),
('HUMAN_CAPITAL','PHUM','Capital humain et résilience sociale','Réduire fragilités humaines et renforcer capacités','Note d’opportunité capital humain','Étude de faisabilité programmes sociaux/G2P/formation',0.850),
('ECONOMIC_DIVERSIFICATION','PECO','Diversification économique','Réduire dépendances et chômage, renforcer valeur ajoutée','Note d’opportunité diversification','Étude de faisabilité filière/PME/industrie',0.850),
('MONETARY_FINANCIAL_RESILIENCE','PMON','Résilience monétaire et financière','Réduire vulnérabilités dette, inflation, change','Note d’opportunité résilience financière','Étude de faisabilité mécanismes financiers souverains',0.900),
('ENVIRONMENTAL_RESILIENCE','PENV','Résilience environnementale','Réduire risques climatiques et environnementaux','Note d’opportunité environnement/climat','Étude de faisabilité carbone/e-cadastre/agroforesterie',0.850),
('SECURITY_RESILIENCE','PMIL','Résilience sécurité/défense','Réduire risques sécuritaires et dépendances critiques','Note d’opportunité sécurité résiliente','Étude de faisabilité sécurité/industrie défense/alerte',0.850)
ON CONFLICT (project_family_code) DO UPDATE SET
    pillar_code = EXCLUDED.pillar_code,
    project_family_label = EXCLUDED.project_family_label,
    strategic_objective = EXCLUDED.strategic_objective,
    open_data_deliverable = EXCLUDED.open_data_deliverable,
    premium_deliverable = EXCLUDED.premium_deliverable,
    default_priority = EXCLUDED.default_priority,
    updated_at = CURRENT_TIMESTAMP;

CREATE TABLE IF NOT EXISTS rf.premium_feasibility_policy (
    trigger_code VARCHAR(40) PRIMARY KEY,
    trigger_label TEXT NOT NULL,
    min_priority_score NUMERIC(5,3) NOT NULL,
    min_threat_score NUMERIC(5,3) NOT NULL DEFAULT 0.700,
    min_weakness_score NUMERIC(5,3) NOT NULL DEFAULT 0.650,
    premium_action TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

TRUNCATE TABLE rf.premium_feasibility_policy;
INSERT INTO rf.premium_feasibility_policy
(trigger_code, trigger_label, min_priority_score, min_threat_score, min_weakness_score, premium_action)
VALUES
('PREMIUM_URGENT','Urgent feasibility trigger',0.800,0.800,0.750,'FEASIBILITY_STUDY_URGENT'),
('PREMIUM_STANDARD','Standard feasibility trigger',0.650,0.700,0.650,'FEASIBILITY_STUDY_STANDARD'),
('PREMIUM_PROTOTYPE','Prototype / POC trigger',0.700,0.600,0.600,'PROTOTYPE_OR_POC'),
('OPEN_ONLY','Open opportunity only',0.000,0.000,0.000,'OPEN_DATA_OPPORTUNITY_STUDY_ONLY');

-- ------------------------------------------------------------
-- Compatibility view 1: ma.v_p7x_computed_swot_source
-- Exposes stable columns from ma.computed_values without assuming names.
-- ------------------------------------------------------------
DO $$
DECLARE
    has_table BOOLEAN;
    code_col TEXT;
    country_col TEXT;
    year_col TEXT;
    pillar_col TEXT;
    value_col TEXT;
    sql TEXT;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema='ma' AND table_name='computed_values'
    ) INTO has_table;

    IF NOT has_table THEN
        EXECUTE 'CREATE OR REPLACE VIEW ma.v_p7x_computed_swot_source AS
                 SELECT NULL::text AS swot_code, NULL::text AS swot_type, NULL::text AS country_iso3,
                        NULL::int AS year, NULL::text AS pillar_code, NULL::numeric AS swot_value,
                        ''MISSING_TABLE''::text AS compatibility_status WHERE FALSE';
        RETURN;
    END IF;

    SELECT column_name INTO code_col
    FROM information_schema.columns
    WHERE table_schema='ma' AND table_name='computed_values'
      AND column_name IN ('computed_code','indicator_code','code','metric_code','signal_code','name')
    ORDER BY CASE column_name
        WHEN 'computed_code' THEN 1 WHEN 'indicator_code' THEN 2 WHEN 'code' THEN 3
        WHEN 'metric_code' THEN 4 WHEN 'signal_code' THEN 5 ELSE 9 END
    LIMIT 1;

    SELECT column_name INTO country_col
    FROM information_schema.columns
    WHERE table_schema='ma' AND table_name='computed_values'
      AND column_name IN ('country_iso3','iso3','country_code')
    ORDER BY CASE column_name WHEN 'country_iso3' THEN 1 WHEN 'iso3' THEN 2 ELSE 3 END
    LIMIT 1;

    SELECT column_name INTO year_col
    FROM information_schema.columns
    WHERE table_schema='ma' AND table_name='computed_values'
      AND column_name IN ('year','annee')
    ORDER BY CASE column_name WHEN 'year' THEN 1 ELSE 2 END
    LIMIT 1;

    SELECT column_name INTO pillar_col
    FROM information_schema.columns
    WHERE table_schema='ma' AND table_name='computed_values'
      AND column_name IN ('pillar_code','pillar','domain_code')
    ORDER BY CASE column_name WHEN 'pillar_code' THEN 1 WHEN 'pillar' THEN 2 ELSE 3 END
    LIMIT 1;

    SELECT column_name INTO value_col
    FROM information_schema.columns
    WHERE table_schema='ma' AND table_name='computed_values'
      AND column_name IN ('computed_value','value','processed_value','score','raw_value')
    ORDER BY CASE column_name
        WHEN 'computed_value' THEN 1 WHEN 'value' THEN 2 WHEN 'processed_value' THEN 3
        WHEN 'score' THEN 4 ELSE 5 END
    LIMIT 1;

    IF code_col IS NULL OR country_col IS NULL OR year_col IS NULL OR value_col IS NULL THEN
        EXECUTE 'CREATE OR REPLACE VIEW ma.v_p7x_computed_swot_source AS
                 SELECT NULL::text AS swot_code, NULL::text AS swot_type, NULL::text AS country_iso3,
                        NULL::int AS year, NULL::text AS pillar_code, NULL::numeric AS swot_value,
                        ''MISSING_REQUIRED_COLUMNS''::text AS compatibility_status WHERE FALSE';
        RETURN;
    END IF;

    sql := format($f$
        CREATE OR REPLACE VIEW ma.v_p7x_computed_swot_source AS
        SELECT
            (%1$I)::text AS swot_code,
            CASE
                WHEN (%1$I)::text LIKE 'WKN_%%' THEN 'WKN'
                WHEN (%1$I)::text LIKE 'THR_%%' THEN 'THR'
                WHEN (%1$I)::text LIKE 'STR_%%' THEN 'STR'
                WHEN (%1$I)::text LIKE 'OPP_%%' THEN 'OPP'
                ELSE 'OTHER'
            END::text AS swot_type,
            (%2$I)::text AS country_iso3,
            (%3$I)::int AS year,
            %4$s AS pillar_code,
            (%5$I)::numeric AS swot_value,
            'OK'::text AS compatibility_status
        FROM ma.computed_values
        WHERE (%1$I)::text LIKE 'WKN_%%'
           OR (%1$I)::text LIKE 'THR_%%'
           OR (%1$I)::text LIKE 'STR_%%'
           OR (%1$I)::text LIKE 'OPP_%%'
    $f$,
    code_col,
    country_col,
    year_col,
    CASE WHEN pillar_col IS NOT NULL THEN format('(%I)::text', pillar_col)
         ELSE format('NULLIF(split_part((%I)::text,''_'',2),'''')::text', code_col) END,
    value_col);

    EXECUTE sql;
END $$;

-- ------------------------------------------------------------
-- Compatibility view 2: ma.v_p7x_observed_pillar_source
-- Exposes stable columns from P7E pillar scores.
-- ------------------------------------------------------------
DO $$
DECLARE
    has_view BOOLEAN;
    has_col BOOLEAN;
    select_sql TEXT;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar'
    ) INTO has_view;

    IF NOT has_view THEN
        EXECUTE 'CREATE OR REPLACE VIEW ma.v_p7x_observed_pillar_source AS
                 SELECT NULL::text country_iso3, NULL::int year, NULL::text pillar_code,
                        NULL::numeric isa_observed_score, NULL::numeric sovereignty_observed_score,
                        NULL::numeric vulnerability_observed_score, NULL::numeric resilience_observed_score,
                        NULL::numeric data_completeness, NULL::numeric observation_confidence,
                        NULL::text publication_status, NULL::text publication_decision
                 WHERE FALSE';
        RETURN;
    END IF;

    select_sql := 'CREATE OR REPLACE VIEW ma.v_p7x_observed_pillar_source AS SELECT ';

    select_sql := select_sql || CASE WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar' AND column_name='country_iso3')
        THEN 'country_iso3::text AS country_iso3,' ELSE '''UNK''::text AS country_iso3,' END;
    select_sql := select_sql || CASE WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar' AND column_name='year')
        THEN 'year::int AS year,' ELSE 'NULL::int AS year,' END;
    select_sql := select_sql || CASE WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar' AND column_name='pillar_code')
        THEN 'pillar_code::text AS pillar_code,' ELSE '''UNK''::text AS pillar_code,' END;
    select_sql := select_sql || CASE WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar' AND column_name='isa_observed_score')
        THEN 'COALESCE(isa_observed_score,0)::numeric AS isa_observed_score,' ELSE '0::numeric AS isa_observed_score,' END;
    select_sql := select_sql || CASE WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar' AND column_name='sovereignty_observed_score')
        THEN 'COALESCE(sovereignty_observed_score,0)::numeric AS sovereignty_observed_score,' ELSE '0::numeric AS sovereignty_observed_score,' END;
    select_sql := select_sql || CASE WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar' AND column_name='vulnerability_observed_score')
        THEN 'COALESCE(vulnerability_observed_score,0)::numeric AS vulnerability_observed_score,' ELSE '0::numeric AS vulnerability_observed_score,' END;
    select_sql := select_sql || CASE WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar' AND column_name='resilience_observed_score')
        THEN 'COALESCE(resilience_observed_score,0)::numeric AS resilience_observed_score,' ELSE '0::numeric AS resilience_observed_score,' END;
    select_sql := select_sql || CASE WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar' AND column_name='data_completeness')
        THEN 'COALESCE(data_completeness,0)::numeric AS data_completeness,' ELSE '0::numeric AS data_completeness,' END;
    select_sql := select_sql || CASE WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar' AND column_name='observation_confidence')
        THEN 'COALESCE(observation_confidence,0)::numeric AS observation_confidence,' ELSE '0::numeric AS observation_confidence,' END;
    select_sql := select_sql || CASE WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar' AND column_name='publication_status')
        THEN 'publication_status::text AS publication_status,' ELSE '''UNKNOWN''::text AS publication_status,' END;
    select_sql := select_sql || CASE WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ma' AND table_name='v_isa_observed_scores_by_pillar' AND column_name='publication_decision')
        THEN 'publication_decision::text AS publication_decision' ELSE '''OBSERVE_ONLY''::text AS publication_decision' END;

    select_sql := select_sql || ' FROM ma.v_isa_observed_scores_by_pillar';
    EXECUTE select_sql;
END $$;

CREATE INDEX IF NOT EXISTS idx_swot_signal_policy_role ON rf.swot_signal_policy(strategic_role);

DO $$
DECLARE n INT;
BEGIN
    SELECT COUNT(*) INTO n FROM rf.swot_signal_policy;
    RAISE NOTICE 'P7X SWOT signal policy lignes : %', n;
END $$;

COMMIT;
