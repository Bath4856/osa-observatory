-- ============================================================
-- OSA / ISA OBSERVATORY
-- PATCH : rf.monetary_zone_history
-- Date   : 2026-03-31
-- Sprint : 3.5 — Gouvernance des zones monétaires africaines
--
-- Objectif :
--   Tracer l'évolution historique et future des appartenances
--   monétaires des 54 pays africains. Permet au pipeline ISA
--   de calculer le bon coefficient de souveraineté monétaire
--   pour chaque année, même si la situation institutionnelle
--   a changé entre-temps.
--
-- Cas d'usage prévu :
--   - Création d'une monnaie AES (Mali, Niger, Burkina Faso)
--   - Adhésion/retrait d'un pays à une zone monétaire
--   - Révision du coefficient de souveraineté
--   - Changement de banque centrale régionale
-- ============================================================

BEGIN;

-- Extension nécessaire pour les contraintes de dates
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ============================================================
-- 1. TABLE rf.monetary_zone_history
--    Historique des appartenances monétaires par pays
-- ============================================================

CREATE TABLE IF NOT EXISTS rf.monetary_zone_history (

    -- Identifiants
    id                  SERIAL        PRIMARY KEY,
    country_iso3        VARCHAR(3)    NOT NULL
                        REFERENCES rf.countries(iso3)
                        ON DELETE CASCADE,

    -- Classification monétaire
    central_bank_type   VARCHAR(20)   NOT NULL
                        CHECK (central_bank_type IN (
                            'NATIONAL',  -- banque centrale nationale
                            'UEMOA',     -- zone CFA Ouest (BCEAO)
                            'CEMAC',     -- zone CFA Centre (BEAC)
                            'AES',       -- Alliance des États du Sahel (future)
                            'EAC_MU',   -- Union monétaire EAC (future)
                            'OTHER'      -- autre zone monétaire
                        )),
    central_bank_code   VARCHAR(10)   NOT NULL,
    central_bank_name   VARCHAR(100)  NULL,
    currency_code       VARCHAR(5)    NULL,
    currency_name       VARCHAR(50)   NULL,

    -- Coefficient de souveraineté monétaire
    sovereignty_weight  NUMERIC(4,3)  NOT NULL DEFAULT 1.000
                        CHECK (sovereignty_weight BETWEEN 0.0 AND 1.0),

    -- Validité temporelle
    valid_from          DATE          NOT NULL,
    valid_to            DATE          NULL,  -- NULL = encore en vigueur
    is_current          BOOLEAN       GENERATED ALWAYS AS
                        (valid_to IS NULL) STORED,

    -- Source et traçabilité
    source_reference    TEXT          NULL,  -- traité, décision officielle
    source_date         DATE          NULL,  -- date de la décision officielle
    notes               TEXT          NULL,

    -- Audit
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(50)   NOT NULL DEFAULT 'OSA_SYSTEM',

    -- Contrainte d'unicité : un seul enregistrement actif par pays
    CONSTRAINT uq_current_per_country UNIQUE (country_iso3, valid_from)
);

COMMENT ON TABLE rf.monetary_zone_history IS
    'Historique complet des appartenances monétaires des pays africains. '
    'Utilisé par le pipeline ISA pour calculer le coefficient de souveraineté '
    'monétaire correct pour chaque année de calcul. '
    'Immuable — ne jamais modifier les entrées passées, uniquement ajouter.';

COMMENT ON COLUMN rf.monetary_zone_history.sovereignty_weight IS
    'Coefficient de souveraineté monétaire (0.0 → 1.0) :
     1.000 — banque centrale nationale (pleine souveraineté)
     0.700 — zone CFA actuelle (UEMOA/CEMAC)
     0.850 — zone AES future (souveraineté partielle avec banque commune)
     Ajusté lors de chaque changement institutionnel.';

COMMENT ON COLUMN rf.monetary_zone_history.valid_to IS
    'Date de fin de validité (exclusive). NULL = entrée encore en vigueur. '
    'Ne jamais modifier une entrée passée — créer une nouvelle entrée.';

COMMENT ON COLUMN rf.monetary_zone_history.is_current IS
    'Colonne calculée automatiquement. TRUE si valid_to IS NULL.';

