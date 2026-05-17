-- ============================================================
-- OSA / ISA — P7I-AMAR-GENECO Registry Extension
-- Purpose: Conflict economy exposure, as a sub-module of AMAR.
-- Scope: No new ISA pillar. No legal attribution. Risk intelligence only.
-- ============================================================

BEGIN;

-- Package registry, compatible with existing mg.package_registry shape.
INSERT INTO mg.package_registry (
    package_code,
    package_name,
    status,
    parent_package_code,
    description,
    created_at,
    updated_at
)
VALUES (
    'P7I-AMAR-GENECO',
    'P7I-AMAR-GENECO — Conflict Economy Exposure Engine',
    'ACTIVE',
    'P7I-AMAR',
    'Extension of P7I-AMAR measuring conflict-economy exposure using existing OSA/ISA pillars. It does not create a new pillar and does not attribute legal responsibility.',
    NOW(),
    NOW()
)
ON CONFLICT (package_code)
DO UPDATE SET
    package_name = EXCLUDED.package_name,
    status = EXCLUDED.status,
    parent_package_code = EXCLUDED.parent_package_code,
    description = EXCLUDED.description,
    updated_at = NOW();

-- Risk taxonomy extension if the table exists from AMAR v2.
DO $$
BEGIN
    IF to_regclass('mg.risk_taxonomy') IS NOT NULL THEN
        INSERT INTO mg.risk_taxonomy (
            risk_code,
            risk_name,
            description,
            severity_order,
            public_visible
        )
        VALUES (
            'CONFLICT_ECONOMY_EXPOSURE',
            'Conflict Economy Exposure Risk',
            'Risk that extractive, logistics, institutional, humanitarian or information conditions enable a conflict economy. This is not legal attribution.',
            7,
            TRUE
        )
        ON CONFLICT (risk_code)
        DO UPDATE SET
            risk_name = EXCLUDED.risk_name,
            description = EXCLUDED.description,
            severity_order = EXCLUDED.severity_order,
            public_visible = EXCLUDED.public_visible,
            updated_at = NOW();
    END IF;
END $$;

COMMIT;
