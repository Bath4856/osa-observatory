-- ============================================================
-- OSA / ISA OBSERVATORY
-- PATCH : Ajout G5 Sahel et AES (Alliance des États du Sahel)
-- Date   : 2026-03-30
-- Contexte :
--   - G5 Sahel : créé en 2014 — coopération sécuritaire et
--     développement. Mali, Niger, Burkina ont suspendu leur
--     participation suite aux coups d'État (2021-2023) mais
--     restent membres fondateurs.
--   - AES : Alliance des États du Sahel, créée juillet 2023,
--     confédération effective janvier 2024. Mali, Niger,
--     Burkina Faso — rupture assumée avec la CEDEAO.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Ajout des deux blocs dans rf.regional_blocs
-- ============================================================

INSERT INTO rf.regional_blocs (code, name_fr, name_en, description)
VALUES
    ('G5SAH',
     'G5 Sahel',
     'G5 Sahel',
     'Cadre institutionnel de coopération sécuritaire et de développement — '
     'Burkina Faso, Mali, Mauritanie, Niger, Tchad. '
     'Créé en 2014. Mali, Niger et Burkina ont suspendu leur participation en 2022-2023.'),
    ('AES',
     'Alliance des États du Sahel',
     'Alliance of Sahel States',
     'Confédération créée en juillet 2023, effective janvier 2024. '
     'Mali, Niger, Burkina Faso — issus des coups d''État militaires. '
     'Rupture avec la CEDEAO annoncée en janvier 2024.')
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 2. Membres G5 Sahel (5 membres fondateurs)
-- ============================================================

INSERT INTO rf.country_blocs (country_iso2, bloc_code, membership_status)
VALUES
    ('BF', 'G5SAH', 'suspended'),  -- Burkina Faso — suspendu 2022
    ('ML', 'G5SAH', 'suspended'),  -- Mali — suspendu 2022
    ('MR', 'G5SAH', 'member'),     -- Mauritanie — membre actif
    ('NE', 'G5SAH', 'suspended'),  -- Niger — suspendu 2023
    ('TD', 'G5SAH', 'member')      -- Tchad — membre actif
ON CONFLICT DO NOTHING;

-- ============================================================
-- 3. Membres AES (3 membres fondateurs)
-- ============================================================

INSERT INTO rf.country_blocs (country_iso2, bloc_code, membership_status)
VALUES
    ('BF', 'AES', 'member'),  -- Burkina Faso
    ('ML', 'AES', 'member'),  -- Mali
    ('NE', 'AES', 'member')   -- Niger
ON CONFLICT DO NOTHING;

-- ============================================================
-- 4. Vérifications post-patch
-- ============================================================

DO $$
DECLARE
    v_g5sah   INT;
    v_aes     INT;
    v_blocs   INT;
BEGIN
    SELECT COUNT(*) INTO v_g5sah
        FROM rf.country_blocs WHERE bloc_code = 'G5SAH';
    SELECT COUNT(*) INTO v_aes
        FROM rf.country_blocs WHERE bloc_code = 'AES';
    SELECT COUNT(*) INTO v_blocs
        FROM rf.regional_blocs;

    IF v_g5sah <> 5 THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : G5 Sahel a % membres (attendu 5)', v_g5sah;
    END IF;
    IF v_aes <> 3 THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : AES a % membres (attendu 3)', v_aes;
    END IF;

    RAISE NOTICE 'PATCH OK —';
    RAISE NOTICE '  Blocs régionaux total : %', v_blocs;
    RAISE NOTICE '  G5 Sahel              : % membres (3 suspendus, 2 actifs)', v_g5sah;
    RAISE NOTICE '  AES                   : % membres', v_aes;
END;
$$;

COMMIT;

-- ============================================================
-- Contrôle rapide post-déploiement
-- ============================================================
-- SELECT b.code, b.name_fr, COUNT(*) AS nb_membres
-- FROM rf.country_blocs cb
-- JOIN rf.regional_blocs b ON b.code = cb.bloc_code
-- GROUP BY b.code, b.name_fr
-- ORDER BY b.code;
--
-- Vérifier les 3 pays AES avec tous leurs blocs :
-- SELECT c.iso3, c.name_fr,
--        STRING_AGG(cb.bloc_code || '(' || cb.membership_status || ')', ', '
--                   ORDER BY cb.bloc_code) AS blocs
-- FROM rf.countries c
-- JOIN rf.country_blocs cb ON cb.country_iso2 = c.iso2
-- WHERE c.iso3 IN ('MLI', 'NER', 'BFA')
-- GROUP BY c.iso3, c.name_fr
-- ORDER BY c.name_fr;