-- Index
CREATE INDEX IF NOT EXISTS idx_mzh_country
    ON rf.monetary_zone_history (country_iso3);
CREATE INDEX IF NOT EXISTS idx_mzh_current
    ON rf.monetary_zone_history (country_iso3, valid_from)
    WHERE is_current;
CREATE INDEX IF NOT EXISTS idx_mzh_type
    ON rf.monetary_zone_history (central_bank_type, valid_from);



-- ============================================================
-- 3. Peuplement initial — état au 1er janvier 2010
--    (début de la période de collecte OSA)
-- ============================================================

-- Zone UEMOA — BCEAO (8 pays)
INSERT INTO rf.monetary_zone_history
    (country_iso3, central_bank_type, central_bank_code, central_bank_name,
     currency_code, currency_name, sovereignty_weight,
     valid_from, valid_to, source_reference, notes)
VALUES
    ('BEN', 'UEMOA', 'BCEAO', 'Banque Centrale des États de l''Afrique de l''Ouest',
     'XOF', 'Franc CFA ouest-africain', 0.700,
     '2010-01-01', NULL,
     'Traité UEMOA 1994 — Protocole additionnel III',
     'Membre fondateur UEMOA. Réserves mutualisées à la BCEAO.'),
    ('BFA', 'UEMOA', 'BCEAO', 'Banque Centrale des États de l''Afrique de l''Ouest',
     'XOF', 'Franc CFA ouest-africain', 0.700,
     '2010-01-01', NULL,
     'Traité UEMOA 1994',
     'Membre fondateur UEMOA. Participation suspendue au G5 Sahel (2022).'),
    ('CIV', 'UEMOA', 'BCEAO', 'Banque Centrale des États de l''Afrique de l''Ouest',
     'XOF', 'Franc CFA ouest-africain', 0.700,
     '2010-01-01', NULL,
     'Traité UEMOA 1994',
     'Membre fondateur UEMOA. Principale économie de la zone.'),
    ('GNB', 'UEMOA', 'BCEAO', 'Banque Centrale des États de l''Afrique de l''Ouest',
     'XOF', 'Franc CFA ouest-africain', 0.700,
     '2010-01-01', NULL,
     'Adhésion UEMOA 1997',
     'A rejoint l''UEMOA en 1997. Ancienne monnaie : Peso.'),
    ('MLI', 'UEMOA', 'BCEAO', 'Banque Centrale des États de l''Afrique de l''Ouest',
     'XOF', 'Franc CFA ouest-africain', 0.700,
     '2010-01-01', NULL,
     'Traité UEMOA 1994',
     'Membre fondateur UEMOA. Co-fondateur AES (juillet 2023) — monnaie AES en projet.'),
    ('NER', 'UEMOA', 'BCEAO', 'Banque Centrale des États de l''Afrique de l''Ouest',
     'XOF', 'Franc CFA ouest-africain', 0.700,
     '2010-01-01', NULL,
     'Traité UEMOA 1994',
     'Membre fondateur UEMOA. Co-fondateur AES (juillet 2023) — monnaie AES en projet.'),
    ('SEN', 'UEMOA', 'BCEAO', 'Banque Centrale des États de l''Afrique de l''Ouest',
     'XOF', 'Franc CFA ouest-africain', 0.700,
     '2010-01-01', NULL,
     'Traité UEMOA 1994',
     'Membre fondateur UEMOA.'),
    ('TGO', 'UEMOA', 'BCEAO', 'Banque Centrale des États de l''Afrique de l''Ouest',
     'XOF', 'Franc CFA ouest-africain', 0.700,
     '2010-01-01', NULL,
     'Traité UEMOA 1994',
     'Membre fondateur UEMOA.')
ON CONFLICT (country_iso3, valid_from) DO NOTHING;

-- Zone CEMAC — BEAC (6 pays)
INSERT INTO rf.monetary_zone_history
    (country_iso3, central_bank_type, central_bank_code, central_bank_name,
     currency_code, currency_name, sovereignty_weight,
     valid_from, valid_to, source_reference, notes)
