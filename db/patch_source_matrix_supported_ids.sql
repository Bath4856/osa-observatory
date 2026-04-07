-- ============================================================
-- OSA / ISA OBSERVATORY
-- patch_source_matrix_supported_ids.sql
-- ============================================================
-- Correction #2 : run_ingestion_from_matrix() accepte désormais
-- la liste des source_id supportés en paramètre Python,
-- au lieu d'une liste hardcodée dans le corps de la fonction.
--
-- Rétrocompatible : l'ancienne signature (4 params) est conservée
-- en parallèle. Python appelle la nouvelle (5 params) et gère
-- le fallback vers l'ancienne si nécessaire.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION collect.run_ingestion_from_matrix(
    p_year_from      INT            DEFAULT NULL,
    p_year_to        INT            DEFAULT NULL,
    p_include_pilot  BOOLEAN        DEFAULT FALSE,
    p_requested_by   VARCHAR        DEFAULT 'SYSTEM',
    p_supported_ids  VARCHAR[]      DEFAULT NULL   -- #2 nouveau paramètre
)
RETURNS TABLE (
    run_id    BIGINT,
    source_id VARCHAR,
    status    VARCHAR,
    priority  INT,
    supported BOOLEAN,
    decision  VARCHAR,
    reason    TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_run_id      BIGINT;
    v_supported   VARCHAR[];
BEGIN
    -- Si p_supported_ids non fourni, conserver l'ancienne liste statique
    -- pour rétrocompatibilité avec les appels SQL directs existants.
    v_supported := COALESCE(
        p_supported_ids,
        ARRAY['WB','IMF','IMF_WEO','IMF_DOTS','IMF_BOP',
              'WHO','ITU','FAO','UNDP','UNESCO',
              'EITI','SIPRI','USGS','ACLED','OECD']
    );

    INSERT INTO collect.ingestion_matrix_runs(
        include_pilot, year_from, year_to, requested_by
    )
    VALUES (p_include_pilot, p_year_from, p_year_to,
            COALESCE(p_requested_by, 'SYSTEM'))
    RETURNING id INTO v_run_id;

    INSERT INTO collect.ingestion_matrix_run_items(
        run_id, source_id, status, priority, supported, decision, reason
    )
    SELECT
        v_run_id,
        s.source_id,
        s.status,
        s.priority,
        -- #2 : supported calculé depuis le paramètre, pas hardcodé
        (s.source_id = ANY(v_supported))          AS supported,
        CASE
            WHEN s.is_active IS FALSE              THEN 'SKIP'
            WHEN s.source_id != ALL(v_supported)  THEN 'UNSUPPORTED'
            WHEN s.status = 'GO'                   THEN 'EXECUTE'
            WHEN s.status = 'PILOT'
             AND p_include_pilot                   THEN 'EXECUTE'
            WHEN s.status = 'PILOT'
             AND NOT p_include_pilot               THEN 'SKIP'
            ELSE 'SKIP'
        END                                        AS decision,
        CASE
            WHEN s.is_active IS FALSE              THEN 'Source inactive'
            WHEN s.source_id != ALL(v_supported)  THEN 'Provider non implémenté'
            WHEN s.status = 'GO'                   THEN 'GO autorisé'
            WHEN s.status = 'PILOT'
             AND p_include_pilot                   THEN 'PILOT autorisé (include_pilot=true)'
            WHEN s.status = 'PILOT'
             AND NOT p_include_pilot               THEN 'PILOT désactivé'
            WHEN s.status = 'NO_GO'
                THEN COALESCE(s.reason, 'NO_GO')
            ELSE 'Hors scope'
        END                                        AS reason
    FROM collect.source_registry s
    ORDER BY s.priority, s.source_id;

    RETURN QUERY
    SELECT i.run_id, i.source_id, i.status, i.priority,
           i.supported, i.decision, i.reason
    FROM collect.ingestion_matrix_run_items i
    WHERE i.run_id = v_run_id
    ORDER BY i.priority, i.source_id;
END;
$$;

-- ============================================================
-- Vue complémentaire : quels providers Python sont absents
-- de source_registry ? Utile pour diagnostiquer les UNSUPPORTED.
-- ============================================================
CREATE OR REPLACE VIEW collect.v_unsupported_providers AS
WITH python_supported(source_id) AS (
    VALUES
        ('WB'),('WHO'),('ITU'),('UNESCO'),
        ('IMF'),('IMF_WEO'),('IMF_DOTS'),('IMF_BOP'),
        ('FAO'),('UNDP'),('EITI'),('SIPRI'),('USGS'),('ACLED')
)
SELECT
    ps.source_id                           AS python_source_id,
    sr.source_id IS NOT NULL               AS in_registry,
    sr.status                              AS registry_status,
    sr.priority                            AS registry_priority
FROM python_supported ps
LEFT JOIN collect.source_registry sr
    ON sr.source_id = ps.source_id
ORDER BY in_registry, ps.source_id;

COMMENT ON VIEW collect.v_unsupported_providers IS
'Providers déclarés dans FETCHER_REGISTRY Python vs collect.source_registry.
Toute ligne avec in_registry=false indique un provider Python non enregistré
— il sera marqué UNSUPPORTED dans le plan d''exécution.
Corriger : INSERT INTO collect.source_registry(...).';

COMMIT;
