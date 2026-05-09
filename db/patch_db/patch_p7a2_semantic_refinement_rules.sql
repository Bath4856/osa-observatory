-- ============================================================
-- OSA / ISA — P7A2
-- Patch : Semantic Refinement Rules
-- Objectif : transformer les classifications heuristiques faibles
--            en règles métier ISA explicites et gouvernées.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS ma.signal_semantic_refinement_rules (
    rule_id BIGSERIAL PRIMARY KEY,
    rule_code VARCHAR(80) UNIQUE NOT NULL,
    indicator_code VARCHAR(30),
    pillar_code VARCHAR(10),
    code_pattern VARCHAR(80),
    name_pattern VARCHAR(160),
    semantic_code VARCHAR(30) NOT NULL,
    semantic_confidence NUMERIC(4,3) NOT NULL DEFAULT 0.900,
    refinement_reason TEXT NOT NULL,
    rule_priority SMALLINT NOT NULL DEFAULT 100,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sem_ref_indicator
    ON ma.signal_semantic_refinement_rules(indicator_code);

CREATE INDEX IF NOT EXISTS idx_sem_ref_pillar
    ON ma.signal_semantic_refinement_rules(pillar_code);

CREATE INDEX IF NOT EXISTS idx_sem_ref_active
    ON ma.signal_semantic_refinement_rules(is_active);

-- Règles explicites : PECO
INSERT INTO ma.signal_semantic_refinement_rules
(rule_code, indicator_code, pillar_code, code_pattern, name_pattern, semantic_code, semantic_confidence, refinement_reason, rule_priority)
VALUES
('P7A2_ECO_GDP_STRUCTURAL', 'ECO_GDP', 'PECO', NULL, NULL, 'STRUCTURAL', 0.930, 'PIB par habitant = capacité économique structurelle, non simple flux.', 10),
('P7A2_ECO_GRW_FLOW', 'ECO_GRW', 'PECO', NULL, NULL, 'FLOW', 0.920, 'Croissance = dynamique de flux économique.', 10),
('P7A2_ECO_INF_PRESSURE', 'ECO_INF', 'PECO', NULL, NULL, 'PRESSURE', 0.930, 'Inflation = pression macroéconomique.', 10),
('P7A2_ECO_UNE_PRESSURE', 'ECO_UNE', 'PECO', NULL, NULL, 'PRESSURE', 0.920, 'Chômage = pression socioéconomique.', 10),
('P7A2_ECO_FDI_FLOW', 'ECO_FDI', 'PECO', NULL, NULL, 'FLOW', 0.930, 'IDE nets = flux de capital.', 10),
('P7A2_ECO_INV_FLOW', 'ECO_INV', 'PECO', NULL, NULL, 'FLOW', 0.920, 'Investissement = flux économique.', 10),
('P7A2_ECO_TAX_GOVERNANCE', 'ECO_TAX', 'PECO', NULL, NULL, 'GOVERNANCE', 0.930, 'Fiscalité = capacité de gouvernance économique.', 10),
('P7A2_ECO_SME_STRUCTURAL', 'ECO_SME', 'PECO', NULL, NULL, 'STRUCTURAL', 0.900, 'Tissu PME = capacité structurelle économique.', 10),
('P7A2_ECO_PRO_STRUCTURAL', 'ECO_PRO', 'PECO', NULL, NULL, 'STRUCTURAL', 0.900, 'Productivité = capacité structurelle.', 10),
('P7A2_ECO_EXB_FLOW', 'ECO_EXB', 'PECO', NULL, NULL, 'FLOW', 0.920, 'Export bois industriel = flux économique sectoriel.', 10),
('P7A2_ECO_INB_STRUCTURAL', 'ECO_INB', 'PECO', NULL, NULL, 'STRUCTURAL', 0.900, 'Transformation industrielle bois = capacité productive.', 10),
('P7A2_ECO_VAF_STRUCTURAL', 'ECO_VAF', 'PECO', NULL, NULL, 'STRUCTURAL', 0.900, 'Valeur ajoutée forestière = capacité productive.', 10),
('P7A2_ECO_EMP_STRUCTURAL', 'ECO_EMP', 'PECO', NULL, NULL, 'STRUCTURAL', 0.900, 'Emploi formel = profondeur structurelle du marché.', 10),
('P7A2_ECO_IND_STRUCTURAL', 'ECO_IND', 'PECO', NULL, NULL, 'STRUCTURAL', 0.900, 'Industrialisation = capacité structurelle.', 10)
ON CONFLICT (rule_code) DO UPDATE SET
    semantic_code = EXCLUDED.semantic_code,
    semantic_confidence = EXCLUDED.semantic_confidence,
    refinement_reason = EXCLUDED.refinement_reason,
    rule_priority = EXCLUDED.rule_priority,
    is_active = TRUE;

-- Règles explicites : PMON
INSERT INTO ma.signal_semantic_refinement_rules
(rule_code, indicator_code, pillar_code, code_pattern, name_pattern, semantic_code, semantic_confidence, refinement_reason, rule_priority)
VALUES
('P7A2_MON_INF_PRESSURE', 'MON_INF', 'PMON', NULL, NULL, 'PRESSURE', 0.940, 'Inflation monétaire = pression macro-monétaire.', 10),
('P7A2_MON_EXR_PRESSURE', 'MON_EXR', 'PMON', NULL, NULL, 'PRESSURE', 0.930, 'Taux de change = pression de stabilité monétaire.', 10),
('P7A2_MON_M2_FLOW', 'MON_M2', 'PMON', NULL, NULL, 'FLOW', 0.920, 'Masse monétaire = flux/liquidité.', 10),
('P7A2_MON_EXT_DEPENDENCY', 'MON_EXT', 'PMON', NULL, NULL, 'DEPENDENCY', 0.930, 'Dette extérieure = dépendance financière.', 10),
('P7A2_MON_AUT_GOVERNANCE', 'MON_AUT', 'PMON', NULL, NULL, 'GOVERNANCE', 0.950, 'Autonomie monétaire = gouvernance souveraine.', 10),
('P7A2_MON_CTRL_GOVERNANCE', 'MON_CTRL', 'PMON', NULL, NULL, 'GOVERNANCE', 0.950, 'Contrôle monétaire = gouvernance souveraine.', 10),
('P7A2_MON_IND_GOVERNANCE', 'MON_IND', 'PMON', NULL, NULL, 'GOVERNANCE', 0.950, 'Indépendance monétaire = gouvernance.', 10),
('P7A2_MON_CRY_GOVERNANCE', 'MON_CRY', 'PMON', NULL, NULL, 'GOVERNANCE', 0.900, 'Crypto/monnaie numérique = gouvernance monétaire émergente.', 10),
('P7A2_MON_DIG_GOVERNANCE', 'MON_DIG', 'PMON', NULL, NULL, 'GOVERNANCE', 0.900, 'Paiement/monnaie digitale = gouvernance monétaire.', 10),
('P7A2_MON_PAY_FLOW', 'MON_PAY', 'PMON', NULL, NULL, 'FLOW', 0.900, 'Paiements = flux monétaire.', 10),
('P7A2_MON_STB_RESILIENCE', 'MON_STB', 'PMON', NULL, NULL, 'RESILIENCE', 0.920, 'Stabilité monétaire = résilience.', 10)
ON CONFLICT (rule_code) DO UPDATE SET
    semantic_code = EXCLUDED.semantic_code,
    semantic_confidence = EXCLUDED.semantic_confidence,
    refinement_reason = EXCLUDED.refinement_reason,
    rule_priority = EXCLUDED.rule_priority,
    is_active = TRUE;

-- Règles explicites : PMIL
INSERT INTO ma.signal_semantic_refinement_rules
(rule_code, indicator_code, pillar_code, code_pattern, name_pattern, semantic_code, semantic_confidence, refinement_reason, rule_priority)
VALUES
('P7A2_PMIL_DEF_BUDGET_GDP_STRUCTURAL', 'PMIL_DEF_BUDGET_GDP', 'PMIL', NULL, NULL, 'STRUCTURAL', 0.930, 'Budget défense/PIB = capacité militaire structurelle.', 10),
('P7A2_PMIL_DEF_BUDGET_GOV_STRUCTURAL', 'PMIL_DEF_BUDGET_GOV', 'PMIL', NULL, NULL, 'STRUCTURAL', 0.930, 'Budget défense/gouvernement = capacité budgétaire structurelle.', 10),
('P7A2_PMIL_ARMED_FORCES_STRUCTURAL', 'PMIL_ARMED_FORCES', 'PMIL', NULL, NULL, 'STRUCTURAL', 0.930, 'Forces armées = capacité structurelle humaine.', 10),
('P7A2_PMIL_STABILITY_WGI_PRESSURE', 'PMIL_STABILITY_WGI', 'PMIL', NULL, NULL, 'PRESSURE', 0.930, 'Stabilité politique/sécurité = pression de sécurité.', 10),
('P7A2_PMIL_GCI_CYBER_NETWORK', 'PMIL_GCI_CYBER', 'PMIL', NULL, NULL, 'NETWORK', 0.910, 'Cyberdéfense = réseau/capacité numérique sécuritaire.', 10),
('P7A2_MIL_MIS_EVENT', 'MIL_MIS', 'PMIL', NULL, NULL, 'EVENT', 0.900, 'Missions/conflits = événement sécuritaire.', 10),
('P7A2_MIL_LOG_STRUCTURAL', 'MIL_LOG', 'PMIL', NULL, NULL, 'STRUCTURAL', 0.900, 'Logistique militaire = capacité structurelle.', 10)
ON CONFLICT (rule_code) DO UPDATE SET
    semantic_code = EXCLUDED.semantic_code,
    semantic_confidence = EXCLUDED.semantic_confidence,
    refinement_reason = EXCLUDED.refinement_reason,
    rule_priority = EXCLUDED.rule_priority,
    is_active = TRUE;

-- Règles explicites : PENV / PHUM / PGEO / PNUM
INSERT INTO ma.signal_semantic_refinement_rules
(rule_code, indicator_code, pillar_code, code_pattern, name_pattern, semantic_code, semantic_confidence, refinement_reason, rule_priority)
VALUES
('P7A2_ENV_CO2_PRESSURE', 'ENV_CO2', 'PENV', NULL, NULL, 'PRESSURE', 0.940, 'CO2 = pression environnementale.', 10),
('P7A2_ENV_DEF_PRESSURE', 'ENV_DEF', 'PENV', NULL, NULL, 'PRESSURE', 0.940, 'Déforestation = pression environnementale.', 10),
('P7A2_ENV_FOR_STOCK', 'ENV_FOR', 'PENV', NULL, NULL, 'STOCK', 0.920, 'Forêt = stock écologique.', 10),
('P7A2_ENV_WAT_STOCK', 'ENV_WAT', 'PENV', NULL, NULL, 'STOCK', 0.920, 'Eau = stock écologique critique.', 10),
('P7A2_ENV_WAS_PRESSURE', 'ENV_WAS', 'PENV', NULL, NULL, 'PRESSURE', 0.920, 'Déchets = pression environnementale.', 10),
('P7A2_HUM_MIG_FLOW', 'HUM_MIG', 'PHUM', NULL, NULL, 'FLOW', 0.930, 'Migration = flux humain.', 10),
('P7A2_HUM_POV_PRESSURE', 'HUM_POV', 'PHUM', NULL, NULL, 'PRESSURE', 0.930, 'Pauvreté = pression humaine.', 10),
('P7A2_HUM_EDU_RESILIENCE', 'HUM_EDU', 'PHUM', NULL, NULL, 'RESILIENCE', 0.930, 'Éducation = résilience humaine.', 10),
('P7A2_HUM_HEA_RESILIENCE', 'HUM_HEA', 'PHUM', NULL, NULL, 'RESILIENCE', 0.930, 'Santé = résilience humaine.', 10),
('P7A2_GEO_MIG_FLOW', 'GEO_MIG', 'PGEO', NULL, NULL, 'FLOW', 0.920, 'Migration géopolitique = flux.', 10),
('P7A2_GEO_SAN_PRESSURE', 'GEO_SAN', 'PGEO', NULL, NULL, 'PRESSURE', 0.920, 'Sanctions = pression géopolitique.', 10),
('P7A2_GEO_CON_EVENT', 'GEO_CON', 'PGEO', NULL, NULL, 'EVENT', 0.920, 'Conflit = événement géopolitique.', 10),
('P7A2_GEO_DIP_NETWORK', 'GEO_DIP', 'PGEO', NULL, NULL, 'NETWORK', 0.900, 'Diplomatie = réseau géopolitique.', 10),
('P7A2_NUM_AI_STRUCTURAL', 'NUM_AI', 'PNUM', NULL, NULL, 'STRUCTURAL', 0.900, 'IA = capacité structurelle numérique.', 10),
('P7A2_NUM_CLO_NETWORK', 'NUM_CLO', 'PNUM', NULL, NULL, 'NETWORK', 0.900, 'Cloud = réseau/infrastructure numérique.', 10),
('P7A2_NUM_DAT_STOCK', 'NUM_DAT', 'PNUM', NULL, NULL, 'STOCK', 0.900, 'Données = stock numérique souverain.', 10),
('P7A2_NUM_RES_RESILIENCE', 'NUM_RES', 'PNUM', NULL, NULL, 'RESILIENCE', 0.900, 'Résilience numérique.', 10)
ON CONFLICT (rule_code) DO UPDATE SET
    semantic_code = EXCLUDED.semantic_code,
    semantic_confidence = EXCLUDED.semantic_confidence,
    refinement_reason = EXCLUDED.refinement_reason,
    rule_priority = EXCLUDED.rule_priority,
    is_active = TRUE;

-- Règles par motifs plus fortes que les défauts de pilier
INSERT INTO ma.signal_semantic_refinement_rules
(rule_code, indicator_code, pillar_code, code_pattern, name_pattern, semantic_code, semantic_confidence, refinement_reason, rule_priority)
VALUES
('P7A2_PATTERN_INF_PRESSURE', NULL, NULL, '%_INF', NULL, 'PRESSURE', 0.880, 'Pattern *_INF = pression inflation / information critique selon contexte.', 50),
('P7A2_PATTERN_RSK_PRESSURE', NULL, NULL, '%_RSK', NULL, 'PRESSURE', 0.880, 'Pattern *_RSK = risque/pression.', 50),
('P7A2_PATTERN_DEP_DEPENDENCY', NULL, NULL, '%_DEP', NULL, 'DEPENDENCY', 0.880, 'Pattern *_DEP = dépendance.', 50),
('P7A2_PATTERN_EXP_FLOW', NULL, NULL, '%_EXP', NULL, 'FLOW', 0.880, 'Pattern *_EXP = flux export.', 50),
('P7A2_PATTERN_IMP_FLOW', NULL, NULL, '%_IMP', NULL, 'FLOW', 0.880, 'Pattern *_IMP = flux import.', 50),
('P7A2_PATTERN_RES_STOCK', NULL, NULL, '%_RES', NULL, 'STOCK', 0.880, 'Pattern *_RES = stock/réserve.', 50),
('P7A2_PATTERN_CAP_STRUCTURAL', NULL, NULL, '%_CAP%', NULL, 'STRUCTURAL', 0.880, 'Pattern *_CAP* = capacité structurelle.', 50),
('P7A2_PATTERN_NET_NETWORK', NULL, NULL, '%_NET%', NULL, 'NETWORK', 0.880, 'Pattern *_NET* = réseau.', 50),
('P7A2_PATTERN_GOV_GOVERNANCE', NULL, NULL, '%_GOV%', NULL, 'GOVERNANCE', 0.880, 'Pattern *_GOV* = gouvernance.', 50)
ON CONFLICT (rule_code) DO UPDATE SET
    semantic_code = EXCLUDED.semantic_code,
    semantic_confidence = EXCLUDED.semantic_confidence,
    refinement_reason = EXCLUDED.refinement_reason,
    rule_priority = EXCLUDED.rule_priority,
    is_active = TRUE;

DO $$
DECLARE
    n_rules INT;
BEGIN
    SELECT COUNT(*) INTO n_rules
    FROM ma.signal_semantic_refinement_rules
    WHERE is_active = TRUE;

    RAISE NOTICE 'P7A2 semantic refinement rules actives : %', n_rules;
END $$;

COMMIT;
