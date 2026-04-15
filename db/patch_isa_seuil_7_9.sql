-- PATCH ISA SEUIL L7 — 7/9 piliers minimum
-- Passage de 6/8 a 7/9 suite integration pilier PRES
BEGIN;
CREATE OR REPLACE FUNCTION ma.compute_isa(p_year smallint, p_method_version integer DEFAULT 1)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
    v_inserted INT;
BEGIN
    INSERT INTO ma.isa_index
        (country_iso3, year, isa_score, pillar_count, method_version_id)
    SELECT
        ps.country_iso3,
        p_year,
        ROUND(AVG(ps.score) * 100, 2),
        COUNT(DISTINCT ps.pillar_code),
        p_method_version
    FROM ma.pillar_scores ps
    WHERE ps.year = p_year
      AND ps.method_version_id = p_method_version
    GROUP BY ps.country_iso3
    HAVING COUNT(DISTINCT ps.pillar_code) >= 7  -- minimum 7/9 piliers
    ON CONFLICT (country_iso3, year, method_version_id)
        DO UPDATE SET
            isa_score    = EXCLUDED.isa_score,
            pillar_count = EXCLUDED.pillar_count,
            computed_at  = now();
      GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$function$;
DO $$ BEGIN
RAISE NOTICE 'PATCH ISA SEUIL — compute_isa mise a jour : seuil 7/9';
END $$;
COMMIT;
