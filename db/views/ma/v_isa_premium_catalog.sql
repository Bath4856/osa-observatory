-- ============================================================
-- OSA / ISA — P8E View: ma.v_isa_premium_catalog
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_premium_catalog AS
SELECT
    p.product_code,
    p.product_name,
    p.source_view,
    p.monetization_class,
    p.requires_contract,
    p.delivery_mode,
    p.api_path,
    p.product_note,
    CASE
        WHEN p.source_view = 'ma.v_isa_premium_feasibility_triggers'
            THEN (SELECT COUNT(*) FROM ma.v_isa_premium_feasibility_triggers)
        WHEN p.source_view = 'ma.v_isa_strategic_recommendation_engine'
            THEN (SELECT COUNT(*) FROM ma.v_isa_strategic_recommendation_engine)
        WHEN p.source_view = 'ma.v_isa_project_opportunity_catalog'
            THEN (SELECT COUNT(*) FROM ma.v_isa_project_opportunity_catalog)
        ELSE 0
    END AS product_source_rows,
    CASE
        WHEN p.requires_contract THEN 'PREMIUM_CONTRACT_REQUIRED'
        ELSE 'PREMIUM_SELF_SERVICE'
    END AS premium_delivery_status
FROM rf.isa_premium_product_policy p;
