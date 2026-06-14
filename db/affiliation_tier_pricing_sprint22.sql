-- OSA Observatory — Grille tarifaire differenciee — Sprint 22
-- Date : 12 juin 2026

ALTER TABLE rf.affiliations
ADD COLUMN IF NOT EXISTS affiliation_tier varchar(30)
    CHECK (affiliation_tier IN ('PUBLIC','SUBSCRIBER','ADVANCED','STATE','DEVELOPMENT_BANK'))
    DEFAULT 'PUBLIC';

CREATE TABLE IF NOT EXISTS rf.affiliation_tier_pricing (
    tier                varchar(30) PRIMARY KEY,
    tier_label_fr       text NOT NULL,
    tier_label_en       text NOT NULL,
    monthly_fee_usd     numeric(10,2),
    annual_fee_usd      numeric(10,2),
    access_level        varchar(20) NOT NULL,
    description_fr      text,
    description_en      text,
    is_active           boolean DEFAULT true,
    available_from_year smallint,
    created_at          timestamp DEFAULT NOW()
);

INSERT INTO rf.affiliation_tier_pricing
    (tier, tier_label_fr, tier_label_en, monthly_fee_usd, annual_fee_usd,
     access_level, description_fr, description_en, available_from_year)
VALUES
('PUBLIC','Acces public gratuit','Free public access',0,0,'PUBLIC',
 'Acces libre aux scores ISA, trajectoires, alertes precoces et catalogue opportunites. Licence CC-BY-NC-4.0.',
 'Free access to ISA scores, trajectories, early warnings and opportunity catalogue. CC-BY-NC-4.0 licence.',2024),
('SUBSCRIBER','Abonne institutionnel','Institutional subscriber',NULL,NULL,'STANDARD',
 'Acces complet aux profils pays, decomposition piliers, etudes de faisabilite et POC. Disponible des 2027.',
 'Full access to country profiles, pillar breakdown, feasibility studies and POC. Available from 2027.',2027),
('ADVANCED','Acces avance sur devis','Advanced access on quote',NULL,NULL,'PREMIUM',
 'Analyses predictives souveraines, solutions alertes, API haute frequence, personnalisation pays.',
 'Sovereign predictive analysis, alert solutions, high-frequency API, country customisation.',2027),
('STATE','Gouvernement souverain africain','African sovereign government',NULL,NULL,'STANDARD',
 'Tarif souverain preferentiel pour les gouvernements et ministeres africains. Conditions sur demande.',
 'Preferential sovereign pricing for African governments and ministries. Terms on request.',2027),
('DEVELOPMENT_BANK','Partenaire de developpement','Development partner',NULL,NULL,'STANDARD',
 'BAD, Banque Mondiale, agences de developpement. Acces partenarial aux donnees ISA et analyses.',
 'AfDB, World Bank, development agencies. Partnership access to ISA data and analytics.',2027)
ON CONFLICT (tier) DO NOTHING;
