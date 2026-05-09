-- ============================================================
-- OSA — AUDIT DE COMPLÉTUDE DU MAPPAGE INDICATEURS ↔ SOURCES
-- Objectif : révéler exactement quels indicateurs sont mappés
--            et lesquels ne le sont pas, avec code WB si disponible
-- Base    : osa_db (PostgreSQL 17)
-- Schémas : rf, collect, ma
-- Date    : Mai 2026
-- ============================================================
-- BLOCS :
--   A : Vue complète indicateurs × sources (tous statuts)
--   B : Indicateurs MAPPÉS avec détail provider + code source
--   C : Indicateurs NON MAPPÉS (ni indicator_source ni source_registry)
--   D : Indicateurs en cours de qualification (source_registry)
--   E : Codes WB extraits de collect.provider_endpoints / source_code
--   F : Taux de complétude par pilier
--   G : Codes WB confirmés vs manquants
--   H : Recommandations de connexion prioritaires
-- ============================================================

\echo '======================================================'
\echo ' OSA — AUDIT COMPLÉTUDE MAPPAGE INDICATEURS ↔ SOURCES'
\echo '======================================================'

-- ============================================================
-- BLOC A — VUE COMPLÈTE : tous indicateurs actifs × statut mapping
-- ============================================================
\echo ''
\echo '=== BLOC A : VUE COMPLÈTE INDICATEURS × STATUT MAPPING ==='

SELECT
    i.pillar_code                                   AS "Pilier",
    i.code                                          AS "Code indicateur",
    i.name_fr                                       AS "Nom indicateur",
    i.direction                                     AS "Dir.",
    i.unit_code                                     AS "Unité",

    -- Statut pipeline opérationnel
    CASE
        WHEN cs.id IS NOT NULL
             THEN '✓ MAPPÉ'
        WHEN sri.source_id IS NOT NULL
             THEN '◎ EN QUALIFICATION'
        ELSE      '✗ SANS SOURCE'
    END                                             AS "Statut mappage",

    -- Provider et endpoint si mappé
    COALESCE(dp.code,       '—')                    AS "Provider",
    COALESCE(pe.endpoint_code, '—')                 AS "Endpoint",

    -- Code source chez le provider (code WB, code IMF, etc.)
    COALESCE(cs.source_code, '—')                   AS "Code source provider",

    -- Statut dans le source_registry si présent
    COALESCE(sr.decision_status::text, '—')         AS "Statut registry",

    -- Volume d'observations existantes
    COALESCE(obs.nb_obs::text, '0')                 AS "Nb obs. actuelles",
    COALESCE(obs.nb_pays::text, '0')                AS "Pays",
    COALESCE(obs.conf_moy::text, '—')               AS "Confiance moy."

FROM rf.indicators i

-- Exclusions (doublons)
WHERE i.is_active = true
  AND NOT EXISTS (
      SELECT 1 FROM ma.indicator_exclusions e
      WHERE e.indicator_code = i.code
  )

-- Mapping pipeline opérationnel (LEFT pour garder les non-mappés)
LEFT JOIN collect.indicator_source cs
       ON cs.indicator_code = i.code
      AND cs.is_active = true

LEFT JOIN collect.provider_endpoints pe
       ON pe.id = cs.endpoint_id

LEFT JOIN collect.data_providers dp
       ON dp.id = pe.provider_id

-- Source registry (qualification en cours)
LEFT JOIN collect.source_registry_indicators sri
       ON sri.indicator_code = i.code

LEFT JOIN collect.source_registry sr
       ON sr.id = sri.source_id

-- Volumes réels
LEFT JOIN (
    SELECT
        indicator_code,
        COUNT(*)                                    AS nb_obs,
        COUNT(DISTINCT country_iso3)                AS nb_pays,
        ROUND(AVG(confidence_score)::numeric, 3)    AS conf_moy
    FROM ma.indicator_values
    WHERE year BETWEEN 2010 AND 2024
      AND processed_value IS NOT NULL
    GROUP BY indicator_code
) obs ON obs.indicator_code = i.code

