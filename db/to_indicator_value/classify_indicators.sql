-- OSA Observatory — Classification indicator_group — Sprint 22
-- Taxonomie : PHYSIQUE / EXPLOITATION / PRESSION / TRAJECTOIRE
-- 206 indicateurs sur 10 piliers

-- ══ PECO — Souverainete economique ══════════════════════════════

UPDATE rf.indicators SET indicator_group = 'PHYSIQUE' WHERE code IN (
    'ECO_GDP',      -- PIB par habitant (capital economique brut)
    'ECO_PRO',      -- PIB par travailleur (productivite)
    'ECO_IND',      -- Part secteur industriel dans PIB
    'ECO_SME',      -- Part PME dans PIB
    'ECO_AGR'       -- Securite alimentaire (base physique)
);

UPDATE rf.indicators SET indicator_group = 'EXPLOITATION' WHERE code IN (
    'ECO_EXP',      -- Part produits manufactures dans exports
    'ECO_FDI',      -- IDE nets
    'ECO_INV',      -- Formation brute capital fixe
    'ECO_TAX',      -- Recettes fiscales % PIB
    'ECO_EMP',      -- Part emploi formel
    'ECO_PUBLIC_REV', -- Recettes publiques hors dons
    'ECO_DIV',      -- Indice Herfindahl exports
    'ECO_VAF',      -- Valeur ajoutee agricole
    'ECO_EXB',      -- Exportations brutes
    'ECO_INB'       -- Investissements nets bruts
);

UPDATE rf.indicators SET indicator_group = 'PRESSION' WHERE code IN (
    'ECO_IMP',      -- Part importations dans consommation
    'ECO_INF',      -- Inflation
    'ECO_UNE',      -- Chomage
    'ECO_GRW',      -- Taux croissance PIB
    'ECO_INFORMAL_RATE',  -- Part emploi informel
    'ECO_INFORMAL_NB',    -- Nombre travailleurs informels
    'ECO_INFORMAL_MICRO', -- Travailleurs informels micro-entreprises
    'ECO_INFORMAL_NAG'    -- Emploi informel non-agricole
);

UPDATE rf.indicators SET indicator_group = 'TRAJECTOIRE' WHERE code IN (
    'ECO_PUBLIC_LEAKAGE',   -- Fuite recettes publiques
    'ECO_TAX_EFFICIENCY',   -- Efficacite fiscale
    'ECO_FORMAL_TRAJECTORY' -- Trajectoire formalisation economique
);

-- ══ PENV — Souverainete environnementale ════════════════════════

UPDATE rf.indicators SET indicator_group = 'PHYSIQUE' WHERE code IN (
    'ENV_FOR',  -- Part territoire couvert de forets
    'ENV_WAT',  -- Eau douce renouvelable disponible
    'ENV_SOL',  -- Fertilite et sante des sols
    'ENV_BIO',  -- Biodiversite
    'ENV_ECO'   -- Capacite regeneration ecosystemes
);

UPDATE rf.indicators SET indicator_group = 'EXPLOITATION' WHERE code IN (
    'ENV_ENR',  -- Part renouvelables production energie
    'ENV_ENE',  -- Consommation energie par unite PIB
    'ENV_PRO',  -- Part territoire en aires protegees
    'ENV_FIS',  -- Sante stocks poissons exploites
    'ENV_WAS'   -- Collecte et traitement dechets
);

UPDATE rf.indicators SET indicator_group = 'PRESSION' WHERE code IN (
    'ENV_CO2',  -- Emissions CO2 par habitant
    'ENV_LAN',  -- Terres degradees ou desertifiees
    'ENV_POL',  -- Pollution air, eau et sols
    'ENV_RSK',  -- Exposition evenements climatiques extremes
    'ENV_ADA',  -- Capacite adaptation changements climatiques
    'ENV_DEF',  -- Deforestation
    'ENV_REF'   -- Refugies environnementaux
);

-- ══ PGEO — Souverainete geopolitique ════════════════════════════

UPDATE rf.indicators SET indicator_group = 'PHYSIQUE' WHERE code IN (
    'GEO_DIP',  -- Representations diplomatiques
    'GEO_ORG',  -- Organisations internationales membres
    'GEO_ALL',  -- Partenariats strategiques actifs
    'GEO_TRD',  -- Accords libre-echange en vigueur
    'GEO_POW',  -- Influence dans la sous-region
    'GEO_SOF'   -- Influence culturelle et normative
);

