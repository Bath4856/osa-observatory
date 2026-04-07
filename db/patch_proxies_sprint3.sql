-- ============================================================
-- OSA / ISA OBSERVATORY
-- PATCH : Correction proxies sémantiques — Sprint 3
-- Date  : 2026-03-28
-- Contexte : audit Sprint 1-3 — 4 proxies sans lien sémantique
--            avec leur indicateur OSA cible.
--
-- Actions :
--   1. MON_AUT  → is_active = FALSE (aucun proxy acceptable disponible)
--   2. MON_STB  → remappé vers WB FB.BNK.CAPA.ZS (via fetcher_wb)
--   3. HUM_MIG  → remappé vers WB SM.POP.NETM    (via fetcher_wb)
--   4. HUM_EDU  → remappé vers WB SE.SEC.ENRR    (via fetcher_wb)
-- ============================================================

BEGIN;

-- ============================================================
-- 1. MON_AUT — désactivation (aucun proxy acceptable)
--    GGX_NGDP (dépenses publiques) ≠ autonomie banque centrale
--    Sera réactivé en Sprint 5 avec un indicateur institutionnel.
-- ============================================================

UPDATE rf.indicator_meta_link
SET    is_active = FALSE
WHERE  indicator_code = 'MON_AUT';

UPDATE ma.indicator_meta_links
SET    is_active = FALSE
WHERE  indicator_code = 'MON_AUT';

UPDATE ma.indicator_meta
SET    is_active = FALSE
WHERE  indicator_code = 'MON_AUT';

-- ============================================================
-- 2. Mise à jour collect.indicator_source — retirer l'ancien
--    mapping IMF pour MON_STB, et les mappings WHO pour
--    HUM_EDU et HUM_MIG. Les nouvelles sources WB seront
--    insérées automatiquement par fetcher_wb lors de la
--    première collecte (ON CONFLICT DO UPDATE).
-- ============================================================

-- Désactiver (pas supprimer) les anciens mappings pour garder la traçabilité
UPDATE collect.indicator_source
SET    is_active = FALSE
WHERE  indicator_code IN ('MON_STB', 'HUM_EDU', 'HUM_MIG')
  AND  endpoint_id IN (
           SELECT id FROM collect.provider_endpoints
           WHERE  endpoint_code IN ('IMF_WEO_INDICATOR', 'WHO_GHO_INDICATOR')
       );

-- Insérer les nouveaux mappings WB pour les 3 indicateurs
WITH wb_ep AS (
    SELECT id FROM collect.provider_endpoints
    WHERE  endpoint_code = 'WB_ALL_COUNTRIES'
)
INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, is_active)
SELECT
    v.indicator_code,
    wb_ep.id,
    v.wb_code,
    v.notes,
    TRUE
FROM wb_ep,
(VALUES
    ('MON_STB', 'FB.BNK.CAPA.ZS',
     'Ratio capital bancaire / actifs totaux (%). Remplace proxy IMF LP (population).'),
    ('HUM_MIG', 'SM.POP.NETM',
     'Solde migratoire net. Remplace mortalité MNT WHO (NCDMORT3070).'),
    ('HUM_EDU', 'SE.SEC.ENRR',
     'Taux scolarisation secondaire brut (%). Remplace densité médecins WHO (HWF_0001). '
     'À remplacer par composante éducation IDH UNDP en Sprint 4.')
) AS v(indicator_code, wb_code, notes),
LATERAL (SELECT TRUE) _
ON CONFLICT (indicator_code, endpoint_id)
DO UPDATE SET
    source_indicator_code = EXCLUDED.source_indicator_code,
    source_notes          = EXCLUDED.source_notes,
    is_active             = TRUE;

-- ============================================================
-- 3. Mettre à jour les notes dans rf.indicators
--    Désactivation temporaire du trigger anti-mutation
-- ============================================================
ALTER TABLE rf.indicators DISABLE TRIGGER trg_protect_indicators;

UPDATE rf.indicators
SET    description = 'Désactivé Sprint 3 — aucun proxy API disponible pour l''autonomie '
                     'de la banque centrale. À réactiver en Sprint 5 avec un indicateur '
                     'institutionnel (ex: CBI index Dincer-Eichengreen).'
WHERE  code = 'MON_AUT';