ORDER BY
    i.pillar_code,
    CASE
        WHEN cs.id IS NOT NULL THEN 1
        WHEN sri.source_id IS NOT NULL THEN 2
        ELSE 3
    END,
    i.code;


-- ============================================================
-- BLOC B — INDICATEURS MAPPÉS (pipeline opérationnel actif)
-- ============================================================
\echo ''
\echo '=== BLOC B : INDICATEURS MAPPÉS — DÉTAIL COMPLET ==='

SELECT
    i.pillar_code                                   AS "Pilier",
    i.code                                          AS "Code OSA",
    i.name_fr                                       AS "Nom",
    i.direction                                     AS "Dir.",
    dp.code                                         AS "Provider",
    dp.name                                         AS "Provider nom",
    pe.endpoint_code                                AS "Endpoint",
    pe.base_url                                     AS "URL base",
    cs.source_code                                  AS "Code source",   -- code WB, code IMF, etc.
    cs.source_type                                  AS "Type source",
    cs.collection_method                            AS "Méthode",
    cs.update_frequency                             AS "Fréquence",
    cs.last_collected_at                            AS "Dernière collecte",
    obs.nb_obs                                      AS "Nb obs.",
    obs.nb_pays                                     AS "Pays",
    obs.conf_moy                                    AS "Confiance"

FROM rf.indicators i
JOIN collect.indicator_source cs
     ON cs.indicator_code = i.code AND cs.is_active = true
JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
JOIN collect.data_providers dp     ON dp.id = pe.provider_id
LEFT JOIN (
    SELECT indicator_code,
           COUNT(*) nb_obs,
           COUNT(DISTINCT country_iso3) nb_pays,
           ROUND(AVG(confidence_score)::numeric, 3) conf_moy
    FROM ma.indicator_values
    WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) obs ON obs.indicator_code = i.code

WHERE i.is_active = true
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)

ORDER BY i.pillar_code, dp.code, i.code;


-- ============================================================
-- BLOC C — INDICATEURS NON MAPPÉS (sans source dans aucun système)
-- ============================================================
\echo ''
\echo '=== BLOC C : INDICATEURS NON MAPPÉS — À CONNECTER ==='

SELECT
    i.pillar_code                                   AS "Pilier",
    i.code                                          AS "Code OSA",
    i.name_fr                                       AS "Nom",
    i.direction                                     AS "Dir.",
    i.unit_code                                     AS "Unité",
    i.imputation_regime                             AS "Régime imputation",

    -- Volume existant malgré l'absence de mapping formel
    COALESCE(obs.nb_obs::text, '0')                 AS "Obs. existantes",
    COALESCE(obs.nb_pays::text, '0')                AS "Pays",

    -- Diagnostic
    CASE
        WHEN obs.nb_obs > 0
             THEN '⚠ Données présentes sans source tracée'
        WHEN i.imputation_regime = 'PHYSICAL'
             THEN '🔴 Physique non traçable — priorité haute'
        WHEN i.pillar_code IN ('PECO','PHUM','PMON')
             THEN '🟠 Pilier certifié — source attendue WB/IMF'
        WHEN i.pillar_code IN ('PGEO','PMIL','PNUM')
             THEN '🟡 Pilier composite — source spécialisée'
        ELSE      '⚪ À identifier'
    END                                             AS "Diagnostic"

FROM rf.indicators i

LEFT JOIN collect.indicator_source cs
       ON cs.indicator_code = i.code AND cs.is_active = true

LEFT JOIN collect.source_registry_indicators sri
       ON sri.indicator_code = i.code

LEFT JOIN (
    SELECT indicator_code,
           COUNT(*) nb_obs,
           COUNT(DISTINCT country_iso3) nb_pays
    FROM ma.indicator_values
    WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) obs ON obs.indicator_code = i.code

