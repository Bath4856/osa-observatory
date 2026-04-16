-- ============================================================
-- OSA Observatory — patch_port_agreements.sql
-- Sprint 5 — Avril 2026
-- ============================================================
-- Crée la table rf.port_agreements qui documente les accords
-- d'accès portuaire des pays africains enclavés.
--
-- Utilisée par l'imputer PTRA (étape 0) pour distinguer :
--   - Pays enclavé SANS accord actif → PTRA_PORT_* = 0 (réel)
--   - Pays enclavé AVEC accord actif → proxy via port d'accès
--
-- Modèle temporel : valid_from / valid_to permettent de
-- reconstituer l'état des accords pour chaque année ISA
-- (2010–2024), notamment les ruptures (ex : Niger 2023).
--
-- Idempotent — peut être rejoué sans erreur.
-- ============================================================

BEGIN;

-- ── 1. Table rf.port_agreements ───────────────────────────
CREATE TABLE IF NOT EXISTS rf.port_agreements (
    id              SERIAL PRIMARY KEY,

    -- Pays enclavé bénéficiaire de l'accord
    landlocked_iso3 CHAR(3)      NOT NULL
                    REFERENCES rf.countries(iso3),

    -- Pays côtier qui héberge le port d'accès
    coastal_iso3    CHAR(3)      NOT NULL
                    REFERENCES rf.countries(iso3),

    -- Nom du port d'accès principal
    port_name       VARCHAR(100) NOT NULL,

    -- Nom du corridor logistique officiel (si existant)
    corridor_name   VARCHAR(200),

    -- Cadre juridique de l'accord
    -- BILATERAL    : accord bilatéral entre les deux pays
    -- REGIONAL     : accord cadre bloc régional (UEMOA, SADC, EAC, CEMAC)
    -- DEFACTO      : accès de fait sans accord formel structuré
    agreement_type  VARCHAR(20)  NOT NULL
                    CHECK (agreement_type IN ('BILATERAL','REGIONAL','DEFACTO')),

    -- Score de confiance pour l'imputer
    -- BILATERAL → 0.75
    -- REGIONAL  → 0.70
    -- DEFACTO   → 0.55
    confidence      NUMERIC(4,2) NOT NULL
                    CHECK (confidence BETWEEN 0 AND 1),

    -- Validité temporelle
    valid_from      INT          NOT NULL,  -- année de début
    valid_to        INT,                    -- NULL = accord toujours actif

    -- Notes documentaires
    notes           TEXT,

    created_at      TIMESTAMPTZ  DEFAULT NOW(),

    -- Un pays enclavé peut avoir plusieurs accords (ports différents)
    -- mais un seul accord actif PAR port à une date donnée
    CONSTRAINT uq_port_agreement
        UNIQUE (landlocked_iso3, coastal_iso3, port_name, valid_from)
);

-- Index pour l'imputer (requête par pays + année)
CREATE INDEX IF NOT EXISTS idx_port_agreements_landlocked
    ON rf.port_agreements (landlocked_iso3, valid_from, valid_to);

CREATE INDEX IF NOT EXISTS idx_port_agreements_active
    ON rf.port_agreements (landlocked_iso3)
    WHERE valid_to IS NULL;

-- ── 2. Fonction utilitaire ────────────────────────────────
-- Retourne les accords actifs pour un pays et une année donnés.
-- Utilisée par l'imputer via appel SQL direct.
CREATE OR REPLACE FUNCTION rf.port_agreements_at(
    p_iso3 CHAR(3),
    p_year INT
)
RETURNS TABLE (
    coastal_iso3    CHAR(3),
    port_name       VARCHAR(100),
    corridor_name   VARCHAR(200),
    agreement_type  VARCHAR(20),
    confidence      NUMERIC(4,2)
)
LANGUAGE sql STABLE AS $$
    SELECT coastal_iso3, port_name, corridor_name,
           agreement_type, confidence
    FROM rf.port_agreements
    WHERE landlocked_iso3 = p_iso3
      AND valid_from <= p_year
      AND (valid_to IS NULL OR valid_to >= p_year)
    ORDER BY confidence DESC, valid_from DESC;
$$;

-- ── 3. Vue synthétique accords actifs ─────────────────────
CREATE OR REPLACE VIEW rf.v_port_agreements_current AS
SELECT
    pa.landlocked_iso3,
    cl.name_fr                          AS pays_enclave,
    pa.coastal_iso3,
    cc.name_fr                          AS pays_cotier,
    pa.port_name,
    pa.corridor_name,
    pa.agreement_type,
    pa.confidence,
    pa.valid_from,
    pa.valid_to,
    CASE WHEN pa.valid_to IS NULL THEN 'ACTIF' ELSE 'EXPIRÉ' END AS statut
