BEGIN;

CREATE TABLE IF NOT EXISTS rf.isa_intervention_family_registry (
    intervention_family_code        TEXT PRIMARY KEY,
    pillar_code                     TEXT NOT NULL,
    intervention_family_label       TEXT NOT NULL,
    strategic_domain                TEXT,
    infrastructure_intensity        NUMERIC(5,3),
    governance_complexity           NUMERIC(5,3),
    sovereign_dependency_score      NUMERIC(5,3),
    budget_intensity_score          NUMERIC(5,3),
    implementation_horizon_years    INTEGER,
    executive_track_default         TEXT,
    created_at                      TIMESTAMP DEFAULT NOW()
);

DELETE FROM rf.isa_intervention_family_registry;

INSERT INTO rf.isa_intervention_family_registry VALUES

-- PRES
('ENERGY_WATER_CERTIFICATION','PRES','Energy & Water Certification','ENERGY',0.90,0.70,0.60,0.85,5,'HIGH_PRIORITY_PORTFOLIO',NOW()),
('GRID_RESILIENCE','PRES','Grid Resilience Programme','ENERGY',0.88,0.68,0.55,0.82,6,'HIGH_PRIORITY_PORTFOLIO',NOW()),
('STRATEGIC_DAMS','PRES','Strategic Water Dams','WATER',0.95,0.80,0.40,0.92,8,'EXECUTIVE_BOARD',NOW()),
('ENERGY_STORAGE','PRES','Strategic Energy Storage','ENERGY',0.78,0.66,0.70,0.74,4,'STANDARD_PROGRAMME',NOW()),
('REGIONAL_POWER_POOL','PRES','Regional Power Pool','ENERGY',0.84,0.74,0.78,0.81,7,'EXECUTIVE_BOARD',NOW()),

-- PMON
('MONETARY_STABILIZATION','PMON','Monetary Stabilization','FINANCE',0.30,0.90,0.88,0.52,3,'EXECUTIVE_BOARD',NOW()),
('RESERVE_PROTECTION','PMON','Reserve Protection','FINANCE',0.25,0.84,0.82,0.44,2,'HIGH_PRIORITY_PORTFOLIO',NOW()),
('PAYMENT_SOVEREIGNTY','PMON','Payment Sovereignty','FINTECH',0.50,0.70,0.75,0.56,4,'STANDARD_PROGRAMME',NOW()),
('CBDC_INFRA','PMON','CBDC Infrastructure','FINTECH',0.66,0.74,0.80,0.62,5,'STANDARD_PROGRAMME',NOW()),
('BANKING_RESILIENCE','PMON','Banking Resilience','BANKING',0.42,0.76,0.65,0.48,3,'STANDARD_PROGRAMME',NOW()),

-- PNUM
('DIGITAL_IDENTITY','PNUM','Digital Identity Infrastructure','DIGITAL',0.72,0.64,0.74,0.61,4,'HIGH_PRIORITY_PORTFOLIO',NOW()),
('CYBER_SOVEREIGNTY','PNUM','Cyber Sovereignty','CYBER',0.64,0.84,0.68,0.57,4,'HIGH_PRIORITY_PORTFOLIO',NOW()),
('SOVEREIGN_CLOUD','PNUM','Sovereign Cloud Infrastructure','DIGITAL',0.80,0.73,0.71,0.76,5,'EXECUTIVE_BOARD',NOW()),
('DATA_GOVERNANCE','PNUM','National Data Governance','DIGITAL',0.40,0.79,0.66,0.39,3,'STANDARD_PROGRAMME',NOW()),
('DIGITAL_G2P','PNUM','Digital G2P Infrastructure','DIGITAL',0.70,0.71,0.62,0.59,4,'STANDARD_PROGRAMME',NOW());

COMMIT;