-- ================================================================
-- CREATION DE ma.pillar_type
-- Typologie des piliers par nature du reel
-- OSA Observatory -- Avril 2026
-- ================================================================

CREATE TABLE ma.pillar_type (
    pillar_code         VARCHAR(10)     NOT NULL
                        REFERENCES rf.pillars(code),
    pillar_type         VARCHAR(20)     NOT NULL
                        CHECK (pillar_type IN ('PHYSIQUE','STRUCTUREL','COMPOSITE')),
    seuil_exclusion     NUMERIC(4,2)    NOT NULL,
    niveau_certification VARCHAR(20)   NOT NULL
                        CHECK (niveau_certification IN ('CERTIFIE','CONDITIONNEL','MODELISE')),
    imputation_rule     VARCHAR(30)     NOT NULL
                        CHECK (imputation_rule IN ('RESTRICTIVE','PRUDENTE','PERMISE')),
    justification       TEXT,
    assigned_by         VARCHAR(100)    DEFAULT 'OSA-team',
    assigned_at         TIMESTAMP       DEFAULT now(),
    PRIMARY KEY (pillar_code)
);

COMMENT ON TABLE ma.pillar_type IS
'Typologie des piliers OSA par nature du reel. Pilote les regles d imputation, les seuils d exclusion et les niveaux de certification des scores ISA.';

-- ================================================================
-- INSERTION DES 10 PILIERS
-- ================================================================

INSERT INTO ma.pillar_type
    (pillar_code, pillar_type, seuil_exclusion, niveau_certification, imputation_rule, justification)
VALUES

-- PILIERS PHYSIQUES (seuil 80%, imputation restrictive)
(
    'PENV', 'PHYSIQUE', 0.80, 'CERTIFIE', 'RESTRICTIVE',
    'Donnees biophysiques (forets, eau, CO2, sols, energie). Evolution lente, contraintes naturelles. Sources FAO/WB/IEA. Toute imputation doit etre tracee et coefficientee.'
),
(
    'PRES', 'PHYSIQUE', 0.80, 'CERTIFIE', 'RESTRICTIVE',
    'Ressources energetiques et hydriques, rentes naturelles, donnees geophysiques. Regime PHYSICAL deja present dans rf.indicators. Sources IEA/FAO/IRENA/WB. Pilier de reference physique.'
),

-- PILIERS STRUCTURELS (seuil 70%, imputation avec prudence)
(
    'PECO', 'STRUCTUREL', 0.70, 'CONDITIONNEL', 'PRUDENTE',
    'Donnees macroeconomiques observables et certifiees. Confiance 0.996, 100% observations reelles, sources WB/IMF primaires. Modelisable avec prudence sur indicateurs partiels.'
),
(
    'PHUM', 'STRUCTUREL', 0.70, 'CONDITIONNEL', 'PRUDENTE',
    'Donnees sociales institutionnelles observables. Confiance 0.962, sources UNICEF/WB/ONU. HUM_DIG (0.718) surveiller. Serie complete 2010-2024.'
),
(
    'PMIN', 'STRUCTUREL', 0.70, 'CONDITIONNEL', 'PRUDENTE',
    'Donnees sectorielles observables : commerce, fiscalite, gouvernance miniere. Sources ILO/UNCTAD/AME. MIN_ENV et MIN_DIV a surveiller (1 seul millesime 2023).'
),
(
    'PMON', 'STRUCTUREL', 0.70, 'CERTIFIE', 'PRUDENTE',
    'Donnees monetaires certifiees a la source. Confiance 1.000 sur tous les indicateurs, zero imputation. Sources IMF/WB. Pilier de reference qualite de lensemble ISA.'
),
(
    'PTRA', 'STRUCTUREL', 0.70, 'CONDITIONNEL', 'PRUDENTE',
    'Infrastructure de transport observable et mesurable. Sources institutionnelles WB LPI/LSCI. PTRA_RD_DENSITY (conf. 0.577) et PTRA_RD_PAVED (0.550) a ponderer. 2415 imputations.'
),

-- PILIERS COMPOSITES (seuil 60%, imputation permise)
(
    'PGEO', 'COMPOSITE', 0.60, 'MODELISE', 'PERMISE',
    'Dependance aux indices ACLED/WGI/RSF. 12/16 indicateurs sans score de confiance renseigne. Donnees conflictuelles et geopolitiques fortement modelisees. Pilier clairement composite.'
),
(
    'PMIL', 'COMPOSITE', 0.60, 'MODELISE', 'PERMISE',
    'Melange de donnees observees (effectifs, budget) et d indices composites externes (GTI, WGI, SIPRI). Dimension securitaire et projection de puissance fortement modelisees. Classifie COMPOSITE par principe de prudence.'
),
(
    'PNUM', 'COMPOSITE', 0.60, 'MODELISE', 'PERMISE',
    'Dependance ITU/EGDI/WGI. Indicateurs biannuels (EGDI tous les 2 ans). Alternance 7/10 indicateurs actifs selon les annees. Pilier clairement composite et dependant d indices externes.'
);

-- ================================================================
-- VERIFICATION
-- ================================================================

SELECT
    pt.pillar_code,
    p.name_fr,
    pt.pillar_type,
    pt.seuil_exclusion,
    pt.niveau_certification,
    pt.imputation_rule
FROM ma.pillar_type pt
JOIN rf.pillars p ON p.code = pt.pillar_code
ORDER BY pt.pillar_type, pt.pillar_code;
