
BEGIN;

-- ============================================================
-- OSA Observatory -- Sprint 20
-- Étape 2 : rf.sovereign_project_catalog
-- Projets souverains nommés -- pays-spécifiques ou génériques
-- ============================================================

CREATE TABLE rf.sovereign_project_catalog (
    project_code         VARCHAR(60)  PRIMARY KEY,
    project_family_code  VARCHAR(40)  NOT NULL REFERENCES rf.structuring_project_catalog(project_family_code),
    pillar_code          VARCHAR(10)  NOT NULL,
    country_iso3         CHAR(3)      NULL, -- NULL = applicable à tous les pays du pilier
    project_name         TEXT         NOT NULL,
    project_acronym      VARCHAR(40)  NULL,
    project_description  TEXT         NOT NULL,
    strategic_objective  TEXT         NOT NULL,
    deliverable_public   TEXT         NOT NULL, -- note d'opportunité publique (OpenData)
    deliverable_premium  TEXT         NOT NULL, -- étude de faisabilité (Premium)
    opportunity_class    VARCHAR(40)  NOT NULL DEFAULT 'HIGH_IMPACT_OPPORTUNITY'
                         CHECK (opportunity_class IN (
                             'HIGH_IMPACT_OPPORTUNITY','SIGNIFICANT_OPPORTUNITY',
                             'UNLOCK_OPPORTUNITY','MONITORING_OPPORTUNITY')),
    priority_score       NUMERIC(5,3) NOT NULL DEFAULT 0.800,
    status               VARCHAR(30)  NOT NULL DEFAULT 'CONCEPT'
                         CHECK (status IN ('CONCEPT','FEASIBILITY','PROTOTYPE','ACTIVE','FUNDED','COMPLETED')),
    tags                 TEXT[]       NULL,
    is_active            BOOLEAN      NOT NULL DEFAULT true,
    created_at           TIMESTAMP    NOT NULL DEFAULT now(),
    updated_at           TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE INDEX idx_sovereign_project_pillar   ON rf.sovereign_project_catalog (pillar_code);
CREATE INDEX idx_sovereign_project_country  ON rf.sovereign_project_catalog (country_iso3);
CREATE INDEX idx_sovereign_project_family   ON rf.sovereign_project_catalog (project_family_code);
CREATE INDEX idx_sovereign_project_class    ON rf.sovereign_project_catalog (opportunity_class);
CREATE INDEX idx_sovereign_project_active   ON rf.sovereign_project_catalog (is_active) WHERE is_active = true;

-- ── Projets nommés par Théo Bakang + recommandations P7J ──────

-- PMIN — Chaîne de valeur minière
INSERT INTO rf.sovereign_project_catalog VALUES
('SNCTM_GENERIC','MINING_VALUE_CHAIN','PMIN',NULL,
 'Système Numérique de Certification et Traçabilité des Minerais',
 'SNCTM',
 'Plateforme blockchain de certification et traçabilité des minerais critiques depuis l extraction jusqu à l exportation. Garantit la souveraineté sur la chaîne de valeur minière.',
 'Transformer l avantage physique en souveraineté économique et réduire la fuite de valeur minière.',
 'Note d opportunité SNCTM -- accès public OSA Observatory',
 'Étude de faisabilité technique SNCTM + prototype certification blockchain',
 'HIGH_IMPACT_OPPORTUNITY', 0.950, 'CONCEPT',
 ARRAY['blockchain','certification','minerais','traçabilité','souveraineté'], true, now(), now()),

('FST_GENERIC','MINING_VALUE_CHAIN','PMIN',NULL,
 'Fonds Souverain Tokenisé sur les Ressources Minières',
 'FST',
 'Mécanisme de tokenisation des revenus miniers en actifs numériques souverains. Permet une gestion transparente et traçable des fonds d accumulation issus de l exploitation minière.',
 'Créer un mécanisme souverain d épargne et d investissement ancré sur les ressources physiques certifiées.',
 'Note d opportunité Fonds Souverain Tokenisé -- OSA Observatory',
 'Étude de faisabilité FST + architecture tokenisation + cadre réglementaire',
 'HIGH_IMPACT_OPPORTUNITY', 0.920, 'CONCEPT',
 ARRAY['tokenisation','fonds souverain','minerais','finance','blockchain'], true, now(), now()),

('LAB_CERTIFICATION_GENERIC','MINING_VALUE_CHAIN','PMIN',NULL,
 'Laboratoire Africain de Certification des Minerais',
 'LACM',
 'Réseau de laboratoires régionaux indépendants pour la certification physique et chimique des minerais critiques. Réduit la dépendance aux certifications occidentales.',
 'Souveraineté analytique sur la qualité et la valeur des ressources extractives.',
 'Note d opportunité certification minière -- OSA Observatory',
 'Étude de faisabilité réseau laboratoires + normes africaines certification',
 'SIGNIFICANT_OPPORTUNITY', 0.870, 'CONCEPT',
 ARRAY['laboratoire','certification','minerais','normes'], true, now(), now()),

-- PHUM — Capital humain
('G2P_GENERIC','HUMAN_CAPITAL','PHUM',NULL,
 'Plateforme G2P de Transferts Sociaux Souverains',
 'G2P-Africa',
 'Infrastructure numérique souveraine de transferts Government-to-Person. Distribue directement les aides sociales aux citoyens via identité numérique, sans intermédiaire bancaire traditionnel.',
 'Réduire les fragilités humaines et renforcer la résilience sociale par des transferts directs et traçables.',
 'Note d opportunité G2P souverain -- OSA Observatory',
 'Étude de faisabilité G2P + architecture identité numérique + pilote pays',
 'HIGH_IMPACT_OPPORTUNITY', 0.900, 'CONCEPT',
 ARRAY['G2P','transferts sociaux','identité numérique','inclusion financière'], true, now(), now()),

('RSR_GENERIC','HUMAN_CAPITAL','PHUM',NULL,
 'Registre Social Souverain Africain',
 'RSS',
 'Base de données nationale unifiée des bénéficiaires de programmes sociaux. Fondation technique du G2P. Garantit la non-duplication, la traçabilité et la souveraineté des données sociales.',
 'Construire la fondation data des programmes de protection sociale souveraine.',
 'Note d opportunité registre social -- OSA Observatory',
 'Étude de faisabilité RSS + interopérabilité systèmes existants',
 'SIGNIFICANT_OPPORTUNITY', 0.860, 'CONCEPT',
 ARRAY['registre social','protection sociale','données','souveraineté'], true, now(), now()),

-- PECO — Diversification économique
('UMOJA_DPI_AGRI','ECONOMIC_DIVERSIFICATION','PECO',NULL,
 'UMOJA-DPI Agriculture -- Plateforme Numérique Agricole Souveraine',
 'UMOJA-DPI',
 'Infrastructure numérique publique pour la chaîne de valeur agricole africaine. Couvre la traçabilité des intrants, la certification des productions, les marchés numériques et le financement agricole souverain.',
 'Réduire la dépendance aux plateformes étrangères et créer de la valeur ajoutée agricole souveraine.',
 'Note d opportunité UMOJA-DPI Agriculture -- OSA Observatory',
 'Étude de faisabilité UMOJA-DPI + architecture DPI + pilote filière',
 'HIGH_IMPACT_OPPORTUNITY', 0.890, 'CONCEPT',
 ARRAY['agriculture','DPI','numérique','filière','souveraineté'], true, now(), now()),

('ECADASTRE_GENERIC','ECONOMIC_DIVERSIFICATION','PECO',NULL,
 'ECadastre -- Cadastre Foncier Numérique Souverain',
 'ECadastre',
 'Plateforme numérique souveraine de gestion et certification du foncier. Réduit les conflits fonciers, sécurise les droits de propriété et permet la valorisation du capital foncier national.',
 'Sécuriser les droits fonciers et transformer le capital foncier en levier de développement souverain.',
 'Note d opportunité ECadastre -- OSA Observatory',
 'Étude de faisabilité ECadastre + architecture SIG souverain + pilote régional',
 'HIGH_IMPACT_OPPORTUNITY', 0.880, 'CONCEPT',
 ARRAY['foncier','cadastre','SIG','propriété','souveraineté'], true, now(), now()),

-- PNUM — Souveraineté numérique
('OSA_OBSERVATORY_REPLICA','DIGITAL_SOVEREIGNTY','PNUM',NULL,
 'Observatoire National de Souveraineté -- Réplication OSA',
 'ONS',
 'Déclinaison nationale de l Observatoire OSA pour un suivi en temps réel des indicateurs de souveraineté au niveau infra-national (régions, secteurs). Renforce la capacité analytique souveraine.',
 'Étendre la capacité d observation souveraine au niveau national et infranational.',
 'Note d opportunité Observatoire National -- OSA Observatory',
 'Étude de faisabilité ONS + architecture données + partenariat OSA',
 'HIGH_IMPACT_OPPORTUNITY', 0.900, 'CONCEPT',
 ARRAY['observatoire','données','souveraineté','analytique','gouvernance'], true, now(), now()),

('GOVTECH_PLATFORM','DIGITAL_SOVEREIGNTY','PNUM',NULL,
 'Plateforme GovTech Souveraine',
 'GovTech-AF',
 'Écosystème de services numériques gouvernementaux souverains : identité numérique, signature électronique, paiements publics, interopérabilité administrative. Réduit la dépendance aux solutions propriétaires étrangères.',
 'Construire l infrastructure numérique de l État souverain africain.',
 'Note d opportunité GovTech souveraine -- OSA Observatory',
 'Étude de faisabilité GovTech + architecture open source + pilote administration',
 'HIGH_IMPACT_OPPORTUNITY', 0.880, 'CONCEPT',
 ARRAY['GovTech','identité numérique','administration','open source','souveraineté'], true, now(), now()),

-- PENV — Résilience environnementale (top P7J : 36 pays CRITICAL)
('BOURSE_CARBONE_AF','ENVIRONMENTAL_RESILIENCE','PENV',NULL,
 'Bourse Carbone Africaine Souveraine',
 'BCA',
 'Mécanisme africain souverain d échange de crédits carbone. Permet aux États africains de valoriser leurs stocks naturels (forêts, mangroves, sols) sans dépendance aux marchés carbone occidentaux.',
 'Monétiser les actifs environnementaux africains tout en finançant la résilience climatique.',
 'Note d opportunité Bourse Carbone Africaine -- OSA Observatory',
 'Étude de faisabilité BCA + cadre réglementaire + pilote pays forestier',
 'HIGH_IMPACT_OPPORTUNITY', 0.940, 'CONCEPT',
 ARRAY['carbone','climat','forêt','finance verte','souveraineté'], true, now(), now()),

('CADASTRE_CLIMATIQUE','ENVIRONMENTAL_RESILIENCE','PENV',NULL,
 'Cadastre Foncier Climatique Africain',
 'CFC',
 'Cartographie souveraine des risques climatiques sur le foncier africain. Identifie les zones à risque inondation, désertification, stress hydrique pour orienter les politiques d adaptation.',
 'Réduire la vulnérabilité foncière et climatique par une cartographie souveraine des risques.',
 'Note d opportunité Cadastre Climatique -- OSA Observatory',
 'Étude de faisabilité CFC + architecture SIG climatique + partenariat satellitaire',
 'HIGH_IMPACT_OPPORTUNITY', 0.920, 'CONCEPT',
 ARRAY['climat','foncier','cartographie','risque','adaptation'], true, now(), now()),

-- PTRA — Transport et logistique (33 pays CRITICAL)
('CORRIDOR_NUMERIQUE_AF','TRANSPORT_LOGISTICS','PTRA',NULL,
 'Corridor Numérique Panafricain',
 'CNA',
 'Infrastructure de fibre optique souveraine reliant les grandes métropoles africaines. Réduit le routage du trafic internet africain via l Europe et permet des tarifs souverains.',
 'Réduire la dépendance aux infrastructures télécom étrangères et créer une connectivité numérique africaine.',
 'Note d opportunité Corridor Numérique -- OSA Observatory',
 'Étude de faisabilité CNA + cartographie infrastructure + modèle financement',
 'HIGH_IMPACT_OPPORTUNITY', 0.910, 'CONCEPT',
 ARRAY['fibre optique','connectivité','internet','infrastructure','souveraineté'], true, now(), now()),

('HUB_LOGISTIQUE_SOUVERAIN','TRANSPORT_LOGISTICS','PTRA',NULL,
 'Hub Logistique Souverain Africain',
 'HLS',
 'Plateforme logistique multimodale souveraine dans les nœuds stratégiques africains. Réduit les coûts de transit, crée de la valeur logistique locale et renforce les corridors de commerce intra-africain.',
 'Renforcer la compétitivité logistique africaine et réduire les dépendances aux opérateurs étrangers.',
 'Note d opportunité Hub Logistique Souverain -- OSA Observatory',
 'Étude de faisabilité HLS + analyse corridors + modèle PPP souverain',
 'HIGH_IMPACT_OPPORTUNITY', 0.900, 'CONCEPT',
 ARRAY['logistique','transport','corridor','hub','commerce'], true, now(), now()),

-- PRES — Énergie-eau (23 pays CRITICAL)
('RESEAU_EAU_CERTIFIE','ENERGY_WATER_CERTIFICATION','PRES',NULL,
 'Réseau Eau Certifié Souverain',
 'RECS',
 'Système de certification et de monitoring en temps réel des ressources en eau souveraines. Combine IoT, données satellitaires et gouvernance locale pour une gestion souveraine de l eau.',
 'Certifier les données hydrologiques et structurer la gouvernance souveraine de l eau.',
 'Note d opportunité Réseau Eau Certifié -- OSA Observatory',
 'Étude de faisabilité RECS + architecture IoT eau + protocole certification',
 'HIGH_IMPACT_OPPORTUNITY', 0.930, 'CONCEPT',
 ARRAY['eau','certification','IoT','ressources','souveraineté'], true, now(), now()),

('MINIGRIDS_SOUVERAINS','ENERGY_WATER_CERTIFICATION','PRES',NULL,
 'Mini-Grids Énergétiques Souverains',
 'MGS',
 'Réseau décentralisé de micro-centrales énergétiques souveraines (solaire, hydro, biomasse) pour les zones rurales et péri-urbaines. Réduit la dépendance énergétique et les importations de combustibles.',
 'Garantir l accès souverain à l énergie dans les zones non connectées au réseau national.',
 'Note d opportunité Mini-Grids Souverains -- OSA Observatory',
 'Étude de faisabilité MGS + cartographie énergétique + modèle financement décentralisé',
 'HIGH_IMPACT_OPPORTUNITY', 0.910, 'CONCEPT',
 ARRAY['énergie','solaire','décentralisé','rural','souveraineté'], true, now(), now()),

-- PMON — Résilience monétaire
('CHAMBRE_COMPENSATION_AF','MONETARY_FINANCIAL_RESILIENCE','PMON',NULL,
 'Chambre de Compensation Régionale Africaine',
 'CCRA',
 'Mécanisme africain de règlement des transactions intra-africaines en monnaies locales. Réduit la dépendance au dollar et à l euro dans les échanges commerciaux africains.',
 'Réduire la vulnérabilité au risque de change et renforcer la souveraineté monétaire africaine.',
 'Note d opportunité Chambre Compensation -- OSA Observatory',
 'Étude de faisabilité CCRA + architecture SWIFT alternatif + cadre réglementaire UA',
 'HIGH_IMPACT_OPPORTUNITY', 0.920, 'CONCEPT',
 ARRAY['monnaie','compensation','change','souveraineté','finance'], true, now(), now()),

-- PGEO — Gouvernance
('OBS_GOUVERNANCE_TERRITORIALE','GOVERNANCE_CAPACITY','PGEO',NULL,
 'Observatoire de Gouvernance Territoriale',
 'OGT',
 'Plateforme de monitoring en temps réel de la gouvernance territoriale africaine. Combine données ACLED, indicateurs institutionnels et signaux AMAR pour une alerte précoce sur les crises de gouvernance.',
 'Renforcer la capacité d anticipation et de réaction institutionnelle face aux crises de gouvernance.',
 'Note d opportunité Observatoire Gouvernance -- OSA Observatory',
 'Étude de faisabilité OGT + architecture données + partenariat ACLED/UA',
 'SIGNIFICANT_OPPORTUNITY', 0.870, 'CONCEPT',
 ARRAY['gouvernance','territoriale','alerte','ACLED','institution'], true, now(), now()),

-- PMIL — Sécurité
('SYSTEME_ALERTE_AMAR','SECURITY_RESILIENCE','PMIL',NULL,
 'Système d Alerte Précoce AMAR -- Déploiement National',
 'AMAR-NAT',
 'Déclinaison nationale du moteur AMAR d OSA Observatory. Permet à un État de monitorer en temps réel les précurseurs d atrocités et de conflits sur son territoire avec une granularité infranationale.',
 'Renforcer la capacité d anticipation sécuritaire souveraine et réduire les risques d atrocités.',
 'Note d opportunité AMAR National -- OSA Observatory',
 'Étude de faisabilité AMAR-NAT + architecture données + protocole réponse',
 'HIGH_IMPACT_OPPORTUNITY', 0.940, 'CONCEPT',
 ARRAY['sécurité','alerte précoce','AMAR','conflit','prévention'], true, now(), now());

COMMENT ON TABLE rf.sovereign_project_catalog IS
    'Catalogue des projets souverains nommés -- OSA Observatory Sprint 20. '
    'Projets pays-spécifiques ou génériques (country_iso3 NULL = applicable à tous). '
    'Liés à rf.structuring_project_catalog par project_family_code. '
    'Un INSERT = un projet. Jamais de code change.';

COMMIT;
