-- ============================================================
-- OSA ISA – Sprint 24 GAF v3
-- Seed : règles d'orientation + calibration comité initiale
--
-- Nouveautés v3 :
-- [B bis] publication_impact + iprs_weight dans gaf_orientation_rules
-- [D]     Seed ops.gaf_iprs_calibration avec valeurs par défaut
--         is_validated = FALSE = en attente validation comité
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Table de référence des règles
-- ============================================================

CREATE TABLE IF NOT EXISTS ops.gaf_orientation_rules (
    rule_code           TEXT            PRIMARY KEY,
    finding_code        TEXT            NOT NULL,
    severity            TEXT            NOT NULL
                        CHECK (severity IN ('CRITICAL','HIGH','MEDIUM','LOW','INFO')),
    object_type         TEXT,
    recommended_action  TEXT            NOT NULL,
    priority            TEXT            NOT NULL
                        CHECK (priority IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    owner               TEXT            NOT NULL,
    sprint_target       TEXT,
    publication_impact  TEXT            NOT NULL DEFAULT 'NONE'
                        CHECK (publication_impact IN ('BLOCKING','CONDITIONAL','NONE')),
    iprs_weight         NUMERIC(4,2)    NOT NULL DEFAULT 0.00,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    description         TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 2. Seed des 12 règles avec publication_impact et iprs_weight
-- ============================================================

INSERT INTO ops.gaf_orientation_rules
    (rule_code, finding_code, severity, object_type,
     recommended_action, priority, owner, sprint_target,
     publication_impact, iprs_weight, description)
VALUES

('R01_METHOD_VERSION_NULL','METHOD_VERSION_ID_NULL','CRITICAL','TABLE',
 'Ajouter DEFAULT 1 sur method_version_id. Dédupliquer ma.indicator_values.',
 'CRITICAL','DATA_STEWARD','Sprint 24',
 'BLOCKING', 5.00,
 'method_version_id IS NULL — contrainte UNIQUE inopérante'),

('R02_DUPLICATE_VALUES','DUPLICATE_INDICATOR_VALUES','CRITICAL','TABLE',
 'Dédupliquer ma.indicator_values. Corriger la contrainte UNIQUE.',
 'CRITICAL','DATA_STEWARD','Sprint 24',
 'BLOCKING', 5.00,
 'Doublons dans ma.indicator_values — scores potentiellement faux'),

('R03_WEIGHT_CONSISTENCY','WEIGHT_SUM_INCONSISTENT','HIGH','TABLE',
 'Revoir les poids dans ma.indicator_meta_links. Somme = 1.0 par (meta_code, ref_year).',
 'HIGH','METHODOLOGY_COMMITTEE','Sprint 24',
 'CONDITIONAL', 3.00,
 'Somme poids ≠ 1.0 pour SOV_PECO / SOV_PMON'),

('R04_INDICATOR_NOT_LINKED','INDICATOR_UNLINKED','HIGH','INDICATOR',
 'Lier l indicateur dans ma.indicator_meta_links ou ma.indicator_exclusions.',
 'HIGH','METHODOLOGY_COMMITTEE','Sprint 24',
 'CONDITIONAL', 2.00,
 'Indicateur absent de ma.indicator_meta_links sans exclusion'),

('R05_ENDPOINT_MISSING','API_ENDPOINT_MISSING','HIGH','ENDPOINT',
 'Vérifier implémentation FastAPI et enregistrement router dans main.py.',
 'HIGH','OPS_ADMINISTRATOR','Sprint 24',
 'CONDITIONAL', 2.00,
 'Endpoint API retourne 404'),

('R06_ENDPOINT_TIMEOUT','API_ENDPOINT_TIMEOUT','MEDIUM','ENDPOINT',
 'Créer une vue matérialisée pub.mv_* si vue standard trop lente.',
 'MEDIUM','OPS_ADMINISTRATOR','Sprint 25',
 'NONE', 1.00,
 'Endpoint API en timeout lors de l audit'),

('R07_ENDPOINT_SLOW','API_ENDPOINT_SLOW','MEDIUM','ENDPOINT',
 'EXPLAIN ANALYZE + vue matérialisée ou index supplémentaire.',
 'MEDIUM','OPS_ADMINISTRATOR','Sprint 25',
 'NONE', 0.50,
 'Latence endpoint > seuil WARNING'),

('R08_NULL_VALUES','DATA_NULL_VALUES','MEDIUM','TABLE',
 'Identifier indicateurs et années avec valeurs nulles. Vérifier collecteurs.',
 'MEDIUM','DATA_STEWARD','Sprint 25',
 'NONE', 1.00,
 'Valeurs nulles dans ma.indicator_values'),

('R09_TRAJECTORY_INACTIVE','TRAJECTORY_INDICATOR_INACTIVE','MEDIUM','INDICATOR',
 'Vérifier données source pour l année de référence. Doctrine P7E si imputation > 50%.',
 'MEDIUM','METHODOLOGY_COMMITTEE','Sprint 25',
 'NONE', 0.50,
 'Indicateur TRAJECTOIRE sans données pour l année de référence'),

('R10_SECURITY_SENSITIVE','SECURITY_SENSITIVE_PATTERN','LOW','CONFIG',
 'Vérifier absence credentials en clair. Utiliser variables d environnement.',
 'LOW','OPS_ADMINISTRATOR','Sprint 25',
 'NONE', 0.25,
 'Patterns sensibles détectés dans les fichiers du repo'),

('R11_MISSING_COUNTRY','COVERAGE_MISSING_COUNTRY','LOW','TABLE',
 'Vérifier liste pays africains dans rf.countries et _AFRICA_ISO3.',
 'LOW','DATA_STEWARD','Sprint 26',
 'NONE', 0.25,
 'Pays absent de la couverture Early Warning'),

('R12_NO_AUTH_TOKEN','AUTH_TOKEN_NOT_CONFIGURED','INFO','CONFIG',
 'Configurer api_key et auth_token dans audit_config.yaml.',
 'LOW','OPS_ADMINISTRATOR','Sprint 25',
 'NONE', 0.00,
 'Tokens authentification absents de la configuration')

ON CONFLICT (rule_code) DO NOTHING;

-- ============================================================
-- 3. [D] Calibration comité initiale
--    is_validated = FALSE = valeurs par défaut en attente comité
--    Le Comité Scientifique valide via :
--    UPDATE ops.gaf_iprs_calibration
--    SET iprs_weight = X, publication_impact = 'Y',
--        rationale = 'Justification', validated_by = 'Comité',
--        validated_at = NOW(), is_validated = TRUE
--    WHERE finding_code = 'CODE';
-- ============================================================

INSERT INTO ops.gaf_iprs_calibration
    (finding_code, iprs_weight, publication_impact, rationale,
     validated_by, is_validated)
VALUES

('METHOD_VERSION_ID_NULL',     5.00, 'BLOCKING',
 'Invalide la fiabilité de tous les scores. Bloquant publication.',
 'DEFAULT', FALSE),

('DUPLICATE_INDICATOR_VALUES', 5.00, 'BLOCKING',
 'Scores potentiellement faux par double comptage.',
 'DEFAULT', FALSE),

('WEIGHT_SUM_INCONSISTENT',    3.00, 'CONDITIONAL',
 'Scores PECO/PMON sous-estimés de ~6%. Publication conditionnelle.',
 'DEFAULT', FALSE),

('INDICATOR_UNLINKED',         2.00, 'CONDITIONAL',
 'Indicateur non pris en compte dans le calcul ISA.',
 'DEFAULT', FALSE),

('API_ENDPOINT_MISSING',       2.00, 'CONDITIONAL',
 'Fonctionnalité API absente. Impact sur les utilisateurs.',
 'DEFAULT', FALSE),

('API_ENDPOINT_TIMEOUT',       1.00, 'NONE',
 'Performance dégradée. Non bloquant pour publication.',
 'DEFAULT', FALSE),

('API_ENDPOINT_SLOW',          0.50, 'NONE',
 'Latence élevée. Impact UX mais non bloquant.',
 'DEFAULT', FALSE),

('DATA_NULL_VALUES',           1.00, 'NONE',
 'Valeurs manquantes dans les données brutes. A investiguer.',
 'DEFAULT', FALSE),

('TRAJECTORY_INDICATOR_INACTIVE', 0.50, 'NONE',
 'Indicateur TRAJECTOIRE sans données pour l année. Doctrine P7E.',
 'DEFAULT', FALSE),

('SECURITY_SENSITIVE_PATTERN', 0.25, 'NONE',
 'Risque sécurité potentiel. A vérifier manuellement.',
 'DEFAULT', FALSE),

('COVERAGE_MISSING_COUNTRY',   0.25, 'NONE',
 'Pays absent de la couverture. Impact mineur sur représentativité.',
 'DEFAULT', FALSE),

('AUTH_TOKEN_NOT_CONFIGURED',  0.00, 'NONE',
 'Configuration manquante. Non bloquant — passe B optionnelle.',
 'DEFAULT', FALSE),

('UNCLASSIFIED',               0.00, 'NONE',
 'Finding non classifié. Analyse manuelle requise.',
 'DEFAULT', FALSE)

ON CONFLICT (finding_code) DO NOTHING;

COMMIT;

-- Vérification
SELECT rule_code, finding_code, severity, publication_impact,
       iprs_weight, is_active
FROM ops.gaf_orientation_rules
ORDER BY CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
                        WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END;

SELECT finding_code, iprs_weight, publication_impact, is_validated
FROM ops.gaf_iprs_calibration
ORDER BY iprs_weight DESC;