VALUES
    ('CMR', 'CEMAC', 'BEAC', 'Banque des États de l''Afrique Centrale',
     'XAF', 'Franc CFA d''Afrique centrale', 0.700,
     '2010-01-01', NULL,
     'Traité CEMAC 1994',
     'Membre fondateur CEMAC. Principale économie de la zone.'),
    ('CAF', 'CEMAC', 'BEAC', 'Banque des États de l''Afrique Centrale',
     'XAF', 'Franc CFA d''Afrique centrale', 0.700,
     '2010-01-01', NULL,
     'Traité CEMAC 1994',
     'Membre fondateur CEMAC.'),
    ('TCD', 'CEMAC', 'BEAC', 'Banque des États de l''Afrique Centrale',
     'XAF', 'Franc CFA d''Afrique centrale', 0.700,
     '2010-01-01', NULL,
     'Traité CEMAC 1994',
     'Membre fondateur CEMAC. Membre G5 Sahel (actif).'),
    ('COG', 'CEMAC', 'BEAC', 'Banque des États de l''Afrique Centrale',
     'XAF', 'Franc CFA d''Afrique centrale', 0.700,
     '2010-01-01', NULL,
     'Traité CEMAC 1994',
     'Membre fondateur CEMAC.'),
    ('GNQ', 'CEMAC', 'BEAC', 'Banque des États de l''Afrique Centrale',
     'XAF', 'Franc CFA d''Afrique centrale', 0.700,
     '2010-01-01', NULL,
     'Adhésion CEMAC 1999',
     'A rejoint la CEMAC en 1999. Économie pétrolière.'),
    ('GAB', 'CEMAC', 'BEAC', 'Banque des États de l''Afrique Centrale',
     'XAF', 'Franc CFA d''Afrique centrale', 0.700,
     '2010-01-01', NULL,
     'Traité CEMAC 1994',
     'Membre fondateur CEMAC.')
ON CONFLICT (country_iso3, valid_from) DO NOTHING;

-- Pays à banque centrale nationale (40 pays)
-- Insertion groupée avec les principales banques centrales
INSERT INTO rf.monetary_zone_history
    (country_iso3, central_bank_type, central_bank_code, central_bank_name,
     currency_code, currency_name, sovereignty_weight,
     valid_from, valid_to)