FROM rf.port_agreements pa
JOIN rf.countries cl ON cl.iso3 = pa.landlocked_iso3
JOIN rf.countries cc ON cc.iso3 = pa.coastal_iso3
ORDER BY pa.landlocked_iso3, pa.confidence DESC;

-- ── 4. Données — Afrique Centrale ────────────────────────

-- RCA → Cameroun (port de Douala)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('CAF', 'CMR', 'Douala', 'Corridor Bangui-Douala',
     'BILATERAL', 0.75, 2010, NULL,
     'Accord bilatéral RCA-Cameroun. Douala = port principal RCA. '
     'Transit géré par le bureau de douane de Beloko (frontière).')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Tchad → Cameroun (port de Douala)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('TCD', 'CMR', 'Douala', 'Corridor N''Djamena-Douala (Trans-Camerounais)',
     'BILATERAL', 0.75, 2010, NULL,
     'Accord bilatéral Tchad-Cameroun. ~80% du commerce extérieur tchadien '
     'transite par Douala. Distance N''Djamena-Douala : ~1 700 km.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Tchad → Congo (port de Pointe-Noire) — alternative secondaire
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('TCD', 'COG', 'Pointe-Noire', 'Corridor Tchad-Congo',
     'DEFACTO', 0.55, 2010, NULL,
     'Accès secondaire de facto via République du Congo. '
     'Usage marginal comparé à Douala.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- ── 5. Données — Afrique de l'Ouest ──────────────────────

-- Mali → Côte d'Ivoire (port d'Abidjan) — SUSPENDU 2022
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('MLI', 'CIV', 'Abidjan', 'Corridor Bamako-Abidjan',
     'REGIONAL', 0.70, 2010, 2022,
     'Accord UEMOA. Suspendu suite aux sanctions CEDEAO contre le Mali '
     '(janvier 2022). Frontières fermées. Accès rétabli partiellement 2023.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Mali → Côte d'Ivoire — rétablissement partiel 2023
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('MLI', 'CIV', 'Abidjan', 'Corridor Bamako-Abidjan (rétabli)',
     'REGIONAL', 0.60, 2023, NULL,
     'Rétablissement partiel post-sanctions CEDEAO. '
     'Confiance réduite (instabilité politique persistante).')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Mali → Sénégal (port de Dakar)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('MLI', 'SEN', 'Dakar', 'Corridor Bamako-Dakar',
     'BILATERAL', 0.70, 2010, NULL,
     'Accord bilatéral Mali-Sénégal. Voie ferrée Bamako-Dakar '
     '(Dakar-Bamako Ferroviaire). Accès maintenu pendant sanctions CEDEAO 2022.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Mali → Guinée (port de Conakry) — alternatif
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('MLI', 'GIN', 'Conakry', 'Corridor Bamako-Conakry',
     'DEFACTO', 0.55, 2010, NULL,
     'Accès alternatif utilisé pendant les crises d''accès à Abidjan/Dakar.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Burkina Faso → Côte d'Ivoire (port d'Abidjan)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('BFA', 'CIV', 'Abidjan', 'Corridor Ouagadougou-Abidjan',
     'REGIONAL', 0.70, 2010, NULL,
     'Accord UEMOA. Principal accès maritime du Burkina (~70% du commerce).')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Burkina Faso → Ghana (port de Tema)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('BFA', 'GHA', 'Tema', 'Corridor Ouagadougou-Tema',
     'BILATERAL', 0.70, 2010, NULL,
     'Accord bilatéral Burkina-Ghana. Alternative à Abidjan (~20% du commerce).')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Niger → Bénin (port de Cotonou) — SUSPENDU 2023
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('NER', 'BEN', 'Cotonou', 'Corridor Niamey-Cotonou',
     'BILATERAL', 0.75, 2010, 2023,
     'Accord bilatéral Niger-Bénin. Suspendu suite au coup d''État nigérien '
     '(juillet 2023) et aux sanctions CEDEAO. Frontières fermées.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Niger → Nigeria (port de Lagos/Apapa)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('NER', 'NGA', 'Lagos', 'Corridor Niamey-Lagos',
     'BILATERAL', 0.65, 2010, NULL,
     'Accès via Nigeria. Maintenu même pendant la crise 2023. '
     'Confiance réduite (instabilité frontalière).')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- ── 6. Données — Afrique de l'Est ────────────────────────

-- Éthiopie → Djibouti (port de Djibouti)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('ETH', 'DJI', 'Djibouti', 'Corridor Addis-Abeba-Djibouti',
     'BILATERAL', 0.75, 2010, NULL,
     'Accord stratégique majeur. ~95% du commerce éthiopien transite par Djibouti. '
     'Chemin de fer électrique Addis-Djibouti (2017). '
     'Zone franche dédiée à l''Éthiopie au port de Djibouti.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Éthiopie → Érythrée (port de Massawa) — SUSPENDU 1998-2018
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('ETH', 'ERI', 'Massawa', 'Corridor Éthiopie-Érythrée',
     'BILATERAL', 0.60, 2018, NULL,
     'Rétablissement des relations ETH-ERI (accord de paix 2018, Nobel 2019). '
     'Accès partiel rétabli mais infrastructure dégradée. '
     'Suspendu de facto pendant le conflit du Tigré 2020-2022.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Éthiopie → Somaliland (port de Berbera) — 2018+
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('ETH', 'SOM', 'Berbera', 'Corridor Éthiopie-Berbera',
     'BILATERAL', 0.60, 2018, NULL,
     'Accord ETH-Somaliland (2018) — prise de participation ETH dans port de Berbera. '
     'Statut juridique complexe (Somaliland non reconnu internationalement). '
     'Confiance réduite en raison de l''instabilité régionale.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Ouganda → Kenya (port de Mombasa)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('UGA', 'KEN', 'Mombasa', 'Corridor Northern (Mombasa-Nairobi-Kampala)',
     'REGIONAL', 0.75, 2010, NULL,
     'Accord EAC (East African Community). '
     'Standard Gauge Railway Mombasa-Nairobi opérationnel (2017). '
     'Extension Nairobi-Kampala planifiée.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Rwanda → Kenya (port de Mombasa)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('RWA', 'KEN', 'Mombasa', 'Corridor Central (Mombasa-Nairobi-Kigali)',
     'REGIONAL', 0.75, 2010, NULL,
     'Accord EAC. Rwanda utilise aussi le port de Dar es Salaam (TZA) '
     'via le corridor Central.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Rwanda → Tanzanie (port de Dar es Salaam)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('RWA', 'TZA', 'Dar es Salaam', 'Corridor Central (TZA-RWA)',
     'REGIONAL', 0.70, 2010, NULL,
     'Accord EAC. Deuxième voie d''accès maritime pour le Rwanda.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Burundi → Tanzanie (port de Dar es Salaam)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('BDI', 'TZA', 'Dar es Salaam', 'Corridor Central (TZA-BDI)',
     'REGIONAL', 0.70, 2010, NULL,
     'Accord EAC. Principal accès maritime du Burundi.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Soudan du Sud → Kenya (port de Mombasa)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('SSD', 'KEN', 'Mombasa', 'Corridor Mombasa-Juba',
     'BILATERAL', 0.60, 2011, NULL,
     'Accord depuis indépendance SSD (2011). '
     'Confiance réduite — instabilité chronique au Soudan du Sud.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Soudan du Sud → Soudan (port de Port Sudan)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('SSD', 'SDN', 'Port Sudan', 'Pipeline pétrolier SSD-SDN',
     'BILATERAL', 0.55, 2011, NULL,
     'Accord pétrolier SSD-SDN (exportations pétrole via pipeline). '
     'Relations très tendues. Accès perturbé régulièrement. '
     'Confiance très réduite.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- ── 7. Données — Afrique Australe ────────────────────────

-- Zambie → Mozambique (port de Beira)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('ZMB', 'MOZ', 'Beira', 'Corridor de Beira (SADC)',
     'REGIONAL', 0.75, 2010, NULL,
     'Accord SADC. Corridor Beira = artère vitale Afrique australe enclavée.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Zambie → Tanzanie (port de Dar es Salaam)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('ZMB', 'TZA', 'Dar es Salaam', 'Corridor TAZARA (Tanzanie-Zambie)',
     'REGIONAL', 0.70, 2010, NULL,
     'Accord SADC + ligne ferroviaire TAZARA (1975). '
     'Infrastructure vieillissante mais toujours opérationnelle.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Zambie → Afrique du Sud (port de Durban)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('ZMB', 'ZAF', 'Durban', 'Corridor Nord-Sud (SADC)',
     'REGIONAL', 0.70, 2010, NULL,
     'Accord SADC. Corridor Nord-Sud = Cape Town/Durban → Zimbabwe → Zambie.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Zimbabwe → Mozambique (port de Beira)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('ZWE', 'MOZ', 'Beira', 'Corridor de Beira (Zimbabwe)',
     'REGIONAL', 0.75, 2010, NULL,
     'Accord SADC. Port de Beira = accès maritime principal Zimbabwe.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Zimbabwe → Afrique du Sud (port de Durban)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, valid_from, valid_to,
     corridor_name, agreement_type, confidence, notes)
VALUES
    ('ZWE', 'ZAF', 'Durban', 2010, NULL,
     'Corridor Nord-Sud (SADC)',
     'REGIONAL', 0.70,
     'Accès via Beit Bridge. Deuxième voie d''accès Zimbabwe.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Malawi → Mozambique (port de Beira)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('MWI', 'MOZ', 'Beira', 'Corridor Beira-Malawi',
     'REGIONAL', 0.75, 2010, NULL,
     'Accord SADC. Beira = accès principal Malawi.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Malawi → Mozambique (port de Nacala)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('MWI', 'MOZ', 'Nacala', 'Corridor Nacala (Malawi-Mozambique)',
     'BILATERAL', 0.75, 2010, NULL,
     'Accord bilatéral Malawi-Mozambique. Corridor Nacala = '
     'voie ferrée Nacala-Lilongwe (réhabilitée 2015).')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Botswana → Afrique du Sud (port de Durban)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('BWA', 'ZAF', 'Durban', 'Corridor SADC Botswana-ZAF',
     'REGIONAL', 0.75, 2010, NULL,
     'Accord SADC. Durban = accès maritime principal Botswana.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Lesotho → Afrique du Sud (port de Durban)
-- Lesotho est entièrement enclavé dans l'Afrique du Sud
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('LSO', 'ZAF', 'Durban', 'Corridor Lesotho-ZAF (SACU)',
     'REGIONAL', 0.80, 2010, NULL,
     'SACU (Southern African Customs Union). '
     'Lesotho = enclavé dans ZAF. Accès garanti par traité SACU. '
     'Confiance élevée — union douanière formelle.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- Eswatini → Mozambique (port de Maputo) + ZAF (Durban)
INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('SWZ', 'MOZ', 'Maputo', 'Corridor Eswatini-Maputo',
     'BILATERAL', 0.75, 2010, NULL,
     'Accord bilatéral Eswatini-Mozambique. Maputo = port le plus proche.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

INSERT INTO rf.port_agreements
    (landlocked_iso3, coastal_iso3, port_name, corridor_name,
     agreement_type, confidence, valid_from, valid_to, notes)
VALUES
    ('SWZ', 'ZAF', 'Durban', 'Corridor Eswatini-Durban (SACU)',
     'REGIONAL', 0.75, 2010, NULL,
     'SACU. Accès alternatif via Afrique du Sud.')
ON CONFLICT (landlocked_iso3, coastal_iso3, port_name, valid_from) DO NOTHING;

-- ── 8. Vérifications finales ──────────────────────────────
DO $$
DECLARE
    v_total      INT;
    v_actifs     INT;
    v_landlocked INT;
    v_bilat      INT;
    v_regional   INT;
    v_defacto    INT;
BEGIN
    SELECT COUNT(*)  INTO v_total      FROM rf.port_agreements;
    SELECT COUNT(*)  INTO v_actifs     FROM rf.port_agreements WHERE valid_to IS NULL;
    SELECT COUNT(DISTINCT landlocked_iso3) INTO v_landlocked FROM rf.port_agreements;
    SELECT COUNT(*)  INTO v_bilat      FROM rf.port_agreements WHERE agreement_type = 'BILATERAL';
    SELECT COUNT(*)  INTO v_regional   FROM rf.port_agreements WHERE agreement_type = 'REGIONAL';
    SELECT COUNT(*)  INTO v_defacto    FROM rf.port_agreements WHERE agreement_type = 'DEFACTO';

    RAISE NOTICE 'PATCH PORT_AGREEMENTS ——————————————————————————';
    RAISE NOTICE '  Accords total           : %', v_total;
    RAISE NOTICE '  Accords actifs          : %', v_actifs;
    RAISE NOTICE '  Pays enclavés couverts  : % / 15', v_landlocked;
    RAISE NOTICE '  BILATERAL               : %', v_bilat;
    RAISE NOTICE '  REGIONAL                : %', v_regional;
    RAISE NOTICE '  DEFACTO                 : %', v_defacto;

    IF v_total < 20 THEN
        RAISE EXCEPTION 'PATCH PORT_AGREEMENTS échoué — accords insuffisants : %', v_total;
    END IF;
    IF v_landlocked < 14 THEN
        RAISE EXCEPTION 'PATCH PORT_AGREEMENTS échoué — pays couverts : % (attendu >= 14)', v_landlocked;
    END IF;

    RAISE NOTICE 'PATCH PORT_AGREEMENTS OK';
END;
$$;

COMMIT;