UPDATE rf.indicators
SET    description = 'Ratio capital et réserves / actifs totaux (%). '
                     'Source : WB FB.BNK.CAPA.ZS (FSI/IMF). '
                     'Remplace proxy IMF LP (population totale, sans lien sémantique).'
WHERE  code = 'MON_STB';

UPDATE rf.indicators
SET    description = 'Solde migratoire net annuel (émigration – immigration). '
                     'Source : WB SM.POP.NETM. '
                     'Proxy fuite des cerveaux — à affiner en Sprint 5 avec SM.EMI.TERT.ZS.'
WHERE  code = 'HUM_MIG';

UPDATE rf.indicators
SET    description = 'Taux brut de scolarisation dans le secondaire (%). '
                     'Source : WB SE.SEC.ENRR. '
                     'À remplacer par composante éducation IDH (UNDP) en Sprint 4.'
WHERE  code = 'HUM_EDU';

-- Réactivation du trigger
ALTER TABLE rf.indicators ENABLE TRIGGER trg_protect_indicators;

-- ============================================================
-- 4. Vérifications post-patch
-- ============================================================

DO $$
DECLARE
    v_mon_aut_active  BOOLEAN;
    v_mon_stb_wb      TEXT;
    v_hum_mig_wb      TEXT;
    v_hum_edu_wb      TEXT;
    v_old_sources_off INT;
BEGIN
    -- MON_AUT désactivé dans les deux tables de liens
    SELECT bool_or(is_active) INTO v_mon_aut_active
    FROM rf.indicator_meta_link WHERE indicator_code = 'MON_AUT';

    IF v_mon_aut_active IS TRUE THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : MON_AUT encore actif dans rf.indicator_meta_link';
    END IF;

    -- Nouveaux codes WB présents dans collect.indicator_source
    SELECT source_indicator_code INTO v_mon_stb_wb
    FROM collect.indicator_source
    WHERE indicator_code = 'MON_STB' AND is_active = TRUE
    ORDER BY id DESC LIMIT 1;

    SELECT source_indicator_code INTO v_hum_mig_wb
    FROM collect.indicator_source
    WHERE indicator_code = 'HUM_MIG' AND is_active = TRUE
    ORDER BY id DESC LIMIT 1;

    SELECT source_indicator_code INTO v_hum_edu_wb
    FROM collect.indicator_source
    WHERE indicator_code = 'HUM_EDU' AND is_active = TRUE
    ORDER BY id DESC LIMIT 1;

    IF v_mon_stb_wb <> 'FB.BNK.CAPA.ZS' THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : MON_STB source incorrecte : %', v_mon_stb_wb;
    END IF;
    IF v_hum_mig_wb <> 'SM.POP.NETM' THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : HUM_MIG source incorrecte : %', v_hum_mig_wb;
    END IF;
    IF v_hum_edu_wb <> 'SE.SEC.ENRR' THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : HUM_EDU source incorrecte : %', v_hum_edu_wb;
    END IF;

    -- Anciens mappings IMF/WHO bien désactivés
    SELECT COUNT(*) INTO v_old_sources_off
    FROM collect.indicator_source
    WHERE indicator_code IN ('MON_STB', 'HUM_EDU', 'HUM_MIG')
      AND is_active = FALSE;

    RAISE NOTICE 'PATCH OK —';
    RAISE NOTICE '  MON_AUT désactivé : TRUE';
    RAISE NOTICE '  MON_STB → %', v_mon_stb_wb;
    RAISE NOTICE '  HUM_MIG → %', v_hum_mig_wb;
    RAISE NOTICE '  HUM_EDU → %', v_hum_edu_wb;
    RAISE NOTICE '  Anciens mappings désactivés : %', v_old_sources_off;
END;
$$;

COMMIT;

-- ============================================================
-- Contrôle rapide post-déploiement
-- ============================================================
-- SELECT code, description, is_active
-- FROM   rf.indicators
-- WHERE  code IN ('MON_AUT','MON_STB','HUM_MIG','HUM_EDU');
--
-- SELECT i.indicator_code, pe.endpoint_code, i.source_indicator_code, i.is_active
-- FROM   collect.indicator_source i
-- JOIN   collect.provider_endpoints pe ON pe.id = i.endpoint_id
-- WHERE  i.indicator_code IN ('MON_AUT','MON_STB','HUM_MIG','HUM_EDU')
-- ORDER  BY i.indicator_code, i.is_active DESC;
