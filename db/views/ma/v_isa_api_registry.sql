-- ============================================================
-- OSA / ISA — P8F View: ma.v_isa_api_registry
-- ============================================================

CREATE OR REPLACE VIEW ma.v_isa_api_registry AS
SELECT
    endpoint_code,
    api_version,
    http_method,
    api_path,
    backing_view,
    access_class,
    auth_required,
    rate_limit_policy,
    monetization_class,
    certification_dependency,
    is_enabled,
    endpoint_note,
    CASE
        WHEN is_enabled IS FALSE THEN 'API_DISABLED'
        WHEN access_class = 'PUBLIC' AND auth_required IS FALSE THEN 'API_PUBLIC_READY'
        WHEN access_class = 'PRIVATE' AND auth_required IS TRUE THEN 'API_PRIVATE_READY'
        ELSE 'API_GOVERNANCE_REVIEW'
    END AS api_governance_status
FROM rf.isa_api_endpoint_registry;