VALUES
    ('DZA','NATIONAL','BA',   'Banque d''Algérie',                          'DZD','Dinar algérien',        1.000,'2010-01-01',NULL),
    ('EGY','NATIONAL','CBE',  'Central Bank of Egypt',                      'EGP','Livre égyptienne',       1.000,'2010-01-01',NULL),
    ('LBY','NATIONAL','CBL',  'Central Bank of Libya',                      'LYD','Dinar libyen',           1.000,'2010-01-01',NULL),
    ('MAR','NATIONAL','BCM',  'Bank Al-Maghrib',                            'MAD','Dirham marocain',        1.000,'2010-01-01',NULL),
    ('MRT','NATIONAL','BCM',  'Banque Centrale de Mauritanie',              'MRU','Ouguiya mauritanien',    1.000,'2010-01-01',NULL),
    ('SDN','NATIONAL','CBOS', 'Central Bank of Sudan',                      'SDG','Livre soudanaise',       1.000,'2010-01-01',NULL),
    ('TUN','NATIONAL','BCT',  'Banque Centrale de Tunisie',                 'TND','Dinar tunisien',         1.000,'2010-01-01',NULL),
    ('CPV','NATIONAL','BCV',  'Banco de Cabo Verde',                        'CVE','Escudo cap-verdien',     1.000,'2010-01-01',NULL),
    ('GMB','NATIONAL','CBG',  'Central Bank of The Gambia',                 'GMD','Dalasi gambien',         1.000,'2010-01-01',NULL),
    ('GHA','NATIONAL','BOG',  'Bank of Ghana',                              'GHS','Cedi ghanéen',           1.000,'2010-01-01',NULL),
    ('GIN','NATIONAL','BCRG', 'Banque Centrale de la République de Guinée', 'GNF','Franc guinéen',          1.000,'2010-01-01',NULL),
    ('LBR','NATIONAL','CBL',  'Central Bank of Liberia',                    'LRD','Dollar libérien',        1.000,'2010-01-01',NULL),
    ('NGA','NATIONAL','CBN',  'Central Bank of Nigeria',                    'NGN','Naira nigérian',         1.000,'2010-01-01',NULL),
    ('SLE','NATIONAL','BSL',  'Bank of Sierra Leone',                       'SLL','Leone sierra-léonais',   1.000,'2010-01-01',NULL),
    ('BDI','NATIONAL','BRB',  'Banque de la République du Burundi',         'BIF','Franc burundais',        1.000,'2010-01-01',NULL),
    ('COM','NATIONAL','BCC',  'Banque Centrale des Comores',                'KMF','Franc comorien',         1.000,'2010-01-01',NULL),
    ('DJI','NATIONAL','BCD',  'Banque Centrale de Djibouti',                'DJF','Franc djiboutien',       1.000,'2010-01-01',NULL),
    ('ERI','NATIONAL','NBE',  'National Bank of Eritrea',                   'ERN','Nakfa érythréen',        1.000,'2010-01-01',NULL),
    ('ETH','NATIONAL','NBE',  'National Bank of Ethiopia',                  'ETB','Birr éthiopien',         1.000,'2010-01-01',NULL),
    ('KEN','NATIONAL','CBK',  'Central Bank of Kenya',                      'KES','Shilling kényan',        1.000,'2010-01-01',NULL),
    ('MDG','NATIONAL','BCM',  'Banque Centrale de Madagascar',              'MGA','Ariary malgache',        1.000,'2010-01-01',NULL),
    ('MWI','NATIONAL','RBM',  'Reserve Bank of Malawi',                     'MWK','Kwacha malawite',        1.000,'2010-01-01',NULL),
    ('MUS','NATIONAL','BOM',  'Bank of Mauritius',                          'MUR','Roupie mauricienne',     1.000,'2010-01-01',NULL),
    ('MOZ','NATIONAL','BM',   'Banco de Moçambique',                        'MZN','Metical mozambicain',    1.000,'2010-01-01',NULL),
    ('RWA','NATIONAL','BNR',  'National Bank of Rwanda',                    'RWF','Franc rwandais',         1.000,'2010-01-01',NULL),
    ('SYC','NATIONAL','CBS',  'Central Bank of Seychelles',                 'SCR','Roupie seychelloise',    1.000,'2010-01-01',NULL),
    ('SOM','NATIONAL','CBS',  'Central Bank of Somalia',                    'SOS','Shilling somalien',      1.000,'2010-01-01',NULL),
    ('SSD','NATIONAL','BOSS', 'Bank of South Sudan',                        'SSP','Livre sud-soudanaise',   1.000,'2010-01-01',NULL),
    ('TZA','NATIONAL','BOT',  'Bank of Tanzania',                           'TZS','Shilling tanzanien',     1.000,'2010-01-01',NULL),
    ('UGA','NATIONAL','BOU',  'Bank of Uganda',                             'UGX','Shilling ougandais',     1.000,'2010-01-01',NULL),
    ('ZMB','NATIONAL','BOZ',  'Bank of Zambia',                             'ZMW','Kwacha zambien',         1.000,'2010-01-01',NULL),
    ('ZWE','NATIONAL','RBZ',  'Reserve Bank of Zimbabwe',                   'ZWL','Dollar zimbabwéen',      1.000,'2010-01-01',NULL),
    ('AGO','NATIONAL','BNA',  'Banco Nacional de Angola',                   'AOA','Kwanza angolais',        1.000,'2010-01-01',NULL),
    ('COD','NATIONAL','BCC',  'Banque Centrale du Congo',                   'CDF','Franc congolais',        1.000,'2010-01-01',NULL),
    ('STP','NATIONAL','BCSTP','Banco Central de São Tomé e Príncipe',       'STN','Dobra santoméen',        1.000,'2010-01-01',NULL),
    ('BWA','NATIONAL','BOB',  'Bank of Botswana',                           'BWP','Pula botswanaise',       1.000,'2010-01-01',NULL),
    ('SWZ','NATIONAL','CBS',  'Central Bank of Eswatini',                   'SZL','Lilangeni swazi',        1.000,'2010-01-01',NULL),
    ('LSO','NATIONAL','CBL',  'Central Bank of Lesotho',                    'LSL','Loti lesothan',          1.000,'2010-01-01',NULL),
    ('NAM','NATIONAL','BON',  'Bank of Namibia',                            'NAD','Dollar namibien',        1.000,'2010-01-01',NULL),
    ('ZAF','NATIONAL','SARB', 'South African Reserve Bank',                 'ZAR','Rand sud-africain',      1.000,'2010-01-01',NULL)