UPDATE rf.indicators SET indicator_group = 'EXPLOITATION' WHERE code IN (
    'GEO_PEA',  -- Personnel maintien de paix
    'GEO_CUL',  -- Rayonnement culturel international
    'GEO_NET',  -- Diplomatie numerique
    'GEO_RES',  -- Capacite absorption chocs geopolitiques
    'GEO_SOVEREIGN_MARGIN' -- Marge fiscale souveraine
);

UPDATE rf.indicators SET indicator_group = 'PRESSION' WHERE code IN (
    'GEO_CON',      -- Conflits frontaliers
    'GEO_SAN',      -- Exposition sanctions internationales
    'GEO_MIG',      -- Flux emigration
    'GEO_CONF',     -- Dyades actives UCDP
    'GEO_TER',      -- Fatalites UCDP
    'PGEO_CIV',     -- Evenements ciblant civils ACLED
    'PGEO_EVT',     -- Evenements violents UCDP
    'PGEO_FAT',     -- Morts violence organisee UCDP
    'PGEO_INS',     -- Morts par evenement
    'PGEO_INT',     -- Proportion evenements etatiques
    'PGEO_PEAK',    -- Annee fatalites maximales
    'PGEO_PRE',     -- Fatalites glissantes 3 ans
    'PGEO_SPR',     -- Lieux distincts touches
    'PGEO_STR',     -- Part civils dans fatalites
    'PGEO_TRD'      -- Variation fatalites vs annee precedente
);

-- ══ PHUM — Souverainete humaine ══════════════════════════════════

UPDATE rf.indicators SET indicator_group = 'PHYSIQUE' WHERE code IN (
    'HUM_POP',  -- Population en age de travailler
    'HUM_HEA',  -- Esperance de vie
    'HUM_LIT',  -- Taux alphabetisation
    'HUM_EDU',  -- Scolarisation secondaire
    'HUM_FOO'   -- Securite alimentaire
);

UPDATE rf.indicators SET indicator_group = 'EXPLOITATION' WHERE code IN (
    'HUM_HEA2', -- Acces et qualite soins
    'HUM_SAN',  -- Acces assainissement
    'HUM_WAT',  -- Acces eau potable
    'HUM_DIG',  -- Competences numeriques
    'HUM_GEN',  -- Egalite de genre
    'HUM_SOC'   -- Cohesion et capital social
);

UPDATE rf.indicators SET indicator_group = 'PRESSION' WHERE code IN (
    'HUM_INF',  -- Mortalite moins de 5 ans
    'HUM_POV',  -- Population sous seuil pauvrete
    'HUM_MIG',  -- Solde migratoire net (fuite cerveaux)
    'HUM_RES'   -- Capacite absorption chocs
);

-- ══ PMIL — Souverainete militaire ════════════════════════════════

UPDATE rf.indicators SET indicator_group = 'PHYSIQUE' WHERE code IN (
    'MIL_PER',          -- Effectif forces armees actives
    'MIL_RES',          -- Forces de reserve mobilisables
    'MIL_EQU',          -- Modernisation equipement
    'MIL_IND',          -- Production equipements defense
    'PMIL_ARMED_FORCES', -- Effectif total forces armees
    'MIL_EXP',          -- Depenses militaires % PIB
    'MIL_EXP_PC',       -- Depenses militaires par habitant
    'MIL_EXP_PCT',      -- Depenses militaires % PIB SIPRI
    'PMIL_DEF_BUDGET_GDP', -- Budget defense % PIB
    'PMIL_DEF_BUDGET_GOV'  -- Budget defense % depenses gouvernement
);

UPDATE rf.indicators SET indicator_group = 'EXPLOITATION' WHERE code IN (
    'MIL_LOG',  -- Capacite logistique forces
    'MIL_INT',  -- Interoperabilite avec allies
    'MIL_MIS',  -- Missions de paix en cours
    'MIL_BRD',  -- Surveillance frontaliere
    'MIL_STR',  -- Projection de force
    'MIL_CYB',  -- Cyberdefense nationale
    'PMIL_GCI_CYBER' -- Indice cyberdefense GCI
);

UPDATE rf.indicators SET indicator_group = 'PRESSION' WHERE code IN (
    'MIL_DEP',          -- Part importations armes
    'MIL_TER',          -- Indice terrorisme inverse
    'MIL_SEC',          -- Securite et ordre public
    'MIL_STB',          -- Cohesion institutionnelle forces
    'PMIL_ARMS_IMPORT', -- Importations armement SIPRI
    'PMIL_ARMS_EXPORT', -- Exportations armement SIPRI
    'PMIL_GTI_TERROR',  -- Global Terrorism Index
    'PMIL_HOMICIDE_RATE' -- Taux homicide
);

