-- ============================================================
-- OSA / ISA OBSERVATORY
-- PATCH : Peuplement rf.country_blocs — 54 pays africains
-- Date   : 2026-03-30
-- Source : Membres officiels au 1er janvier 2024
-- Blocs  : UA, CEDEAO, CEMAC, SADC, EAC, CEN-SAD, IGAD, UMA, COMESA
-- ============================================================

BEGIN;

-- ============================================================
-- Nettoyage préventif (idempotent)
-- ============================================================
DELETE FROM rf.country_blocs;

-- ============================================================
-- UA — Union Africaine (54 membres — tous les pays africains)
-- ============================================================
INSERT INTO rf.country_blocs (country_iso2, bloc_code, membership_status)
SELECT iso2, 'UA', 'member'
FROM rf.countries;

-- ============================================================
-- UMA — Union du Maghreb Arabe (5 membres)
-- ============================================================
INSERT INTO rf.country_blocs (country_iso2, bloc_code, membership_status)
VALUES
    ('DZ', 'UMA', 'member'),  -- Algérie
    ('LY', 'UMA', 'member'),  -- Libye
    ('MA', 'UMA', 'member'),  -- Maroc
    ('MR', 'UMA', 'member'),  -- Mauritanie
    ('TN', 'UMA', 'member')   -- Tunisie
ON CONFLICT DO NOTHING;

-- ============================================================
-- CEDEAO — Communauté économique des États d'Afrique de l'Ouest
-- (15 membres)
-- ============================================================
INSERT INTO rf.country_blocs (country_iso2, bloc_code, membership_status)
VALUES
    ('BJ', 'CEDEAO', 'member'),  -- Bénin
    ('BF', 'CEDEAO', 'member'),  -- Burkina Faso
    ('CV', 'CEDEAO', 'member'),  -- Cabo Verde
    ('CI', 'CEDEAO', 'member'),  -- Côte d'Ivoire
    ('GM', 'CEDEAO', 'member'),  -- Gambie
    ('GH', 'CEDEAO', 'member'),  -- Ghana
    ('GN', 'CEDEAO', 'member'),  -- Guinée
    ('GW', 'CEDEAO', 'member'),  -- Guinée-Bissau
    ('LR', 'CEDEAO', 'member'),  -- Libéria
    ('ML', 'CEDEAO', 'member'),  -- Mali
    ('MR', 'CEDEAO', 'member'),  -- Mauritanie
    ('NE', 'CEDEAO', 'member'),  -- Niger
    ('NG', 'CEDEAO', 'member'),  -- Nigéria
    ('SL', 'CEDEAO', 'member'),  -- Sierra Leone
    ('SN', 'CEDEAO', 'member'),  -- Sénégal
    ('TG', 'CEDEAO', 'member')   -- Togo
ON CONFLICT DO NOTHING;

-- ============================================================
-- CEMAC — Communauté économique et monétaire d'Afrique Centrale
-- (6 membres)
-- ============================================================
INSERT INTO rf.country_blocs (country_iso2, bloc_code, membership_status)
VALUES
    ('CM', 'CEMAC', 'member'),  -- Cameroun
    ('CF', 'CEMAC', 'member'),  -- République centrafricaine
    ('TD', 'CEMAC', 'member'),  -- Tchad
    ('CG', 'CEMAC', 'member'),  -- Congo
    ('GQ', 'CEMAC', 'member'),  -- Guinée équatoriale
    ('GA', 'CEMAC', 'member')   -- Gabon
ON CONFLICT DO NOTHING;

