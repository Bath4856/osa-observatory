BEGIN;

--------------------------------------------------
-- 1. PACKAGE GOVERNANCE REGISTRY
--------------------------------------------------

CREATE TABLE IF NOT EXISTS mg.package_governance_registry (
    package_code                   TEXT PRIMARY KEY,
    package_label                  TEXT,
    package_version                TEXT,
    package_layer                  TEXT,
    package_status                 TEXT,
    governance_scope               TEXT,
    predictive_scope               TEXT,
    publication_scope              TEXT,
    freeze_ready                   BOOLEAN,
    audit_required                 BOOLEAN,
    production_ready               BOOLEAN,
    created_at                     TIMESTAMP DEFAULT NOW(),
    updated_at                     TIMESTAMP DEFAULT NOW()
);

--------------------------------------------------
-- 2. PACKAGE DEPENDENCIES
--------------------------------------------------

CREATE TABLE IF NOT EXISTS mg.package_dependency_registry (
    package_code                   TEXT,
    dependency_package             TEXT,
    dependency_type                TEXT,
    created_at                     TIMESTAMP DEFAULT NOW()
);

--------------------------------------------------
-- 3. CLEAN OLD P7K
--------------------------------------------------

DELETE FROM mg.package_governance_registry
WHERE package_code = 'P7K';

DELETE FROM mg.package_dependency_registry
WHERE package_code = 'P7K';

--------------------------------------------------
-- 4. INSERT P7K GOVERNANCE
--------------------------------------------------

INSERT INTO mg.package_governance_registry (
    package_code,
    package_label,
    package_version,
    package_layer,
    package_status,
    governance_scope,
    predictive_scope,
    publication_scope,
    freeze_ready,
    audit_required,
    production_ready,
    created_at,
    updated_at
)
VALUES (
    'P7K',
    'Executive Governance Layer',
    'P7K_V1_FINAL',
    'EXECUTIVE_GOVERNANCE',
    'PRODUCTION_READY',

    'Transforms sovereign intervention signals into executive governance portfolios and board-ready structures.',

    'Prepares predictive readiness metadata only. Does not execute forecasting or simulations.',

    'Provides executive-ready publication structures for P8.',

    TRUE,
    TRUE,
    TRUE,

    NOW(),
    NOW()
);

--------------------------------------------------
-- 5. INSERT DEPENDENCIES
--------------------------------------------------

INSERT INTO mg.package_dependency_registry VALUES
('P7K','P7F','REQUIRED',NOW()),
('P7K','P7G','REQUIRED',NOW()),
('P7K','P7H','REQUIRED',NOW()),
('P7K','P7J','REQUIRED',NOW()),
('P7K','P7Z','TRANSITION_TARGET',NOW()),
('P7K','P8','PUBLICATION_TARGET',NOW());

--------------------------------------------------
-- 6. GOVERNANCE VALIDATION
--------------------------------------------------

DO $$
DECLARE
    v_master_rows INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO v_master_rows
    FROM ma.v_isa_executive_master_board;

    IF v_master_rows = 0 THEN
        RAISE EXCEPTION
        'P7K governance validation failed: master board empty';
    END IF;

    RAISE NOTICE
    'P7K governance finalized. master_rows=%',
    v_master_rows;

END $$;

COMMIT;