WHERE i.is_active = true
  AND cs.id IS NULL          -- pas de mapping opérationnel
  AND sri.source_id IS NULL  -- pas dans le registre non plus
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)

ORDER BY
    i.pillar_code,
    -- Données présentes sans source = urgence de traçage
    (obs.nb_obs IS NOT NULL AND obs.nb_obs > 0) DESC,
    obs.nb_obs DESC NULLS LAST,
    i.code;


-- ============================================================
-- BLOC D — INDICATEURS EN COURS DE QUALIFICATION (source_registry)
-- ============================================================
\echo ''
\echo '=== BLOC D : INDICATEURS EN QUALIFICATION (SOURCE REGISTRY) ==='

SELECT
    i.pillar_code                                   AS "Pilier",
    i.code                                          AS "Code OSA",
    i.name_fr                                       AS "Nom",
    sr.source_id                                    AS "Source ID",
    sreg.name                                       AS "Source nom",
    sreg.organisation                               AS "Organisation",
    sreg.source_type                                AS "Type",
    sreg.decision_status                            AS "Décision",
    sreg.freshness_score                            AS "Fraîcheur",
    sreg.completeness_score                         AS "Complétude",
    sreg.reliability_score                          AS "Fiabilité",
    sr.source_code                                  AS "Code source",
    sr.collection_notes                             AS "Notes"

FROM rf.indicators i
JOIN collect.source_registry_indicators sr
     ON sr.indicator_code = i.code
JOIN collect.source_registry sreg
     ON sreg.id = sr.source_id

WHERE i.is_active = true
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)

ORDER BY sreg.decision_status DESC, i.pillar_code, i.code;


-- ============================================================
-- BLOC E — CODES WB EXTRAITS DE COLLECT.INDICATOR_SOURCE
-- Tous les source_code existants, triés par provider
-- ============================================================
\echo ''
\echo '=== BLOC E : CODES SOURCE EXISTANTS PAR PROVIDER ==='

SELECT
    dp.code                                         AS "Provider",
    dp.name                                         AS "Provider nom",
    pe.endpoint_code                                AS "Endpoint",
    i.pillar_code                                   AS "Pilier",
    i.code                                          AS "Code OSA",
    i.name_fr                                       AS "Nom indicateur",
    i.direction                                     AS "Dir.",
    cs.source_code                                  AS "Code source provider",
    cs.source_type                                  AS "Type source"

FROM collect.indicator_source cs
JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
JOIN collect.data_providers dp     ON dp.id = pe.provider_id
JOIN rf.indicators i               ON i.code = cs.indicator_code

WHERE cs.is_active = true
  AND i.is_active = true
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)

ORDER BY dp.code, pe.endpoint_code, i.pillar_code, i.code;


-- ============================================================
-- BLOC F — TAUX DE COMPLÉTUDE PAR PILIER
-- ============================================================
\echo ''
\echo '=== BLOC F : TAUX DE COMPLÉTUDE PAR PILIER ==='