-- ============================================================
-- SADC — Communauté de développement d'Afrique australe
-- (16 membres)
-- ============================================================
INSERT INTO rf.country_blocs (country_iso2, bloc_code, membership_status)
VALUES
    ('AO', 'SADC', 'member'),  -- Angola
    ('BW', 'SADC', 'member'),  -- Botswana
    ('KM', 'SADC', 'member'),  -- Comores
    ('CD', 'SADC', 'member'),  -- RD Congo
    ('SZ', 'SADC', 'member'),  -- Eswatini
    ('LS', 'SADC', 'member'),  -- Lesotho
    ('MG', 'SADC', 'member'),  -- Madagascar
    ('MW', 'SADC', 'member'),  -- Malawi
    ('MU', 'SADC', 'member'),  -- Maurice
    ('MZ', 'SADC', 'member'),  -- Mozambique
    ('NA', 'SADC', 'member'),  -- Namibie
    ('SC', 'SADC', 'member'),  -- Seychelles
    ('ZA', 'SADC', 'member'),  -- Afrique du Sud
    ('TZ', 'SADC', 'member'),  -- Tanzanie
    ('ZM', 'SADC', 'member'),  -- Zambie
    ('ZW', 'SADC', 'member')   -- Zimbabwe
ON CONFLICT DO NOTHING;

-- ============================================================
-- EAC — Communauté est-africaine (7 membres)
-- ============================================================
INSERT INTO rf.country_blocs (country_iso2, bloc_code, membership_status)
VALUES
    ('BI', 'EAC', 'member'),  -- Burundi
    ('CD', 'EAC', 'member'),  -- RD Congo
    ('KE', 'EAC', 'member'),  -- Kenya
    ('RW', 'EAC', 'member'),  -- Rwanda
    ('SS', 'EAC', 'member'),  -- Soudan du Sud
    ('TZ', 'EAC', 'member'),  -- Tanzanie
    ('UG', 'EAC', 'member')   -- Ouganda
ON CONFLICT DO NOTHING;

-- ============================================================
-- COMESA — Marché commun de l'Afrique orientale et australe
-- (21 membres)
-- ============================================================
INSERT INTO rf.country_blocs (country_iso2, bloc_code, membership_status)
VALUES
    ('BI', 'COMESA', 'member'),  -- Burundi
    ('KM', 'COMESA', 'member'),  -- Comores
    ('CD', 'COMESA', 'member'),  -- RD Congo
    ('DJ', 'COMESA', 'member'),  -- Djibouti
    ('EG', 'COMESA', 'member'),  -- Égypte
    ('ER', 'COMESA', 'member'),  -- Érythrée
    ('SZ', 'COMESA', 'member'),  -- Eswatini
    ('ET', 'COMESA', 'member'),  -- Éthiopie
    ('KE', 'COMESA', 'member'),  -- Kenya
    ('LY', 'COMESA', 'member'),  -- Libye
    ('MG', 'COMESA', 'member'),  -- Madagascar
    ('MW', 'COMESA', 'member'),  -- Malawi
    ('MU', 'COMESA', 'member'),  -- Maurice
    ('MA', 'COMESA', 'member'),  -- Maroc
    ('MZ', 'COMESA', 'member'),  -- Mozambique
    ('RW', 'COMESA', 'member'),  -- Rwanda
    ('SC', 'COMESA', 'member'),  -- Seychelles
    ('SO', 'COMESA', 'member'),  -- Somalie
    ('SD', 'COMESA', 'member'),  -- Soudan
    ('TN', 'COMESA', 'member'),  -- Tunisie
    ('UG', 'COMESA', 'member'),  -- Ouganda
    ('ZM', 'COMESA', 'member'),  -- Zambie
    ('ZW', 'COMESA', 'member')   -- Zimbabwe
ON CONFLICT DO NOTHING;

-- ============================================================
-- IGAD — Autorité intergouvernementale pour le développement
-- (8 membres)
-- ============================================================
INSERT INTO rf.country_blocs (country_iso2, bloc_code, membership_status)
VALUES
    ('DJ', 'IGAD', 'member'),  -- Djibouti
    ('ER', 'IGAD', 'member'),  -- Érythrée
    ('ET', 'IGAD', 'member'),  -- Éthiopie
    ('KE', 'IGAD', 'member'),  -- Kenya
    ('SO', 'IGAD', 'member'),  -- Somalie
    ('SS', 'IGAD', 'member'),  -- Soudan du Sud
    ('SD', 'IGAD', 'member'),  -- Soudan
    ('UG', 'IGAD', 'member')   -- Ouganda
