--- Patch_audit_trajectory.sql

--- Comme Sprint 21 introduit officiellement les indicateurs de trajectoire, 
--- Créer une vue d'audit dédiée :

CREATE OR REPLACE VIEW ops.v_audit_trajectory AS

SELECT
indicator_code,
COUNT(*) AS nb_values,
MIN(value_numeric) AS min_value,
AVG(value_numeric) AS avg_value,
MAX(value_numeric) AS max_value

FROM indicator_values iv
JOIN indicators i
ON i.indicator_id = iv.indicator_id

WHERE i.indicator_code IN (

'PMIN_VALUE_CAPTURE',
'PMIN_VALUE_LEAKAGE',
'PMIN_SMUGGLING_SIGNAL_RANK',
'PHUM_VALUE_CAPTURE'
```

)

GROUP BY indicator_code;