WITH total_per_pillar AS (
    SELECT
        i.pillar_code,
        COUNT(*)                                    AS total_actifs
    FROM rf.indicators i
    WHERE i.is_active = true
      AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
    GROUP BY i.pillar_code
),
mapped_per_pillar AS (
    SELECT
        i.pillar_code,
        COUNT(DISTINCT i.code)                      AS nb_mappes,
        STRING_AGG(DISTINCT dp.code, ', ' ORDER BY dp.code) AS providers_actifs
    FROM rf.indicators i
    JOIN collect.indicator_source cs ON cs.indicator_code = i.code AND cs.is_active = true
    JOIN collect.provider_endpoints pe ON pe.id = cs.endpoint_id
    JOIN collect.data_providers dp ON dp.id = pe.provider_id
    WHERE i.is_active = true
      AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
    GROUP BY i.pillar_code
),
registry_per_pillar AS (
    SELECT
        i.pillar_code,
        COUNT(DISTINCT i.code)                      AS nb_en_qualification
    FROM rf.indicators i
    JOIN collect.source_registry_indicators sri ON sri.indicator_code = i.code
    WHERE i.is_active = true
      AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code)
      -- Uniquement ceux qui n'ont pas encore de mapping opérationnel
      AND NOT EXISTS (SELECT 1 FROM collect.indicator_source cs2
                      WHERE cs2.indicator_code = i.code AND cs2.is_active = true)
    GROUP BY i.pillar_code
)
SELECT
    t.pillar_code                                   AS "Pilier",
    p.name_fr                                       AS "Nom pilier",
    t.total_actifs                                  AS "Total actifs",
    COALESCE(m.nb_mappes, 0)                        AS "Mappés (opérationnel)",
    COALESCE(r.nb_en_qualification, 0)              AS "En qualification",
    t.total_actifs
        - COALESCE(m.nb_mappes, 0)
        - COALESCE(r.nb_en_qualification, 0)        AS "Sans source",
    ROUND(
        COALESCE(m.nb_mappes, 0)::numeric
        / t.total_actifs * 100
    , 1)                                            AS "% mappé",
    ROUND(
        (COALESCE(m.nb_mappes, 0)
         + COALESCE(r.nb_en_qualification, 0))::numeric
        / t.total_actifs * 100
    , 1)                                            AS "% couvert (mappé+qualif)",
    COALESCE(m.providers_actifs, '—')               AS "Providers actifs"

FROM total_per_pillar t
JOIN rf.pillars p ON p.code = t.pillar_code
LEFT JOIN mapped_per_pillar m   ON m.pillar_code   = t.pillar_code
LEFT JOIN registry_per_pillar r ON r.pillar_code   = t.pillar_code

ORDER BY t.pillar_code;


-- ============================================================
-- BLOC G — CODES WB : CONFIRMÉS vs MANQUANTS
-- Croise les codes WB connus (depuis wb_indicator_map.py documenté
-- dans les transcripts) avec ce qui est dans indicator_source
-- ============================================================
\echo ''
\echo '=== BLOC G : CODES WB CONFIRMÉS vs MANQUANTS ==='