ON CONFLICT (country_iso3, valid_from) DO NOTHING;

-- ============================================================
-- 4. VUE rf.monetary_zone_at(date)
--    Retourne l'état monétaire valide à une date donnée
-- ============================================================

CREATE OR REPLACE FUNCTION rf.monetary_zone_at(p_date DATE)
RETURNS TABLE (
    country_iso3        VARCHAR(3),
    country_name        VARCHAR(100),
    central_bank_type   VARCHAR(20),
    central_bank_code   VARCHAR(10),
    central_bank_name   VARCHAR(100),
    currency_code       VARCHAR(5),
    sovereignty_weight  NUMERIC(4,3)
) AS $$
    SELECT
        c.iso3,
        c.name_fr,
        h.central_bank_type,
        h.central_bank_code,
        h.central_bank_name,
        h.currency_code,
        h.sovereignty_weight
    FROM rf.monetary_zone_history h
    JOIN rf.countries c ON c.iso3 = h.country_iso3
    WHERE h.valid_from <= p_date
    AND (h.valid_to IS NULL OR h.valid_to > p_date)
    ORDER BY h.central_bank_type, c.name_fr;
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION rf.monetary_zone_at IS
    'Retourne l''état monétaire de tous les pays africains à une date donnée. '
    'Utilisé par le pipeline ISA pour calculer le coefficient correct par année. '
    'Exemple : SELECT * FROM rf.monetary_zone_at(''2024-01-01'');';

-- ============================================================
-- 5. VUE rf.monetary_zone_current
--    État monétaire actuel (raccourci pratique)
-- ============================================================

CREATE OR REPLACE VIEW rf.monetary_zone_current AS
SELECT * FROM rf.monetary_zone_at(CURRENT_DATE);

COMMENT ON VIEW rf.monetary_zone_current IS
    'État monétaire actuel de tous les pays africains. '
    'Raccourci vers rf.monetary_zone_at(CURRENT_DATE).';

-- ============================================================
-- 6. Vérifications post-patch
-- ============================================================

DO $$
DECLARE
    v_total     INT;
    v_national  INT;
    v_uemoa     INT;
    v_cemac     INT;
    v_current   INT;
BEGIN
    SELECT COUNT(*) INTO v_total    FROM rf.monetary_zone_history;
    SELECT COUNT(*) INTO v_national FROM rf.monetary_zone_history WHERE central_bank_type = 'NATIONAL';
    SELECT COUNT(*) INTO v_uemoa    FROM rf.monetary_zone_history WHERE central_bank_type = 'UEMOA';
    SELECT COUNT(*) INTO v_cemac    FROM rf.monetary_zone_history WHERE central_bank_type = 'CEMAC';
    SELECT COUNT(*) INTO v_current  FROM rf.monetary_zone_history WHERE is_current;

    IF v_total <> 54 THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : % entrées (attendu 54)', v_total;
    END IF;
    IF v_current <> 54 THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : % entrées actives (attendu 54)', v_current;
    END IF;

    RAISE NOTICE 'PATCH OK —';
    RAISE NOTICE '  Entrées totales       : %', v_total;
    RAISE NOTICE '  Entrées actives       : %', v_current;
    RAISE NOTICE '  NATIONAL              : % pays', v_national;
    RAISE NOTICE '  UEMOA (BCEAO)         : % pays', v_uemoa;
    RAISE NOTICE '  CEMAC (BEAC)          : % pays', v_cemac;
    RAISE NOTICE '';
    RAISE NOTICE 'Fonctions disponibles :';
    RAISE NOTICE '  SELECT * FROM rf.monetary_zone_at(''2024-01-01'');';
    RAISE NOTICE '  SELECT * FROM rf.monetary_zone_current;';
END;
$$;

COMMIT;
