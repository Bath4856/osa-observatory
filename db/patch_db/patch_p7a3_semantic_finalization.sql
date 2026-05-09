-- ============================================================
-- OSA / ISA — P7A3
-- Strategic Semantic Finalization
-- Objet : règles hybrides, priorité sémantique, dominance stratégique
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS ma.semantic_hybrid_rules (
    rule_code VARCHAR(80) PRIMARY KEY,
    indicator_code VARCHAR(30) NOT NULL,
    primary_semantic_code VARCHAR(30) NOT NULL,
    secondary_semantic_code VARCHAR(30),
    tertiary_semantic_code VARCHAR(30),
    dominance_weight NUMERIC(4,3) DEFAULT 0.800,
    hybrid_weight NUMERIC(4,3) DEFAULT 0.200,
    strategic_criticality NUMERIC(4,3) DEFAULT 0.700,
    forecastability_boost NUMERIC(4,3) DEFAULT 0.050,
    status_override VARCHAR(40) DEFAULT 'OK_HYBRID',
    rationale TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_semantic_hybrid_rules_indicator
    ON ma.semantic_hybrid_rules(indicator_code);

CREATE INDEX IF NOT EXISTS idx_semantic_hybrid_rules_primary
    ON ma.semantic_hybrid_rules(primary_semantic_code);

CREATE TABLE IF NOT EXISTS ma.semantic_priority_matrix (
    semantic_code VARCHAR(30) PRIMARY KEY,
    priority_rank SMALLINT NOT NULL,
    sovereignty_weight NUMERIC(4,3) DEFAULT 0.500,
    gap_sensitivity NUMERIC(4,3) DEFAULT 0.500,
    ml_priority NUMERIC(4,3) DEFAULT 0.500,
    description TEXT,
    updated_at TIMESTAMP DEFAULT now()
);

INSERT INTO ma.semantic_priority_matrix
(semantic_code, priority_rank, sovereignty_weight, gap_sensitivity, ml_priority, description)
VALUES
('PHYSICAL',    1, 0.950, 0.900, 0.900, 'Ressource ou capacité physique vérifiable'),
('STOCK',       2, 0.900, 0.850, 0.850, 'Réserve, stock, capital naturel ou stratégique'),
('STRUCTURAL',  3, 0.850, 0.750, 0.850, 'Capacité structurelle ou infrastructurelle'),
('GOVERNANCE',  4, 0.820, 0.800, 0.800, 'Règle, institution, pilotage ou souveraineté de décision'),
('DEPENDENCY',  5, 0.800, 0.900, 0.820, 'Dépendance externe ou vulnérabilité relationnelle'),
('PRESSURE',    6, 0.780, 0.920, 0.850, 'Stress, pression, risque ou contrainte'),
('NETWORK',     7, 0.720, 0.650, 0.760, 'Réseau, connectivité, infrastructure relationnelle'),
('FLOW',        8, 0.680, 0.550, 0.720, 'Flux économique, humain, informationnel ou logistique'),
('RESILIENCE',  9, 0.760, 0.600, 0.750, 'Capacité d’absorption ou de rebond'),
('GEO',        10, 0.780, 0.850, 0.780, 'Géopolitique, position stratégique, influence'),
('EVENT',      11, 0.650, 0.800, 0.700, 'Événement, choc, conflit ou rupture'),
('COMPOSITE',  12, 0.620, 0.500, 0.780, 'Agrégat construit'),
('PERCEPTION', 13, 0.450, 0.450, 0.600, 'Perception, enquête ou appréciation qualitative')
ON CONFLICT (semantic_code) DO UPDATE SET
    priority_rank = EXCLUDED.priority_rank,
    sovereignty_weight = EXCLUDED.sovereignty_weight,
    gap_sensitivity = EXCLUDED.gap_sensitivity,
    ml_priority = EXCLUDED.ml_priority,
    description = EXCLUDED.description,
    updated_at = now();

-- Règles stratégiques explicites sur les 89 restants P7A2 les plus structurants.
INSERT INTO ma.semantic_hybrid_rules
(rule_code, indicator_code, primary_semantic_code, secondary_semantic_code, tertiary_semantic_code,
 dominance_weight, hybrid_weight, strategic_criticality, forecastability_boost, status_override, rationale)
VALUES
-- PENV
('P7A3_ENV_ADA_RESILIENCE_PRESSURE', 'ENV_ADA', 'RESILIENCE', 'PRESSURE', NULL, 0.78, 0.22, 0.82, 0.06, 'OK_HYBRID', 'Adaptation climatique : capacité de résilience sous pression climatique'),
('P7A3_ENV_BIO_STOCK_PRESSURE', 'ENV_BIO', 'STOCK', 'PRESSURE', NULL, 0.80, 0.20, 0.84, 0.05, 'OK_HYBRID', 'Biodiversité : capital naturel exposé aux pressions'),
('P7A3_ENV_ECO_RESILIENCE_STOCK', 'ENV_ECO', 'RESILIENCE', 'STOCK', NULL, 0.78, 0.22, 0.80, 0.05, 'OK_HYBRID', 'Résilience écologique : capacité de maintien du capital naturel'),
('P7A3_ENV_ENE_PRESSURE_FLOW', 'ENV_ENE', 'PRESSURE', 'FLOW', NULL, 0.82, 0.18, 0.78, 0.04, 'OK_HYBRID', 'Intensité énergétique : pression de consommation'),
('P7A3_ENV_ENR_RESILIENCE_PHYSICAL', 'ENV_ENR', 'RESILIENCE', 'PHYSICAL', NULL, 0.76, 0.24, 0.82, 0.06, 'OK_HYBRID', 'Renouvelables : résilience de transition et capacité physique'),
('P7A3_ENV_FIS_STOCK_PHYSICAL', 'ENV_FIS', 'STOCK', 'PHYSICAL', NULL, 0.82, 0.18, 0.80, 0.05, 'OK_HYBRID', 'Stocks halieutiques : ressource physique stockée'),
('P7A3_ENV_LAN_PRESSURE_STOCK', 'ENV_LAN', 'PRESSURE', 'STOCK', NULL, 0.82, 0.18, 0.82, 0.04, 'OK_HYBRID', 'Dégradation des terres : pression sur capital foncier naturel'),
('P7A3_ENV_POL_PRESSURE', 'ENV_POL', 'PRESSURE', NULL, NULL, 0.88, 0.12, 0.78, 0.04, 'OK_STRATEGIC', 'Pollution : pression environnementale directe'),
('P7A3_ENV_PRO_STOCK_GOVERNANCE', 'ENV_PRO', 'STOCK', 'GOVERNANCE', NULL, 0.76, 0.24, 0.76, 0.04, 'OK_HYBRID', 'Aires protégées : stock naturel sous gouvernance'),
('P7A3_ENV_REF_RESILIENCE_STOCK', 'ENV_REF', 'RESILIENCE', 'STOCK', NULL, 0.78, 0.22, 0.80, 0.05, 'OK_HYBRID', 'Reforestation : restauration du stock forestier'),
('P7A3_ENV_SOL_STOCK_PHYSICAL', 'ENV_SOL', 'STOCK', 'PHYSICAL', NULL, 0.80, 0.20, 0.78, 0.04, 'OK_HYBRID', 'Fertilité des sols : capital naturel physique'),

-- PGEO
('P7A3_GEO_ALL_NETWORK_GOVERNANCE', 'GEO_ALL', 'NETWORK', 'GOVERNANCE', 'GEO', 0.74, 0.26, 0.78, 0.04, 'OK_MULTI_SEMANTIC', 'Alliances : réseau stratégique gouverné'),
('P7A3_GEO_CONF_EVENT_PRESSURE', 'GEO_CONF', 'EVENT', 'PRESSURE', 'GEO', 0.72, 0.28, 0.86, 0.06, 'OK_MULTI_SEMANTIC', 'Intensité conflictuelle : événement et pression géopolitique'),
('P7A3_GEO_CUL_GEO_NETWORK', 'GEO_CUL', 'GEO', 'NETWORK', NULL, 0.78, 0.22, 0.70, 0.03, 'OK_HYBRID', 'Influence culturelle : géopolitique de soft power'),
('P7A3_GEO_ORG_NETWORK_GOVERNANCE', 'GEO_ORG', 'NETWORK', 'GOVERNANCE', 'GEO', 0.76, 0.24, 0.76, 0.04, 'OK_MULTI_SEMANTIC', 'Organisations internationales : réseau institutionnel'),
('P7A3_GEO_PEA_EVENT_NETWORK', 'GEO_PEA', 'EVENT', 'NETWORK', 'GEO', 0.74, 0.26, 0.78, 0.05, 'OK_MULTI_SEMANTIC', 'Opérations de paix : engagement géopolitique événementiel'),
('P7A3_GEO_POW_GEO_GOVERNANCE', 'GEO_POW', 'GEO', 'GOVERNANCE', NULL, 0.82, 0.18, 0.84, 0.05, 'OK_HYBRID', 'Influence régionale : puissance géopolitique gouvernée'),
('P7A3_GEO_SOF_GEO_NETWORK', 'GEO_SOF', 'GEO', 'NETWORK', NULL, 0.80, 0.20, 0.74, 0.04, 'OK_HYBRID', 'Soft power : influence géopolitique relationnelle'),
('P7A3_GEO_STAB_RESILIENCE_GOVERNANCE', 'GEO_STAB', 'RESILIENCE', 'GOVERNANCE', 'GEO', 0.74, 0.26, 0.86, 0.06, 'OK_MULTI_SEMANTIC', 'Stabilité politique : résilience institutionnelle'),
('P7A3_GEO_TER_PRESSURE_EVENT', 'GEO_TER', 'PRESSURE', 'EVENT', NULL, 0.82, 0.18, 0.88, 0.05, 'OK_HYBRID', 'Impact humain des conflits : pression sécuritaire'),
('P7A3_PGEO_CIV_PRESSURE_EVENT', 'PGEO_CIV', 'PRESSURE', 'EVENT', NULL, 0.84, 0.16, 0.88, 0.05, 'OK_HYBRID', 'Ciblage des civils : pression conflictuelle'),
('P7A3_PGEO_COR_GOVERNANCE_PRESSURE', 'PGEO_COR', 'GOVERNANCE', 'PRESSURE', NULL, 0.82, 0.18, 0.84, 0.05, 'OK_HYBRID', 'Contrôle corruption : gouvernance sous pression'),
('P7A3_PGEO_EVT_EVENT_GEO', 'PGEO_EVT', 'EVENT', 'GEO', NULL, 0.84, 0.16, 0.82, 0.05, 'OK_HYBRID', 'Nombre événements : événement géopolitique'),
('P7A3_PGEO_FAT_PRESSURE_EVENT', 'PGEO_FAT', 'PRESSURE', 'EVENT', NULL, 0.84, 0.16, 0.88, 0.05, 'OK_HYBRID', 'Fatalités : pression de conflit'),
('P7A3_PGEO_INS_PRESSURE_EVENT', 'PGEO_INS', 'PRESSURE', 'EVENT', NULL, 0.82, 0.18, 0.84, 0.05, 'OK_HYBRID', 'Intensité moyenne : pression conflictualité'),
('P7A3_PGEO_INT_EVENT_GEO', 'PGEO_INT', 'EVENT', 'GEO', NULL, 0.78, 0.22, 0.80, 0.04, 'OK_HYBRID', 'Conflits internes : événement géopolitique'),
('P7A3_PGEO_PRE_PRESSURE_EVENT', 'PGEO_PRE', 'PRESSURE', 'EVENT', NULL, 0.84, 0.16, 0.86, 0.05, 'OK_HYBRID', 'Pression cumulée : pression sécuritaire'),
('P7A3_PGEO_SPR_GEO_NETWORK', 'PGEO_SPR', 'GEO', 'NETWORK', NULL, 0.78, 0.22, 0.78, 0.04, 'OK_HYBRID', 'Dispersion spatiale : géographie du risque'),
('P7A3_PGEO_STR_PRESSURE_EVENT', 'PGEO_STR', 'PRESSURE', 'EVENT', NULL, 0.78, 0.22, 0.82, 0.04, 'OK_HYBRID', 'Structure victimes : pression humaine du conflit'),
('P7A3_PGEO_PEAK_EVENT_PRESSURE', 'PGEO_PEAK', 'EVENT', 'PRESSURE', NULL, 0.74, 0.26, 0.72, 0.03, 'OK_HYBRID', 'Année de pic : événement de rupture'),

-- PHUM
('P7A3_HUM_GEN_GOVERNANCE_RESILIENCE', 'HUM_GEN', 'GOVERNANCE', 'RESILIENCE', NULL, 0.72, 0.28, 0.72, 0.04, 'OK_HYBRID', 'Genre : gouvernance sociale et résilience'),
('P7A3_HUM_HEA2_RESILIENCE_STRUCTURAL', 'HUM_HEA2', 'RESILIENCE', 'STRUCTURAL', NULL, 0.78, 0.22, 0.78, 0.05, 'OK_HYBRID', 'Accès santé : résilience humaine et capacité structurelle'),
('P7A3_HUM_LIT_RESILIENCE_STRUCTURAL', 'HUM_LIT', 'RESILIENCE', 'STRUCTURAL', NULL, 0.78, 0.22, 0.76, 0.05, 'OK_HYBRID', 'Alphabétisation : capital humain résilient'),
('P7A3_HUM_SAN_STRUCTURAL_RESILIENCE', 'HUM_SAN', 'STRUCTURAL', 'RESILIENCE', NULL, 0.76, 0.24, 0.76, 0.04, 'OK_HYBRID', 'Assainissement : infrastructure sociale'),
('P7A3_HUM_WAT_STRUCTURAL_RESILIENCE', 'HUM_WAT', 'STRUCTURAL', 'RESILIENCE', NULL, 0.76, 0.24, 0.78, 0.04, 'OK_HYBRID', 'Eau potable : infrastructure sociale critique'),

-- PMIL
('P7A3_MIL_BRD_STRUCTURAL_PRESSURE', 'MIL_BRD', 'STRUCTURAL', 'PRESSURE', NULL, 0.78, 0.22, 0.80, 0.04, 'OK_HYBRID', 'Frontières : capacité structurelle sous pression'),
('P7A3_MIL_EQU_STRUCTURAL', 'MIL_EQU', 'STRUCTURAL', NULL, NULL, 0.88, 0.12, 0.78, 0.04, 'OK_STRATEGIC', 'Équipement militaire : capacité structurelle'),
('P7A3_MIL_IND_STRUCTURAL_GOVERNANCE', 'MIL_IND', 'STRUCTURAL', 'GOVERNANCE', NULL, 0.82, 0.18, 0.78, 0.04, 'OK_HYBRID', 'Industrie défense : souveraineté industrielle'),
('P7A3_MIL_INT_NETWORK_STRUCTURAL', 'MIL_INT', 'NETWORK', 'STRUCTURAL', NULL, 0.76, 0.24, 0.72, 0.04, 'OK_HYBRID', 'Interopérabilité : réseau capacitaire'),
('P7A3_MIL_PER_STRUCTURAL', 'MIL_PER', 'STRUCTURAL', NULL, NULL, 0.88, 0.12, 0.76, 0.04, 'OK_STRATEGIC', 'Personnel militaire : capacité structurelle'),
('P7A3_MIL_STB_RESILIENCE_GOVERNANCE', 'MIL_STB', 'RESILIENCE', 'GOVERNANCE', NULL, 0.78, 0.22, 0.80, 0.05, 'OK_HYBRID', 'Stabilité forces : résilience sécuritaire'),
('P7A3_MIL_STR_STRUCTURAL_NETWORK', 'MIL_STR', 'STRUCTURAL', 'NETWORK', NULL, 0.80, 0.20, 0.78, 0.04, 'OK_HYBRID', 'Projection : capacité structurelle et réseau'),
('P7A3_MIL_TER_PRESSURE_EVENT', 'MIL_TER', 'PRESSURE', 'EVENT', NULL, 0.84, 0.16, 0.86, 0.05, 'OK_HYBRID', 'Terrorisme : pression sécuritaire'),

-- PMIN / PMON / PNUM / PRES / PTRA
('P7A3_MIN_TAX_GOVERNANCE_FLOW', 'MIN_TAX', 'GOVERNANCE', 'FLOW', NULL, 0.80, 0.20, 0.78, 0.04, 'OK_HYBRID', 'Fiscalité minière : gouvernance des flux'),
('P7A3_MIN_VAL_FLOW_STOCK', 'MIN_VAL', 'FLOW', 'STOCK', NULL, 0.78, 0.22, 0.76, 0.04, 'OK_HYBRID', 'Valeur ajoutée minière : flux issu du stock'),
('P7A3_MON_CHG_GOVERNANCE_PRESSURE', 'MON_CHG', 'GOVERNANCE', 'PRESSURE', NULL, 0.80, 0.20, 0.78, 0.04, 'OK_HYBRID', 'Régime de change : gouvernance exposée aux pressions'),
('P7A3_MON_CUR_GOVERNANCE_PRESSURE', 'MON_CUR', 'GOVERNANCE', 'PRESSURE', NULL, 0.80, 0.20, 0.80, 0.04, 'OK_HYBRID', 'Stabilité monétaire : gouvernance et pression'),
('P7A3_MON_DET_DEPENDENCY_PRESSURE', 'MON_DET', 'DEPENDENCY', 'PRESSURE', NULL, 0.82, 0.18, 0.82, 0.05, 'OK_HYBRID', 'Service dette : dépendance financière'),
('P7A3_MON_FIN_STRUCTURAL_FLOW', 'MON_FIN', 'STRUCTURAL', 'FLOW', NULL, 0.78, 0.22, 0.74, 0.04, 'OK_HYBRID', 'Profondeur financière : structure des flux'),
('P7A3_MON_INT_PRESSURE_FLOW', 'MON_INT', 'PRESSURE', 'FLOW', NULL, 0.78, 0.22, 0.76, 0.04, 'OK_HYBRID', 'Taux réel : pression monétaire'),
('P7A3_NUM_DAT2_GOVERNANCE_NETWORK', 'NUM_DAT2', 'GOVERNANCE', 'NETWORK', NULL, 0.80, 0.20, 0.82, 0.05, 'OK_HYBRID', 'Souveraineté données : gouvernance numérique'),
('P7A3_NUM_DIG_STRUCTURAL_NETWORK', 'NUM_DIG', 'STRUCTURAL', 'NETWORK', NULL, 0.78, 0.22, 0.78, 0.05, 'OK_HYBRID', 'Économie numérique : structure et réseau'),
('P7A3_NUM_FIB_STRUCTURAL_NETWORK', 'NUM_FIB', 'STRUCTURAL', 'NETWORK', NULL, 0.82, 0.18, 0.78, 0.04, 'OK_HYBRID', 'Fibre : infrastructure réseau'),
('P7A3_NUM_FIN_FLOW_NETWORK', 'NUM_FIN', 'FLOW', 'NETWORK', NULL, 0.76, 0.24, 0.72, 0.04, 'OK_HYBRID', 'Fintech : flux sur réseau numérique'),
('P7A3_NUM_INT_FLOW_NETWORK', 'NUM_INT', 'FLOW', 'NETWORK', NULL, 0.76, 0.24, 0.72, 0.04, 'OK_HYBRID', 'Internet : flux d’usage réseau'),
('P7A3_NUM_MOB_NETWORK_FLOW', 'NUM_MOB', 'NETWORK', 'FLOW', NULL, 0.78, 0.22, 0.74, 0.04, 'OK_HYBRID', 'Mobile : réseau et flux d’accès'),
('P7A3_NUM_REG_GOVERNANCE_NETWORK', 'NUM_REG', 'GOVERNANCE', 'NETWORK', NULL, 0.82, 0.18, 0.76, 0.04, 'OK_HYBRID', 'Régulation numérique : gouvernance réseau'),
('P7A3_NUM_SAT_STRUCTURAL_NETWORK', 'NUM_SAT', 'STRUCTURAL', 'NETWORK', NULL, 0.82, 0.18, 0.78, 0.04, 'OK_HYBRID', 'Satellites : infrastructure réseau souveraine'),
('P7A3_NUM_STU_RESILIENCE_STRUCTURAL', 'NUM_STU', 'RESILIENCE', 'STRUCTURAL', NULL, 0.76, 0.24, 0.74, 0.04, 'OK_HYBRID', 'Formation numérique : résilience humaine et structurelle'),
('P7A3_PRES_EN_PROD_TOT_PHYSICAL_STRUCTURAL', 'PRES_EN_PROD_TOT', 'PHYSICAL', 'STRUCTURAL', NULL, 0.86, 0.14, 0.86, 0.05, 'OK_HYBRID', 'Production totale énergie : capacité physique structurante'),
('P7A3_PRES_EN_RENEW_SHARE_RESILIENCE_PHYSICAL', 'PRES_EN_RENEW_SHARE', 'RESILIENCE', 'PHYSICAL', NULL, 0.78, 0.22, 0.82, 0.05, 'OK_HYBRID', 'Part renouvelable : résilience énergétique'),
('P7A3_PRES_WATER_FRESH_STOCK_PHYSICAL', 'PRES_WATER_FRESH', 'STOCK', 'PHYSICAL', NULL, 0.84, 0.16, 0.84, 0.05, 'OK_HYBRID', 'Eau douce renouvelable : stock physique'),
('P7A3_PRES_WATER_WITHDRAWAL_PRESSURE_PHYSICAL', 'PRES_WATER_WITHDRAWAL', 'PRESSURE', 'PHYSICAL', NULL, 0.84, 0.16, 0.84, 0.05, 'OK_HYBRID', 'Prélèvement eau : pression sur ressource'),
('P7A3_PTRA_AIR_AIRPORTS_NETWORK_STRUCTURAL', 'PTRA_AIR_AIRPORTS', 'NETWORK', 'STRUCTURAL', NULL, 0.82, 0.18, 0.76, 0.04, 'OK_HYBRID', 'Aéroports : réseau d’infrastructure'),
('P7A3_PTRA_AIR_CARGO_FLOW_NETWORK', 'PTRA_AIR_CARGO', 'FLOW', 'NETWORK', NULL, 0.82, 0.18, 0.74, 0.04, 'OK_HYBRID', 'Fret aérien : flux logistique'),
('P7A3_PTRA_AIR_PASSENGERS_FLOW_NETWORK', 'PTRA_AIR_PASSENGERS', 'FLOW', 'NETWORK', NULL, 0.82, 0.18, 0.74, 0.04, 'OK_HYBRID', 'Passagers aériens : flux de mobilité'),
('P7A3_PTRA_MULTI_NETWORK_FLOW', 'PTRA_MULTI', 'NETWORK', 'FLOW', 'STRUCTURAL', 0.74, 0.26, 0.80, 0.05, 'OK_MULTI_SEMANTIC', 'Multimodalité : réseau, flux et structure'),
('P7A3_PTRA_RD_TOTAL_STRUCTURAL_NETWORK', 'PTRA_RD_TOTAL', 'STRUCTURAL', 'NETWORK', NULL, 0.82, 0.18, 0.78, 0.04, 'OK_HYBRID', 'Réseau routier total : infrastructure réseau')
ON CONFLICT (rule_code) DO UPDATE SET
    indicator_code = EXCLUDED.indicator_code,
    primary_semantic_code = EXCLUDED.primary_semantic_code,
    secondary_semantic_code = EXCLUDED.secondary_semantic_code,
    tertiary_semantic_code = EXCLUDED.tertiary_semantic_code,
    dominance_weight = EXCLUDED.dominance_weight,
    hybrid_weight = EXCLUDED.hybrid_weight,
    strategic_criticality = EXCLUDED.strategic_criticality,
    forecastability_boost = EXCLUDED.forecastability_boost,
    status_override = EXCLUDED.status_override,
    rationale = EXCLUDED.rationale,
    is_active = TRUE;

DO $$
DECLARE n INT;
BEGIN
    SELECT COUNT(*) INTO n FROM ma.semantic_hybrid_rules WHERE is_active;
    RAISE NOTICE 'P7A3 semantic hybrid rules actives : %', n;
END $$;

COMMIT;