-- Codes WB extraits des transcripts et du rapport Providers v2
-- Cette table de référence encode ce qui DEVRAIT être dans source_code
WITH wb_reference AS (
    SELECT * FROM (VALUES
        -- PECO
        ('ECO_GDP',  'NY.GDP.PCAP.KD',         'WB', 'PECO'),
        ('ECO_GRW',  'NY.GDP.MKTP.KD.ZG',      'WB', 'PECO'),
        ('ECO_INV',  'NE.GDI.TOTL.ZS',         'WB', 'PECO'),
        ('ECO_FDI',  'BX.KLT.DINV.CD.WD',      'WB', 'PECO'),
        ('ECO_EMP',  'SL.EMP.TOTL.SP.ZS',      'WB', 'PECO'),
        ('ECO_IND',  'NV.IND.TOTL.ZS',         'WB', 'PECO'),
        ('ECO_TAX',  'GC.TAX.TOTL.GD.ZS',      'WB', 'PECO'),
        ('ECO_AGR',  'AG.LND.ARBL.ZS',         'WB', 'PECO'),
        ('ECO_UNE',  'SL.UEM.TOTL.ZS',         'WB', 'PECO'),
        -- PENV
        ('ENV_FOR',  'AG.LND.FRST.ZS',         'WB', 'PENV'),
        ('ENV_ENE',  'EG.EGY.PRIM.PP.KD',      'WB', 'PENV'),
        ('ENV_ENR',  'EG.ELC.RNEW.ZS',         'WB', 'PENV'),
        ('ENV_CO2',  'EN.ATM.CO2E.PC',         'WB', 'PENV'),
        ('ENV_ECO',  'ER.BDV.TOTL.XQ',         'WB', 'PENV'),
        ('ENV_PRO',  'ER.LND.PTLD.ZS',         'WB', 'PENV'),
        ('ENV_WAT',  'ER.H2O.INTR.PC',         'WB', 'PENV'),
        ('ENV_LAN',  'AG.LND.DGRD.ZS',         'WB', 'PENV'),
        ('ENV_FIS',  'ER.FSH.PROD.MT',         'WB', 'PENV'),
        -- PGEO
        ('PGEO_COR', 'CC.EST',                  'WB', 'PGEO'),
        ('GEO_STAB', 'PV.EST',                  'WB', 'PGEO'),
        ('GEO_RSK',  'RL.EST',                  'WB', 'PGEO'),
        -- PHUM
        ('HUM_MIG',  'SM.POP.NETM',            'WB', 'PHUM'),
        ('HUM_WAT',  'SH.H2O.BASW.ZS',        'WB', 'PHUM'),
        ('HUM_SAN',  'SH.STA.BASS.ZS',        'WB', 'PHUM'),
        ('HUM_GEN',  'SG.GEN.PARL.ZS',        'WB', 'PHUM'),
        ('HUM_EDU',  'SE.SEC.ENRR',            'WB', 'PHUM'),
        ('HUM_LIT',  'SE.ADT.LITR.ZS',        'WB', 'PHUM'),
        ('HUM_POV',  'SI.POV.DDAY',            'WB', 'PHUM'),
        ('HUM_POP',  'SP.POP.TOTL',            'WB', 'PHUM'),
        -- PMIL
        ('PMIL_HOMICIDE_RATE',  'VC.IHR.PSRC.P5',   'WB', 'PMIL'),
        ('PMIL_ARMED_FORCES',   'MS.MIL.TOTL.P1',   'WB', 'PMIL'),
        ('PMIL_DEF_BUDGET_GDP', 'MS.MIL.XPND.GD.ZS','WB', 'PMIL'),
        ('PMIL_DEF_BUDGET_GOV', 'MS.MIL.XPND.ZS',   'WB', 'PMIL'),
        -- PMIN
        ('MIN_VAL',  'NV.MNF.OTHR.ZS.UN',     'WB', 'PMIN'),
        -- PMON
        ('MON_INF',  'FP.CPI.TOTL.ZG',        'WB', 'PMON'),
        ('MON_RES',  'FI.RES.TOTL.CD',        'WB', 'PMON'),
        ('MON_M2',   'FM.LBL.BMNY.GD.ZS',    'WB', 'PMON'),
        ('MON_FIN',  'FS.AST.PRVT.GD.ZS',    'WB', 'PMON'),
        ('MON_DET',  'GC.XPN.INTP.RV.ZS',    'WB', 'PMON'),
        ('MON_INT',  'FR.INR.RINR',           'WB', 'PMON'),
        ('MON_STB',  'FB.BNK.CAPA.ZS',       'WB', 'PMON'),
        ('MON_EXT',  'DT.DOD.DECT.GD.ZS',    'WB', 'PMON'),
        -- PNUM
        ('PNUM_INTERNET_USERS',       'IT.NET.USER.ZS',   'WB', 'PNUM'),
        ('PNUM_MOBILE_SUBSCRIPTIONS', 'IT.CEL.SETS.P2',   'WB', 'PNUM'),
        ('PNUM_BROADBAND_FIXED',      'IT.NET.BBND.P2',   'WB', 'PNUM'),
        ('PNUM_SECURE_SERVERS',       'IT.NET.SECR.P6',   'WB', 'PNUM'),
        ('PNUM_TERTIARY_ENROLL',      'SE.TER.ENRR',      'WB', 'PNUM'),
        ('NUM_GOV',                   'GE.EST',            'WB', 'PNUM'),
        -- PRES
        ('PRES_WATER_AGRI',       'AG.LND.IRIG.AG.ZS',    'WB', 'PRES'),
        ('PRES_ENRG_USE_CAP',     'EG.USE.PCAP.KG.OE',   'WB', 'PRES'),
        ('PRES_FOSSIL_RENTS_EIA', 'NY.GDP.TOTL.RT.ZS',   'WB', 'PRES'),
        ('PRES_RENEW_SHARE_FEC',  'EG.FEC.RNEW.ZS',      'WB', 'PRES'),
        ('PRES_WATER_WITHDRAWAL', 'ER.H2O.FWTL.ZS',      'WB', 'PRES'),
        ('PRES_WATER_FRESH',      'ER.H2O.INTR.PC',      'WB', 'PRES'),
        ('PRES_OIL_RENTS',        'NY.GDP.PETR.RT.ZS',   'WB', 'PRES'),
        ('PRES_GAS_RENTS',        'NY.GDP.NGAS.RT.ZS',   'WB', 'PRES'),
        -- PTRA
        ('PTRA_RD_DENSITY',    'IS.ROD.TOTL.KM',     'WB', 'PTRA'),
        ('PTRA_RD_PAVED',      'IS.ROD.PAVE.ZS',     'WB', 'PTRA'),
        ('PTRA_AIR_PASSENGERS','IS.AIR.PSGR',         'WB', 'PTRA'),
        ('PTRA_AIR_CARGO',     'IS.AIR.GOOD.MT.K1',  'WB', 'PTRA'),
        ('PTRA_LOG_LPI',       'LP.LPI.OVRL.XQ',     'WB', 'PTRA'),
        ('PTRA_AIR_AIRPORTS',  'IS.AIR.DPRT',        'WB', 'PTRA')
    ) AS t(osa_code, wb_code, provider, pilier)
)
SELECT
    ref.pilier                                      AS "Pilier",
    ref.osa_code                                    AS "Code OSA",
    i.name_fr                                       AS "Nom indicateur",
    ref.wb_code                                     AS "Code WB attendu",
    CASE
        WHEN cs.source_code IS NOT NULL
             THEN '✓ PRÉSENT dans indicator_source'
        ELSE      '✗ MANQUANT — à créer'
    END                                             AS "Statut code WB",
    COALESCE(cs.source_code, '—')                   AS "Code WB actuel en base",
    CASE
        WHEN cs.source_code IS NOT NULL
              AND cs.source_code <> ref.wb_code
             THEN '⚠ DIFFÉRENCE — vérifier'
        WHEN cs.source_code IS NOT NULL
             THEN '✓ Cohérent'
        ELSE      '—'
    END                                             AS "Cohérence",
    COALESCE(obs.nb_obs::text, '0')                 AS "Obs. en base"

