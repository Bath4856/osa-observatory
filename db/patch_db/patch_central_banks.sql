-- ============================================================
-- OSA / ISA OBSERVATORY
-- PATCH : Classification banques centrales africaines
-- Date   : 2026-03-31
-- Sprint : 3.5 — Souveraineté monétaire différenciée
--
-- Contexte :
--   En Afrique, tous les pays n'ont pas de banque centrale nationale.
--   Deux zones monétaires CFA utilisent des banques centrales régionales :
--   - BCEAO (UEMOA) : 8 pays d'Afrique de l'Ouest
--   - BEAC (CEMAC)  : 6 pays d'Afrique Centrale
--   Cette distinction est fondamentale pour mesurer la souveraineté
--   monétaire réelle de chaque pays.
--
-- Impact sur MON_RES :
--   - Pays banque nationale : FI.RES.TOTL.MO (réserves propres)
--   - Pays UEMOA/CEMAC     : BN.CAB.XOKA.GD.ZS (balance courante)
--                            + coefficient de pondération réduit (0.7)
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Ajout colonnes dans rf.countries
-- ============================================================

ALTER TABLE rf.countries
    ADD COLUMN IF NOT EXISTS central_bank_type VARCHAR(20)
        NOT NULL DEFAULT 'NATIONAL'
        CHECK (central_bank_type IN ('NATIONAL', 'UEMOA', 'CEMAC')),
    ADD COLUMN IF NOT EXISTS central_bank_code VARCHAR(10)
        NOT NULL DEFAULT 'NAT',
    ADD COLUMN IF NOT EXISTS currency_code     VARCHAR(5)
        NULL,
    ADD COLUMN IF NOT EXISTS monetary_sovereignty_weight NUMERIC(4,3)
        NOT NULL DEFAULT 1.000
        CHECK (monetary_sovereignty_weight BETWEEN 0.0 AND 1.0);

COMMENT ON COLUMN rf.countries.central_bank_type IS
    'Type de banque centrale :
     NATIONAL — banque centrale nationale propre
     UEMOA    — membre de la zone CFA Ouest (BCEAO)
     CEMAC    — membre de la zone CFA Centre (BEAC)';

COMMENT ON COLUMN rf.countries.central_bank_code IS
    'Code de la banque centrale : NAT (nationale), BCEAO, BEAC';

COMMENT ON COLUMN rf.countries.currency_code IS
    'Code ISO 4217 de la monnaie nationale ou régionale';

COMMENT ON COLUMN rf.countries.monetary_sovereignty_weight IS
    'Coefficient de souveraineté monétaire (0.0 → 1.0) :
     1.000 — banque centrale nationale (pleine souveraineté)
     0.700 — zone CFA (souveraineté partielle — banque régionale)
     Utilisé pour pondérer MON_RES dans le pipeline ISA.';

-- ============================================================
-- 2. Désactiver temporairement le trigger anti-mutation
-- ============================================================

ALTER TABLE rf.countries DISABLE TRIGGER USER;

-- ============================================================
-- 3. Classification UEMOA (BCEAO) — 8 pays
--    Monnaie : Franc CFA ouest-africain (XOF)
-- ============================================================

UPDATE rf.countries SET
    central_bank_type             = 'UEMOA',
    central_bank_code             = 'BCEAO',
    currency_code                 = 'XOF',
    monetary_sovereignty_weight   = 0.700
WHERE iso3 IN (
    'BEN',  -- Bénin
    'BFA',  -- Burkina Faso
    'CIV',  -- Côte d'Ivoire
    'GNB',  -- Guinée-Bissau
    'MLI',  -- Mali
    'NER',  -- Niger
    'SEN',  -- Sénégal
    'TGO'   -- Togo
);

-- ============================================================
-- 4. Classification CEMAC (BEAC) — 6 pays
--    Monnaie : Franc CFA d'Afrique centrale (XAF)
-- ============================================================

UPDATE rf.countries SET
    central_bank_type             = 'CEMAC',
    central_bank_code             = 'BEAC',
    currency_code                 = 'XAF',
    monetary_sovereignty_weight   = 0.700
WHERE iso3 IN (
    'CMR',  -- Cameroun
    'CAF',  -- République centrafricaine
    'TCD',  -- Tchad
    'COG',  -- Congo
    'GNQ',  -- Guinée équatoriale
    'GAB'   -- Gabon
);

-- ============================================================
-- 5. Monnaies des pays à banque centrale nationale
--    (mise à jour partielle des devises principales)
-- ============================================================

