-- ================================================================
-- M3 : Procédure SCD Type 2 — Changement de régime monétaire
-- Usage : adapter les valeurs :iso3, :annee, :regime, :factor
-- OSA Observatory — Mai 2026
-- ================================================================

-- PROCÉDURE GÉNÉRIQUE de changement de régime
-- Étape 1 : fermer le régime actuel
-- UPDATE ma.country_monetary_regime
-- SET valid_to   = :annee_changement - 1,
--     is_current = false
-- WHERE country_iso3 = ':iso3'
--   AND is_current = true;
-- Étape 2 : insérer le nouveau régime
-- INSERT INTO ma.country_monetary_regime
--     (country_iso3, regime_type, mon_sov_factor, valid_from,
--      valid_to, is_current, source_note, decision_ref)
-- VALUES
--     (':iso3', ':nouveau_regime', :factor, :annee_changement,
--      NULL, true, ':note', ':reference');

-- ================================================================
-- CAS AES — Alliance des États du Sahel
-- MLI, BFA, NER : encore CFA_UEMOA en 2024
-- Transition vers UNION_SAHEL prévue
-- Script à exécuter quand la décision officielle est prise
-- ================================================================

-- Simulation documentée (NE PAS EXÉCUTER — exemple de référence)
-- DO $$
-- DECLARE v_annee SMALLINT := 2025; -- année de transition AES
-- BEGIN
--     -- Fermer CFA_UEMOA pour les 3 membres AES
--     UPDATE ma.country_monetary_regime
--     SET valid_to = v_annee - 1, is_current = false
--     WHERE country_iso3 IN ('MLI','BFA','NER')
--       AND is_current = true;
--
--     -- Insérer nouveau régime UNION_SAHEL
--     INSERT INTO ma.country_monetary_regime
--         (country_iso3, regime_type, mon_sov_factor, valid_from,
--          valid_to, is_current, source_note, decision_ref)
--     VALUES
--         ('MLI','UNION_SAHEL',0.65,v_annee,NULL,true,
--          'Union Monetaire AES','Accord monetaire AES :annee'),
--         ('BFA','UNION_SAHEL',0.65,v_annee,NULL,true,
--          'Union Monetaire AES','Accord monetaire AES :annee'),
--         ('NER','UNION_SAHEL',0.65,v_annee,NULL,true,
--          'Union Monetaire AES','Accord monetaire AES :annee');
-- END $$;

-- ================================================================
-- VUE DE CONTRÔLE — Vérification cohérence SCD Type 2
-- Un seul régime actif par pays à la fois
-- ================================================================

CREATE OR REPLACE VIEW ma.v_monetary_regime_current AS
SELECT
    c.iso3,
    c.name_fr AS pays,
    cmr.regime_type,
    cmr.mon_sov_factor,
    cmr.valid_from,
    cmr.valid_to,
    cmr.source_note,
    cmr.decision_ref
FROM rf.countries c
JOIN ma.country_monetary_regime cmr
    ON  cmr.country_iso3 = c.iso3
    AND cmr.is_current = true
ORDER BY cmr.regime_type, c.iso3;

-- Vérification : chaque pays a exactement 1 régime actif
SELECT
    country_iso3,
    COUNT(*) AS nb_regimes_actifs
FROM ma.country_monetary_regime
WHERE is_current = true
GROUP BY country_iso3
HAVING COUNT(*) > 1;

-- Résultat attendu : 0 lignes (aucun doublon)
SELECT 'M3 OK — SCD Type 2 operationnel' AS statut;