FROM wb_reference ref
LEFT JOIN rf.indicators i
       ON i.code = ref.osa_code

LEFT JOIN collect.indicator_source cs
       ON cs.indicator_code = ref.osa_code
      AND cs.is_active = true
      AND EXISTS (
          SELECT 1
          FROM collect.provider_endpoints pe2
          JOIN collect.data_providers dp2 ON dp2.id = pe2.provider_id
          WHERE pe2.id = cs.endpoint_id
            AND dp2.code = 'WB'
      )

LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs
    FROM ma.indicator_values
    WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) obs ON obs.indicator_code = ref.osa_code

ORDER BY ref.pilier, ref.osa_code;


-- ============================================================
-- BLOC H — RECOMMANDATIONS DE CONNEXION PRIORITAIRES
-- Indicateurs avec données en base mais sans source tracée
-- (le cas le plus urgent : données orphelines)
-- ============================================================
\echo ''
\echo '=== BLOC H : URGENCES — DONNÉES PRÉSENTES SANS SOURCE TRACÉE ==='

SELECT
    i.pillar_code                                   AS "Pilier",
    i.code                                          AS "Code OSA",
    i.name_fr                                       AS "Nom",
    obs.nb_obs                                      AS "Obs. en base",
    obs.nb_pays                                     AS "Pays",
    obs.conf_moy                                    AS "Confiance",
    obs.annee_min                                   AS "Début série",
    obs.annee_max                                   AS "Fin série",
    '⚠ Données présentes sans mapping source'      AS "Alerte",
    CASE i.pillar_code
        WHEN 'PECO' THEN 'Probablement WB — vérifier NY.*/NE.*/NV.*'
        WHEN 'PENV' THEN 'WB (AG./EN./ER.) ou FAO/GFW'
        WHEN 'PGEO' THEN 'WB WGI (CC./PV./RL.) ou ACLED'
        WHEN 'PHUM' THEN 'WB (SH./SE./SM./SI.)'
        WHEN 'PMIL' THEN 'WB (MS./VC.) ou SIPRI/ITU'
        WHEN 'PMIN' THEN 'USGS / COMTRADE / EITI'
        WHEN 'PMON' THEN 'WB (FP./FI./FM./FR./GC.) ou IMF'
        WHEN 'PNUM' THEN 'WB (IT.) ou ITU/UN DESA'
        WHEN 'PRES' THEN 'WB (EG./ER./NY.) ou IRENA/IEA'
        WHEN 'PTRA' THEN 'WB (IS./LP.) ou UNCTAD'
        ELSE 'À identifier'
    END                                             AS "Source probable"

