-- ============================================================
-- OSA / ISA — P8E Premium Delivery
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS rf;

DROP TABLE IF EXISTS rf.isa_premium_product_policy CASCADE;

CREATE TABLE rf.isa_premium_product_policy (
    product_code VARCHAR(50) PRIMARY KEY,
    product_name TEXT NOT NULL,
    source_view TEXT NOT NULL,
    monetization_class VARCHAR(30) NOT NULL DEFAULT 'PREMIUM',
    requires_contract BOOLEAN NOT NULL DEFAULT TRUE,
    delivery_mode VARCHAR(30) NOT NULL DEFAULT 'REPORT_AND_DATA',
    api_path TEXT,
    product_note TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO rf.isa_premium_product_policy (
    product_code, product_name, source_view, monetization_class,
    requires_contract, delivery_mode, api_path, product_note
)
VALUES
('FEASIBILITY_STUDIES', 'Études de faisabilité premium', 'ma.v_isa_premium_feasibility_triggers', 'PREMIUM', TRUE, 'REPORT_AND_DATA', '/api/v1/premium/feasibility', 'Déclencheurs d’études de faisabilité par pays/pilier/projet.'),
('PROTOTYPE_POC', 'Prototypes et preuves de concept', 'ma.v_isa_premium_feasibility_triggers', 'PREMIUM', TRUE, 'POC', '/api/v1/premium/prototypes', 'Priorisation des POC/prototypes.'),
('COUNTRY_INTELLIGENCE_PACK', 'Country intelligence pack', 'ma.v_isa_strategic_recommendation_engine', 'PREMIUM', TRUE, 'REPORT_AND_DATA', '/api/v1/premium/country-pack/{iso3}', 'Diagnostic stratégique pays.'),
('INVESTOR_PACK', 'Investor package', 'ma.v_isa_project_opportunity_catalog', 'PREMIUM', TRUE, 'REPORT_AND_DATA', '/api/v1/premium/investor-pack', 'Dossier investisseur à partir du catalogue de projets.')
ON CONFLICT (product_code) DO UPDATE SET
    product_name = EXCLUDED.product_name,
    source_view = EXCLUDED.source_view,
    monetization_class = EXCLUDED.monetization_class,
    requires_contract = EXCLUDED.requires_contract,
    delivery_mode = EXCLUDED.delivery_mode,
    api_path = EXCLUDED.api_path,
    product_note = EXCLUDED.product_note,
    updated_at = NOW();

DO $$
BEGIN
    RAISE NOTICE 'P8E premium product policy lignes : %',
        (SELECT COUNT(*) FROM rf.isa_premium_product_policy);
END $$;

COMMIT;