UPDATE rf.countries SET currency_code = 'DZD' WHERE iso3 = 'DZA';  -- Dinar algérien
UPDATE rf.countries SET currency_code = 'EGP' WHERE iso3 = 'EGY';  -- Livre égyptienne
UPDATE rf.countries SET currency_code = 'LYD' WHERE iso3 = 'LBY';  -- Dinar libyen
UPDATE rf.countries SET currency_code = 'MAD' WHERE iso3 = 'MAR';  -- Dirham marocain
UPDATE rf.countries SET currency_code = 'MRU' WHERE iso3 = 'MRT';  -- Ouguiya mauritanien
UPDATE rf.countries SET currency_code = 'SDG' WHERE iso3 = 'SDN';  -- Livre soudanaise
UPDATE rf.countries SET currency_code = 'TND' WHERE iso3 = 'TUN';  -- Dinar tunisien
UPDATE rf.countries SET currency_code = 'NGN' WHERE iso3 = 'NGA';  -- Naira nigérian
UPDATE rf.countries SET currency_code = 'GHS' WHERE iso3 = 'GHA';  -- Cedi ghanéen
UPDATE rf.countries SET currency_code = 'KES' WHERE iso3 = 'KEN';  -- Shilling kényan
UPDATE rf.countries SET currency_code = 'ETB' WHERE iso3 = 'ETH';  -- Birr éthiopien
UPDATE rf.countries SET currency_code = 'ZAR' WHERE iso3 = 'ZAF';  -- Rand sud-africain
UPDATE rf.countries SET currency_code = 'TZS' WHERE iso3 = 'TZA';  -- Shilling tanzanien
UPDATE rf.countries SET currency_code = 'UGX' WHERE iso3 = 'UGA';  -- Shilling ougandais
UPDATE rf.countries SET currency_code = 'RWF' WHERE iso3 = 'RWA';  -- Franc rwandais
UPDATE rf.countries SET currency_code = 'ZMW' WHERE iso3 = 'ZMB';  -- Kwacha zambien
UPDATE rf.countries SET currency_code = 'ZWL' WHERE iso3 = 'ZWE';  -- Dollar zimbabwéen
UPDATE rf.countries SET currency_code = 'AOA' WHERE iso3 = 'AGO';  -- Kwanza angolais
UPDATE rf.countries SET currency_code = 'MZN' WHERE iso3 = 'MOZ';  -- Metical mozambicain
UPDATE rf.countries SET currency_code = 'MWK' WHERE iso3 = 'MWI';  -- Kwacha malawite
UPDATE rf.countries SET currency_code = 'NAD' WHERE iso3 = 'NAM';  -- Dollar namibien
UPDATE rf.countries SET currency_code = 'BWP' WHERE iso3 = 'BWA';  -- Pula botswanaise
UPDATE rf.countries SET currency_code = 'SZL' WHERE iso3 = 'SWZ';  -- Lilangeni swazi
UPDATE rf.countries SET currency_code = 'LSL' WHERE iso3 = 'LSO';  -- Loti lesothan
UPDATE rf.countries SET currency_code = 'MGA' WHERE iso3 = 'MDG';  -- Ariary malgache
UPDATE rf.countries SET currency_code = 'MUR' WHERE iso3 = 'MUS';  -- Roupie mauricienne
UPDATE rf.countries SET currency_code = 'SCR' WHERE iso3 = 'SYC';  -- Roupie seychelloise
UPDATE rf.countries SET currency_code = 'KMF' WHERE iso3 = 'COM';  -- Franc comorien
UPDATE rf.countries SET currency_code = 'DJF' WHERE iso3 = 'DJI';  -- Franc djiboutien
UPDATE rf.countries SET currency_code = 'ERN' WHERE iso3 = 'ERI';  -- Nakfa érythréen
UPDATE rf.countries SET currency_code = 'SOS' WHERE iso3 = 'SOM';  -- Shilling somalien
UPDATE rf.countries SET currency_code = 'SSP' WHERE iso3 = 'SSD';  -- Livre sud-soudanaise
UPDATE rf.countries SET currency_code = 'SDG' WHERE iso3 = 'SDN';  -- Livre soudanaise
UPDATE rf.countries SET currency_code = 'GMD' WHERE iso3 = 'GMB';  -- Dalasi gambien
UPDATE rf.countries SET currency_code = 'GNF' WHERE iso3 = 'GIN';  -- Franc guinéen
UPDATE rf.countries SET currency_code = 'SLL' WHERE iso3 = 'SLE';  -- Leone sierra-léonais
UPDATE rf.countries SET currency_code = 'LRD' WHERE iso3 = 'LBR';  -- Dollar libérien
UPDATE rf.countries SET currency_code = 'CVE' WHERE iso3 = 'CPV';  -- Escudo cap-verdien
UPDATE rf.countries SET currency_code = 'STN' WHERE iso3 = 'STP';  -- Dobra santoméen
UPDATE rf.countries SET currency_code = 'CDF' WHERE iso3 = 'COD';  -- Franc congolais
UPDATE rf.countries SET currency_code = 'BIF' WHERE iso3 = 'BDI';  -- Franc burundais
UPDATE rf.countries SET currency_code = 'UGX' WHERE iso3 = 'UGA';  -- Shilling ougandais