ON CONFLICT DO NOTHING;

-- ============================================================
-- CEN-SAD — Communauté des États sahélo-sahariens
-- (29 membres)
-- ============================================================
INSERT INTO rf.country_blocs (country_iso2, bloc_code, membership_status)
VALUES
    ('BJ', 'CEN-SAD', 'member'),  -- Bénin
    ('BF', 'CEN-SAD', 'member'),  -- Burkina Faso
    ('CF', 'CEN-SAD', 'member'),  -- Rép. centrafricaine
    ('TD', 'CEN-SAD', 'member'),  -- Tchad
    ('KM', 'CEN-SAD', 'member'),  -- Comores
    ('CI', 'CEN-SAD', 'member'),  -- Côte d'Ivoire
    ('DJ', 'CEN-SAD', 'member'),  -- Djibouti
    ('EG', 'CEN-SAD', 'member'),  -- Égypte
    ('ER', 'CEN-SAD', 'member'),  -- Érythrée
    ('GH', 'CEN-SAD', 'member'),  -- Ghana
    ('GN', 'CEN-SAD', 'member'),  -- Guinée
    ('GW', 'CEN-SAD', 'member'),  -- Guinée-Bissau
    ('LY', 'CEN-SAD', 'member'),  -- Libye
    ('ML', 'CEN-SAD', 'member'),  -- Mali
    ('MR', 'CEN-SAD', 'member'),  -- Mauritanie
    ('MA', 'CEN-SAD', 'member'),  -- Maroc
    ('NE', 'CEN-SAD', 'member'),  -- Niger
    ('NG', 'CEN-SAD', 'member'),  -- Nigéria
    ('SN', 'CEN-SAD', 'member'),  -- Sénégal
    ('SL', 'CEN-SAD', 'member'),  -- Sierra Leone
    ('SO', 'CEN-SAD', 'member'),  -- Somalie
    ('SD', 'CEN-SAD', 'member'),  -- Soudan
    ('TG', 'CEN-SAD', 'member'),  -- Togo
    ('TN', 'CEN-SAD', 'member')   -- Tunisie
ON CONFLICT DO NOTHING;

-- ============================================================
-- Vérifications post-patch
-- ============================================================
DO $$
DECLARE
    v_total        INT;
    v_ua           INT;
    v_sans_bloc    INT;
BEGIN
    SELECT COUNT(*) INTO v_total FROM rf.country_blocs;
    SELECT COUNT(*) INTO v_ua
        FROM rf.country_blocs WHERE bloc_code = 'UA';
    SELECT COUNT(*) INTO v_sans_bloc
        FROM rf.countries c
        WHERE NOT EXISTS (
            SELECT 1 FROM rf.country_blocs cb
            WHERE cb.country_iso2 = c.iso2
        );

    IF v_ua <> 54 THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : UA a % membres (attendu 54)', v_ua;
    END IF;
    IF v_sans_bloc > 0 THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : % pays sans aucun bloc', v_sans_bloc;
    END IF;

    RAISE NOTICE 'PATCH OK —';
    RAISE NOTICE '  Lignes totales       : %', v_total;
    RAISE NOTICE '  Membres UA           : %', v_ua;
    RAISE NOTICE '  Pays sans bloc       : %', v_sans_bloc;
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
-- SELECT c.iso3, c.name_fr,
--        STRING_AGG(cb.bloc_code, ', ' ORDER BY cb.bloc_code) AS blocs
-- FROM rf.countries c
-- JOIN rf.country_blocs cb ON cb.country_iso2 = c.iso2
-- GROUP BY c.iso3, c.name_fr
-- ORDER BY c.name_fr;