-- ══ PMIN — Indicateurs restants sans groupe ══════════════════════

UPDATE rf.indicators SET indicator_group = 'EXPLOITATION' WHERE code IN (
    'MIN_CERT',  -- Conformite EITI
    'MIN_COM',   -- Proxy commerce minier
    'MIN_DIV',   -- Diversite minerais exploites
    'MIN_EMP',   -- Emplois directs mines
    'MIN_INV',   -- IDE secteur minier
    'MIN_TECH',  -- Modernisation technologique
    'MIN_TRAC'   -- Tracabilite et certification
);

UPDATE rf.indicators SET indicator_group = 'PRESSION' WHERE code IN (
    'MIN_LEAKAGE_RISK' -- Ecart rente fossile vs gouvernance
);

-- ══ PMON — Souverainete monetaire ════════════════════════════════

UPDATE rf.indicators SET indicator_group = 'PHYSIQUE' WHERE code IN (
    'MON_RES',  -- Reserves devises banque centrale
    'MON_M2',   -- Profondeur financiere
    'MON_CUR',  -- Stabilite monnaie nationale
    'MON_IND',  -- Independence banque centrale
    'MON_CTRL', -- Souverainete taux directeur
    'MON_GDP_CURRENT' -- PIB courant (auxiliaire)
);

UPDATE rf.indicators SET indicator_group = 'EXPLOITATION' WHERE code IN (
    'MON_FIN',  -- Acces services financiers
    'MON_DIG',  -- Adoption CBDC paiements numeriques
    'MON_CRY',  -- Part transactions crypto
    'MON_CAP',  -- Regulation flux capitaux
    'MON_CHG',  -- Flexibilite regime de change
    'MON_PAY',  -- Balance courante
    'MON_STB'   -- Ratio capital reserves / actifs
);

UPDATE rf.indicators SET indicator_group = 'PRESSION' WHERE code IN (
    'MON_DET',  -- Service dette / recettes
    'MON_EXT',  -- Dette exterieure / PIB
    'MON_INF',  -- Inflation annuelle
    'MON_INT',  -- Taux reel moyen
    'MON_EXR',  -- Instabilite taux de change
    'MON_AUT'   -- Autonomie banque centrale (desactive)
);

UPDATE rf.indicators SET indicator_group = 'TRAJECTOIRE' WHERE code IN (
    'MON_IFF_PRESSURE' -- Pression flux financiers illicites
);

-- ══ PNUM — Souverainete numerique ════════════════════════════════

UPDATE rf.indicators SET indicator_group = 'PHYSIQUE' WHERE code IN (
    'NUM_INT',              -- Part population utilisant internet
    'NUM_MOB',              -- Abonnements mobiles
    'NUM_FIB',              -- Reseau fibre national
    'NUM_DAT',              -- Data centers sur le territoire
    'NUM_SAT',              -- Satellites nationaux
    'PNUM_BROADBAND_FIXED',    -- Haut debit fixe
    'PNUM_BROADBAND_MOBILE',   -- Haut debit mobile
    'PNUM_INTERNET_USERS',     -- Utilisateurs internet
    'PNUM_MOBILE_SUBSCRIPTIONS', -- Abonnements mobiles
    'PNUM_SECURE_SERVERS'      -- Serveurs securises
);

UPDATE rf.indicators SET indicator_group = 'EXPLOITATION' WHERE code IN (
    'NUM_GOV',              -- E-gouvernement EGDI
    'NUM_REG',              -- Maturite cadre legal numerique
    'NUM_DIG',              -- Part economie numerique PIB
    'NUM_FIN',              -- Adoption fintech
    'NUM_CLO',              -- Services cloud
    'NUM_STU',              -- Formation numerique STEM
    'PNUM_EGDI_EGOV',       -- EGDI e-gouvernement
    'PNUM_EGDI_HUMAN_CAP',  -- EGDI capital humain
    'PNUM_EGDI_ONLINE_SVC', -- EGDI services en ligne
    'PNUM_TERTIARY_ENROLL'  -- Scolarisation tertiaire
);