-- ============================================================
-- 6. Réactiver le trigger
-- ============================================================

ALTER TABLE rf.countries ENABLE TRIGGER USER;

-- ============================================================
-- 7. Vue de synthèse par type de banque centrale
-- ============================================================

CREATE OR REPLACE VIEW rf.countries_monetary AS
SELECT
    c.iso3,
    c.iso2,
    c.name_fr,
    c.region_code,
    c.central_bank_type,
    c.central_bank_code,
    c.currency_code,
    c.monetary_sovereignty_weight,
    CASE c.central_bank_type
        WHEN 'NATIONAL' THEN 'Banque centrale nationale'
        WHEN 'UEMOA'    THEN 'BCEAO — Zone CFA Ouest'
        WHEN 'CEMAC'    THEN 'BEAC — Zone CFA Centre'
    END AS banque_centrale_label,
    CASE c.central_bank_type
        WHEN 'NATIONAL' THEN 'FI.RES.TOTL.MO'
        ELSE                 'BN.CAB.XOKA.GD.ZS'
    END AS wb_indicator_mon_res
FROM rf.countries c
ORDER BY c.central_bank_type, c.region_code, c.name_fr;

COMMENT ON VIEW rf.countries_monetary IS
    'Classification monétaire des 54 pays africains. '
    'Indique le type de banque centrale et le code WB à utiliser pour MON_RES.';

-- ============================================================
-- 8. Vérifications post-patch
-- ============================================================

DO $$
DECLARE
    v_national  INT;
    v_uemoa     INT;
    v_cemac     INT;
    v_total     INT;
BEGIN
    SELECT COUNT(*) INTO v_national FROM rf.countries WHERE central_bank_type = 'NATIONAL';
    SELECT COUNT(*) INTO v_uemoa    FROM rf.countries WHERE central_bank_type = 'UEMOA';
    SELECT COUNT(*) INTO v_cemac    FROM rf.countries WHERE central_bank_type = 'CEMAC';
    SELECT COUNT(*) INTO v_total    FROM rf.countries;

    IF v_uemoa <> 8 THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : UEMOA = % pays (attendu 8)', v_uemoa;
    END IF;
    IF v_cemac <> 6 THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : CEMAC = % pays (attendu 6)', v_cemac;
    END IF;
    IF v_national + v_uemoa + v_cemac <> v_total THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : total incohérent';
    END IF;

    RAISE NOTICE 'PATCH OK —';
    RAISE NOTICE '  Banques centrales nationales : % pays', v_national;
    RAISE NOTICE '  Zone UEMOA (BCEAO)           : % pays (XOF)', v_uemoa;
    RAISE NOTICE '  Zone CEMAC (BEAC)            : % pays (XAF)', v_cemac;
    RAISE NOTICE '  Total                        : % pays', v_total;
    RAISE NOTICE '';
    RAISE NOTICE 'Pour MON_RES :';
    RAISE NOTICE '  NATIONAL → FI.RES.TOTL.MO   (réserves en mois importations)';
    RAISE NOTICE '  UEMOA/CEMAC → BN.CAB.XOKA.GD.ZS (balance courante %% PIB)';
END;
$$;

COMMIT;

-- ============================================================
-- Contrôle rapide post-déploiement
-- ============================================================
-- SELECT central_bank_type, central_bank_code, COUNT(*) AS nb_pays,
--        ROUND(AVG(monetary_sovereignty_weight),3) AS poids_moyen
-- FROM rf.countries
-- GROUP BY central_bank_type, central_bank_code
-- ORDER BY central_bank_type;
--
-- SELECT * FROM rf.countries_monetary WHERE central_bank_type != 'NATIONAL';