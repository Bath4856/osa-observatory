CREATE OR REPLACE FUNCTION rf.protect_referential()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'RF immuable : suppression interdite sur %. Creez une nouvelle version.', TG_TABLE_NAME;
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF TG_TABLE_NAME = 'indicators' THEN
            IF (OLD.code IS DISTINCT FROM NEW.code) OR
               (OLD.pillar_code IS DISTINCT FROM NEW.pillar_code) OR
               (OLD.direction IS DISTINCT FROM NEW.direction) OR
               (OLD.unit_code IS DISTINCT FROM NEW.unit_code) THEN
                RAISE EXCEPTION 'RF immuable : mutation des champs structurants interdite sur rf.indicators.';
            END IF;
        END IF;
        IF TG_TABLE_NAME = 'pillars' THEN
            IF (OLD.code IS DISTINCT FROM NEW.code) THEN
                RAISE EXCEPTION 'RF immuable : mutation du code pilier interdite sur rf.pillars.';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;