FROM rf.indicators i

-- Données présentes
JOIN (
    SELECT
        indicator_code,
        COUNT(*)                                    AS nb_obs,
        COUNT(DISTINCT country_iso3)                AS nb_pays,
        ROUND(AVG(confidence_score)::numeric, 3)    AS conf_moy,
        MIN(year)                                   AS annee_min,
        MAX(year)                                   AS annee_max
    FROM ma.indicator_values
    WHERE year BETWEEN 2010 AND 2024
      AND processed_value IS NOT NULL
    GROUP BY indicator_code
) obs ON obs.indicator_code = i.code

-- Mais SANS mapping opérationnel
WHERE i.is_active = true
  AND NOT EXISTS (
      SELECT 1 FROM collect.indicator_source cs
      WHERE cs.indicator_code = i.code AND cs.is_active = true
  )
  AND NOT EXISTS (
      SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code
  )

ORDER BY obs.nb_obs DESC, i.pillar_code, i.code;


-- ============================================================
-- RÉSUMÉ GLOBAL — Tableau de synthèse
-- ============================================================
\echo ''
\echo '=== RÉSUMÉ GLOBAL ==='

SELECT
    COUNT(*)                                        AS "Total indicateurs actifs",
    COUNT(CASE WHEN cs.id IS NOT NULL THEN 1 END)   AS "Mappés (opérationnel)",
    COUNT(CASE WHEN cs.id IS NULL
               AND sri.source_id IS NOT NULL THEN 1 END) AS "En qualification",
    COUNT(CASE WHEN cs.id IS NULL
               AND sri.source_id IS NULL THEN 1 END) AS "Sans source",
    ROUND(
        COUNT(CASE WHEN cs.id IS NOT NULL THEN 1 END)::numeric
        / COUNT(*) * 100
    , 1)                                            AS "% mappé",
    COUNT(CASE WHEN cs.id IS NULL
               AND obs.nb_obs > 0 THEN 1 END)       AS "⚠ Données orphelines"

FROM rf.indicators i
LEFT JOIN collect.indicator_source cs
       ON cs.indicator_code = i.code AND cs.is_active = true
LEFT JOIN collect.source_registry_indicators sri
       ON sri.indicator_code = i.code
LEFT JOIN (
    SELECT indicator_code, COUNT(*) nb_obs
    FROM ma.indicator_values
    WHERE year BETWEEN 2010 AND 2024 AND processed_value IS NOT NULL
    GROUP BY indicator_code
) obs ON obs.indicator_code = i.code
WHERE i.is_active = true
  AND NOT EXISTS (SELECT 1 FROM ma.indicator_exclusions e WHERE e.indicator_code = i.code);

\echo ''
\echo '=== AUDIT COMPLÉTUDE TERMINÉ ==='
\echo 'Consultez les résultats par bloc pour prioriser les connexions.'
\echo 'Bloc H = urgences immédiates (données orphelines).'
\echo 'Bloc G = vérification cohérence codes WB.'