UPDATE rf.indicators SET indicator_group = 'PRESSION' WHERE code IN (
    'NUM_CYB',          -- Cybersecurite UIT
    'NUM_RES',          -- Resistance cybermenaces
    'NUM_AI',           -- Capacite IA nationale
    'NUM_DAT2',         -- Controle national donnees
    'PNUM_GCI_DIGITAL', -- GCI digital
    'PNUM_ITU_REG_ENV'  -- Environnement reglementaire UIT
);

-- ══ PRES — Ressources strategiques ══════════════════════════════

UPDATE rf.indicators SET indicator_group = 'PHYSIQUE' WHERE code IN (
    'PRES_EN_RESERVE',      -- Reserves prouvees energie
    'PRES_EN_ELEC_PROD',    -- Production electrique nationale
    'PRES_EN_FOSSIL',       -- Production hydrocarbures charbon
    'PRES_EN_PROD_TOT',     -- Production nationale brute
    'PRES_WA_RES_TOTAL',    -- Volume total eau renouvelable
    'PRES_WA_RES_PC',       -- Eau renouvelable par habitant
    'PRES_WA_INTERNAL',     -- Part ressources hydriques internes
    'PRES_WA_GROUND',       -- Part eaux souterraines
    'PRES_WA_SURFACE',      -- Part eaux de surface
    'PRES_WA_STORAGE',      -- Capacite stockage eau
    'PRES_BEN',             -- Reserves benzene
    'PRES_CAR',             -- Reserves charbon
    'PRES_PRB'              -- Reserves petrole brut
);

UPDATE rf.indicators SET indicator_group = 'EXPLOITATION' WHERE code IN (
    'PRES_EN_CAPACITY',     -- Puissance installee
    'PRES_EN_CAP_PC',       -- Production electrique par habitant
    'PRES_EN_RENEW_SHARE',  -- Part renouvelables production
    'PRES_WATER_AGRI',      -- Eau utilisee agriculture
    'PRES_WATER_FRESH',     -- Eau douce disponible
    'PRES_WATER_WITHDRAWAL', -- Prelevement eau total
    'PRES_RENEW_CAP_IRENA', -- Capacite renouvelables IRENA
    'PRES_RENEW_SHARE_FEC', -- Part renouvelables FEC
    'PRES_ENRG_PROD_IEA',   -- Production energie IEA
    'PRES_ENRG_USE_CAP'     -- Utilisation capacite energie
);

UPDATE rf.indicators SET indicator_group = 'PRESSION' WHERE code IN (
    'PRES_OIL_RENTS',       -- Rentes petrolieres
    'PRES_GAS_RENTS',       -- Rentes gazières
    'PRES_FOSSIL_RENTS_EIA', -- Rentes fossiles totales EIA
    'PRES_EN_STABILITY',    -- Stabilite production energie
    'PRES_WA_VARIABILITY'   -- Variabilite ressources eau
);

-- ══ PTRA — Souverainete transport ════════════════════════════════

UPDATE rf.indicators SET indicator_group = 'PHYSIQUE' WHERE code IN (
    'PTRA_RD_TOTAL',    -- Reseau routier total
    'PTRA_RD_PAVED',    -- Routes bitumees
    'PTRA_RD_DENSITY',  -- Densite reseau routier
    'PTRA_PORT_CAP',    -- Capacite portuaire
    'PTRA_AIR_AIRPORTS' -- Nombre aeroports
);

UPDATE rf.indicators SET indicator_group = 'EXPLOITATION' WHERE code IN (
    'PTRA_AIR_PASSENGERS', -- Passagers aeriens
    'PTRA_AIR_CARGO',      -- Fret aerien
    'PTRA_AIR_CONNECT',    -- Connectivite aerienne
    'PTRA_AIR_HUB',        -- Hubs aeriens
    'PTRA_PORT_CONNECT',   -- Connectivite portuaire
    'PTRA_LOG_LPI',        -- Indice performance logistique
    'PTRA_MULTI'           -- Multimodalite
);

UPDATE rf.indicators SET indicator_group = 'PRESSION' WHERE code IN (
    'PTRA_RD_QUALITY',   -- Qualite routes
    'PTRA_RD_CONNECT',   -- Connectivite routiere
    'PTRA_RD_STABILITY'  -- Stabilite reseau routier
);

-- Verification finale
SELECT indicator_group, COUNT(*) as nb
FROM rf.indicators
WHERE is_active = true
GROUP BY indicator_group
ORDER BY indicator_group NULLS LAST;
