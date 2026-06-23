--- Patch_audit_scientific_drift.sql

CREATE OR REPLACE VIEW ops.v_scientific_drift AS

SELECT
indicator_id,
year,
AVG(value_numeric) AS avg_value

FROM indicator_values

GROUP BY
indicator_id,
year;

