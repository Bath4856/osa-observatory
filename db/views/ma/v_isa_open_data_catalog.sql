-- ============================================================
-- OSA / ISA — P8D View: ma.v_isa_open_data_catalog
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_open_data_catalog AS
SELECT
    d.dataset_code,
    d.dataset_name,
    d.source_view,
    d.access_class,
    d.delivery_formats,
    d.is_public,
    d.requires_certification,
    d.api_path,
    d.dataset_note,
    CASE
        WHEN d.source_view = 'ma.v_isa_observed_scores_by_country_year'
            THEN (SELECT COUNT(*) FROM ma.v_isa_observed_scores_by_country_year)
        WHEN d.source_view = 'ma.v_isa_observed_scores_by_pillar'
            THEN (SELECT COUNT(*) FROM ma.v_isa_observed_scores_by_pillar)
        WHEN d.source_view = 'ma.v_isa_observed_scores_by_region_year'
            THEN (SELECT COUNT(*) FROM ma.v_isa_observed_scores_by_region_year)
        WHEN d.source_view = 'ma.v_isa_swot_signal_engine'
            THEN (SELECT COUNT(*) FROM ma.v_isa_swot_signal_engine)
        WHEN d.source_view = 'ma.v_isa_project_opportunity_catalog'
            THEN (SELECT COUNT(*) FROM ma.v_isa_project_opportunity_catalog)
        ELSE 0
    END AS dataset_rows,
    CASE
        WHEN d.is_public THEN 'OPEN_DATA_READY'
        ELSE 'OPEN_DATA_DISABLED'
    END AS open_data_delivery_status
FROM rf.isa_open_data_dataset_policy d;
