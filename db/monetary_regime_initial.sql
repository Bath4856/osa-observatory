-- ================================================================
-- M2 : Insertion des 54 régimes monétaires initiaux (2010)
-- SCD Type 2 — valid_from=2010, valid_to=NULL (actuel)
-- OSA Observatory — Mai 2026
-- ================================================================

INSERT INTO ma.country_monetary_regime
    (country_iso3, regime_type, mon_sov_factor, valid_from, valid_to,
     is_current, source_note, decision_ref)
VALUES
-- CFA UEMOA (8 pays) — factor 0.40
('BEN','CFA_UEMOA',0.40,2010,NULL,true,'BCEAO — Banque Centrale des Etats de lAfrique de lOuest','Traite UEMOA 1994'),
('BFA','CFA_UEMOA',0.40,2010,NULL,true,'BCEAO — membre AES, transition monetaire en cours','Traite UEMOA 1994 / AES 2023'),
('CIV','CFA_UEMOA',0.40,2010,NULL,true,'BCEAO — Banque Centrale des Etats de lAfrique de lOuest','Traite UEMOA 1994'),
('GNB','CFA_UEMOA',0.40,2010,NULL,true,'BCEAO — Guinee-Bissau membre UEMOA depuis 1997','Adhesion UEMOA 1997'),
('MLI','CFA_UEMOA',0.40,2010,NULL,true,'BCEAO — membre AES, transition monetaire en cours','Traite UEMOA 1994 / AES 2023'),
('NER','CFA_UEMOA',0.40,2010,NULL,true,'BCEAO — membre AES, transition monetaire en cours','Traite UEMOA 1994 / AES 2023'),
('SEN','CFA_UEMOA',0.40,2010,NULL,true,'BCEAO — Banque Centrale des Etats de lAfrique de lOuest','Traite UEMOA 1994'),
('TGO','CFA_UEMOA',0.40,2010,NULL,true,'BCEAO — Banque Centrale des Etats de lAfrique de lOuest','Traite UEMOA 1994'),
-- CFA CEMAC (6 pays) — factor 0.40
('CMR','CFA_CEMAC',0.40,2010,NULL,true,'BEAC — Banque des Etats de lAfrique Centrale','Traite CEMAC 1994'),
('CAF','CFA_CEMAC',0.40,2010,NULL,true,'BEAC — Banque des Etats de lAfrique Centrale','Traite CEMAC 1994'),
('TCD','CFA_CEMAC',0.40,2010,NULL,true,'BEAC — membre AES, situation monetaire a surveiller','Traite CEMAC 1994 / AES 2023'),
('COG','CFA_CEMAC',0.40,2010,NULL,true,'BEAC — Banque des Etats de lAfrique Centrale','Traite CEMAC 1994'),
('GAB','CFA_CEMAC',0.40,2010,NULL,true,'BEAC — Banque des Etats de lAfrique Centrale','Traite CEMAC 1994'),
('GNQ','CFA_CEMAC',0.40,2010,NULL,true,'BEAC — Guinee Equatoriale membre CEMAC','Adhesion CEMAC 1985'),
-- ZAR Rand (4 pays) — factor 0.60
('LSO','ZAR_RAND',0.60,2010,NULL,true,'CMA — Common Monetary Area, loti arrime au rand','Accord CMA 1986'),
('NAM','ZAR_RAND',0.60,2010,NULL,true,'CMA — dollar namibien arrime au rand 1:1','Independance 1990 / CMA'),
('SWZ','ZAR_RAND',0.60,2010,NULL,true,'CMA — lilangeni arrime au rand 1:1','Accord CMA 1986'),
('ZAF','ZAR_RAND',0.60,2010,NULL,true,'SARB — Reserve Bank souveraine mais anchor du CMA','Banque centrale souveraine ZAR'),
-- Dollarisés (3 pays) — factor 0.50
('DJI','DOLLARIZED',0.50,2010,NULL,true,'BCD — franc djiboutien arrime USD depuis 1949','Arrimage USD 1949'),
('LBR','DOLLARIZED',0.50,2010,NULL,true,'CBL — dollar liberien et USD en circulation simultanee','Dollarisation partielle'),
('ZWE','DOLLARIZED',0.50,2010,NULL,true,'RBZ — abandon ZWD 2009, multicurrency USD dominant','Crise hyperinflation 2009'),
-- Pegged EUR (2 pays) — factor 0.50
('COM','PEGGED_EUR',0.50,2010,NULL,true,'BCC — franc comorien arrime EUR via accord bilateral France','Accord bilateral France 1994'),
('STP','PEGGED_EUR',0.50,2010,NULL,true,'BCSTP — dobra arrime EUR via accord bilateral Portugal','Accord bilateral Portugal 1998'),
-- Pegged basket (1 pays) — factor 0.70
('MAR','PEGGED_BASKET',0.70,2010,NULL,true,'BAM — dirham arrime panier EUR/USD gere activement','Reforme change BAM 2018'),
-- Indépendants (26 pays) — factor 1.00
('AGO','INDEPENDENT',1.00,2010,NULL,true,'BNA — kwanza, politique monetaire souveraine','Banque nationale Angola'),
('BWA','INDEPENDENT',1.00,2010,NULL,true,'BoB — pula, politique monetaire souveraine','Bank of Botswana'),
('BDI','INDEPENDENT',1.00,2010,NULL,true,'BRB — franc burundais, politique monetaire souveraine','Banque de la Republique du Burundi'),
('CPV','INDEPENDENT',1.00,2010,NULL,true,'BCV — escudo cap-verdien, politique monetaire souveraine','Banco de Cabo Verde'),
('COD','INDEPENDENT',1.00,2010,NULL,true,'BCC — franc congolais, politique monetaire souveraine','Banque Centrale du Congo'),
('DZA','INDEPENDENT',1.00,2010,NULL,true,'BA — dinar algerien, politique monetaire souveraine','Banque dAlgerie'),
('EGY','INDEPENDENT',1.00,2010,NULL,true,'CBE — livre egyptienne, politique monetaire souveraine','Central Bank of Egypt'),
('ERI','INDEPENDENT',1.00,2010,NULL,true,'BNE — nakfa, politique monetaire souveraine','Bank of Eritrea'),
('ETH','INDEPENDENT',1.00,2010,NULL,true,'NBE — birr ethiopien, politique monetaire souveraine','National Bank of Ethiopia'),
--
('GHA','INDEPENDENT',1.00,2010,NULL,true,'BoG — cedi ghaneen, politique monetaire souveraine','Bank of Ghana'),
('GMB','INDEPENDENT',1.00,2010,NULL,true,'CBG — dalasi, politique monetaire souveraine','Central Bank of Gambia'),
('GIN','INDEPENDENT',1.00,2010,NULL,true,'BCRG — franc guineen, politique monetaire souveraine','Banque Centrale Republique de Guinee'),
('KEN','INDEPENDENT',1.00,2010,NULL,true,'CBK — shilling kenyan, politique monetaire souveraine','Central Bank of Kenya'),
('LBY','INDEPENDENT',1.00,2010,NULL,true,'CBL — dinar libyen, politique monetaire souveraine','Central Bank of Libya'),
('MDG','INDEPENDENT',1.00,2010,NULL,true,'BFM — ariary malgache, politique monetaire souveraine','Banky Foiben i Madagasikara'),
--
('MOZ','INDEPENDENT',1.00,2010,NULL,true,'BM — metical, politique monetaire souveraine','Banco de Mocambique'),
('MRT','INDEPENDENT',1.00,2010,NULL,true,'BCM — ouguiya, politique monetaire souveraine','Banque Centrale de Mauritanie'),
('MUS','INDEPENDENT',1.00,2010,NULL,true,'BoM — roupie mauricienne, politique monetaire souveraine','Bank of Mauritius'),
('MWI','INDEPENDENT',1.00,2010,NULL,true,'RBM — kwacha malawien, politique monetaire souveraine','Reserve Bank of Malawi'),
-- ('NAM','ZAR_RAND',0.60,2010,NULL,true,'BoN — voir entree precedente','CMA'),
('NGA','INDEPENDENT',1.00,2010,NULL,true,'CBN — naira, politique monetaire souveraine','Central Bank of Nigeria'),
('RWA','INDEPENDENT',1.00,2010,NULL,true,'BNR — franc rwandais, politique monetaire souveraine','Banque Nationale du Rwanda'),
('SDN','INDEPENDENT',1.00,2010,NULL,true,'CBOS — livre soudanaise, politique monetaire souveraine','Central Bank of Sudan'),
('SLE','INDEPENDENT',1.00,2010,NULL,true,'BSL — leone, politique monetaire souveraine','Bank of Sierra Leone'),
('SOM','INDEPENDENT',0.80,2010,NULL,true,'CBS — shilling somalien, institutions monetaires fragiles','Central Bank of Somalia'),
('SSD','INDEPENDENT',0.80,2010,NULL,true,'SSBS — livre soudanaise du sud, institutions fragiles','Bank of South Sudan'),
('SYC','INDEPENDENT',1.00,2010,NULL,true,'CBS — roupie seychelloise, politique monetaire souveraine','Central Bank of Seychelles'),
('TZA','INDEPENDENT',1.00,2010,NULL,true,'BoT — shilling tanzanien, politique monetaire souveraine','Bank of Tanzania'),
('TUN','INDEPENDENT',1.00,2010,NULL,true,'BCT — dinar tunisien, politique monetaire souveraine','Banque Centrale de Tunisie'),
('UGA','INDEPENDENT',1.00,2010,NULL,true,'BoU — shilling ougandais, politique monetaire souveraine','Bank of Uganda'),
('ZMB','INDEPENDENT',1.00,2010,NULL,true,'BoZ — kwacha zambien, politique monetaire souveraine','Bank of Zambia');
-- ('ZWE','DOLLARIZED',0.50,2010,NULL,true,'RBZ — voir entree precedente','Crise hyperinflation 2009');

-- Verification
SELECT
    regime_type,
    COUNT(*) AS nb_pays,
    AVG(mon_sov_factor) AS factor_moy,
    STRING_AGG(country_iso3, ',' ORDER BY country_iso3) AS pays
FROM ma.country_monetary_regime
WHERE is_current = true
GROUP BY regime_type
ORDER BY nb_pays DESC;