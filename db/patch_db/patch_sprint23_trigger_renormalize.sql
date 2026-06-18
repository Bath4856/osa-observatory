-- Trigger de renormalisation automatique des poids
-- Sprint 23 -- apres ajout/suppression/activation/desactivation
-- d'un indicateur dans ma.indicator_meta_links, les poids
-- des indicateurs actifs du meme meta_code/ref_year sont
-- automatiquement renormalises a 1/nb_actifs (equiponderation).

CREATE OR REPLACE FUNCTION ma.trg_renormalize_weights()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $func$
DECLARE
    v_nb_actifs INT;
BEGIN
    SELECT COUNT(*)
    INTO v_nb_actifs
    FROM ma.indicator_meta_links
    WHERE meta_code = COALESCE(NEW.meta_code, OLD.meta_code)
      AND ref_year  = COALESCE(NEW.ref_year,  OLD.ref_year)
      AND is_active = true;

    IF v_nb_actifs = 0 THEN
        RETURN NEW;
    END IF;

    UPDATE ma.indicator_meta_links
    SET weight = 1.0 / v_nb_actifs
    WHERE meta_code = COALESCE(NEW.meta_code, OLD.meta_code)
      AND ref_year  = COALESCE(NEW.ref_year,  OLD.ref_year)
      AND is_active = true;

    RETURN NEW;
END;
$func$;

DROP TRIGGER IF EXISTS trg_renormalize_weights ON ma.indicator_meta_links;

CREATE TRIGGER trg_renormalize_weights
AFTER INSERT OR UPDATE OF is_active ON ma.indicator_meta_links
FOR EACH ROW
EXECUTE FUNCTION ma.trg_renormalize_weights();
