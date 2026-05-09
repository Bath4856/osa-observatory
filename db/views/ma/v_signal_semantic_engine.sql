-- ============================================================
-- OSA / ISA — P7A1
-- Vue : ma.v_signal_semantic_engine
-- Rôle : classifier sémantiquement les indicateurs ISA
-- Priorité : rf.indicator_nature puis heuristiques par code/pilier
-- ============================================================

CREATE OR REPLACE VIEW ma.v_signal_semantic_engine AS

WITH indicators AS (
    SELECT
        i.code AS indicator_code,
        i.pillar_code,
        COALESCE(i.name_fr, i.name_en, i.code) AS indicator_name,
        COALESCE(n.nature_code, 'UNCLASSIFIED') AS nature_code,
        COALESCE(n.confidence_policy, 'UNKNOWN') AS confidence_policy,
        COALESCE(n.physical_weight, 0.50) AS physical_weight,
        COALESCE(n.imputation_allowed, TRUE) AS imputation_allowed,
        COALESCE(n.exclusion_threshold, 0.40) AS governance_threshold
    FROM rf.indicators i
    LEFT JOIN rf.indicator_nature n
        ON n.indicator_code = i.code
),
classified AS (
    SELECT
        indicator_code,
        pillar_code,
        indicator_name,
        nature_code,
        confidence_policy,
        physical_weight,
        imputation_allowed,
        governance_threshold,

        CASE
            -- 1. Classification explicite déjà gouvernée
            WHEN nature_code IN ('PHYSICAL','STRUCTURAL','EVENT','COMPOSITE','PERCEPTION','GEO')
                THEN nature_code

            -- 2. Heuristiques par code indicateur
            WHEN indicator_code ~* '(_RES|RESERVE|STOCK|CAPACITY|CAP_)' THEN 'STOCK'
            WHEN indicator_code ~* '(_FLOW|FLOW|TRADE|TRD|EXP|IMP|PASSENGERS|CARGO|MIG)' THEN 'FLOW'
            WHEN indicator_code ~* '(_DEP|DEPEND|DEPENDENCY|IMPORT_DEP|EXT_DEP)' THEN 'DEPENDENCY'
            WHEN indicator_code ~* '(_GOV|GOVERN|REG|RULE|CTRL|CONTROL|TAX|CERT|TRAC)' THEN 'GOVERNANCE'
            WHEN indicator_code ~* '(_NET|NETWORK|CONNECT|HUB|PORT|ROAD|AIR|BROADBAND|MOBILE|INTERNET)' THEN 'NETWORK'
            WHEN indicator_code ~* '(_SEC|SECURITY|TERROR|HOMICIDE|CONFLICT|EVENT|ACLED|WAR|CRISIS)' THEN 'EVENT'
            WHEN indicator_code ~* '(_RISK|PRESSURE|STRESS|VULN|THR_|THREAT|INSTABILITY)' THEN 'PRESSURE'
            WHEN indicator_code ~* '(_RESIL|RESILIENCE|ADAPT|RECOVERY)' THEN 'RESILIENCE'
            WHEN indicator_code ~* '(_DIV|COMPOSITE|INDEX|SCORE|CRI|WKN_|OPP_|FRC_|FOR_)' THEN 'COMPOSITE'

            -- 3. Heuristiques par pilier
            WHEN pillar_code = 'PMIN' THEN 'STOCK'
            WHEN pillar_code = 'PRES' THEN 'PHYSICAL'
            WHEN pillar_code = 'PTRA' THEN 'NETWORK'
            WHEN pillar_code = 'PMON' THEN 'GOVERNANCE'
            WHEN pillar_code = 'PGEO' THEN 'GEO'
            WHEN pillar_code = 'PMIL' THEN 'EVENT'
            WHEN pillar_code = 'PNUM' THEN 'NETWORK'
            WHEN pillar_code = 'PENV' THEN 'PRESSURE'
            WHEN pillar_code = 'PECO' THEN 'FLOW'
            WHEN pillar_code = 'PHUM' THEN 'RESILIENCE'

            ELSE 'UNCLASSIFIED'
        END AS semantic_code,

        CASE
            WHEN nature_code IN ('PHYSICAL','STRUCTURAL','EVENT','COMPOSITE','PERCEPTION','GEO') THEN 0.95
            WHEN indicator_code ~* '(_RES|RESERVE|STOCK|CAPACITY|CAP_|_FLOW|FLOW|TRADE|TRD|EXP|IMP|_DEP|DEPEND|_GOV|GOVERN|_NET|NETWORK|CONNECT|_SEC|SECURITY|TERROR|HOMICIDE|CONFLICT|_RISK|PRESSURE|_DIV|COMPOSITE|INDEX|SCORE)' THEN 0.80
            WHEN pillar_code IN ('PMIN','PRES','PTRA','PMON','PGEO','PMIL','PNUM','PENV','PECO','PHUM') THEN 0.65
            ELSE 0.30
        END::NUMERIC(4,3) AS semantic_confidence,

        CASE
            WHEN nature_code IN ('PHYSICAL','STRUCTURAL','EVENT','COMPOSITE','PERCEPTION','GEO') THEN 'RF_INDICATOR_NATURE'
            WHEN indicator_code ~* '(_RES|RESERVE|STOCK|CAPACITY|CAP_|_FLOW|FLOW|TRADE|TRD|EXP|IMP|_DEP|DEPEND|_GOV|GOVERN|_NET|NETWORK|CONNECT|_SEC|SECURITY|TERROR|HOMICIDE|CONFLICT|_RISK|PRESSURE|_DIV|COMPOSITE|INDEX|SCORE)' THEN 'CODE_PATTERN_HEURISTIC'
            WHEN pillar_code IN ('PMIN','PRES','PTRA','PMON','PGEO','PMIL','PNUM','PENV','PECO','PHUM') THEN 'PILLAR_DEFAULT_HEURISTIC'
            ELSE 'UNCLASSIFIED_FALLBACK'
        END AS semantic_source,

        CASE
            WHEN nature_code = 'UNCLASSIFIED' THEN 'NATURE_MISSING_CLASSIFIED_BY_P7A1'
            ELSE 'NATURE_ALREADY_GOVERNED'
        END AS fallback_reason
    FROM indicators
)
SELECT
    c.indicator_code,
    c.pillar_code,
    c.indicator_name,
    c.nature_code,
    c.confidence_policy,
    c.physical_weight,
    c.imputation_allowed,
    c.governance_threshold,

    c.semantic_code,
    p.semantic_label,
    c.semantic_confidence,
    c.semantic_source,
    c.fallback_reason,

    p.risk_weight,
    p.strategic_weight,
    p.volatility_weight,
    p.ml_importance,
    p.physicality,
    p.dependency_factor,
    p.resilience_factor,
    p.forecastability,

    CASE
        WHEN c.semantic_code = 'UNCLASSIFIED' THEN 'TO_REVIEW'
        WHEN c.semantic_confidence < 0.50 THEN 'LOW_CONFIDENCE_SEMANTIC'
        WHEN c.semantic_source = 'PILLAR_DEFAULT_HEURISTIC' THEN 'REVIEW_RECOMMENDED'
        ELSE 'OK'
    END AS semantic_governance_status
FROM classified c
LEFT JOIN ma.signal_semantic_policy p
    ON p.semantic_code = c.semantic_code;
