BEGIN;

-- Suppression contrainte sur table mere uniquement (se propage aux partitions)
ALTER TABLE ma.indicator_values DROP CONSTRAINT IF EXISTS chk_value_status;

-- Ajout nouvelle contrainte avec COMPUTED sur table mere uniquement
ALTER TABLE ma.indicator_values ADD CONSTRAINT chk_value_status
  CHECK (value_status IN ('OBSERVED','INTERPOLATED','EXTRAPOLATED','IMPUTED','MISSING','COMPUTED'));

-- Requalification des 3 indicateurs synthetiques
UPDATE ma.indicator_values
SET value_status = 'COMPUTED', confidence_score = 0.850
WHERE indicator_code IN ('ECO_PUBLIC_LEAKAGE','ECO_TAX_EFFICIENCY','GEO_SOVEREIGN_MARGIN')
  AND value_status = 'IMPUTED';

COMMIT;