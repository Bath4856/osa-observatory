-- OSA Observatory — Traduction project_family_label EN/FR — Sprint 22
ALTER TABLE rf.structuring_project_catalog
ADD COLUMN IF NOT EXISTS project_family_label_en text,
ADD COLUMN IF NOT EXISTS project_family_label_fr text;

UPDATE rf.structuring_project_catalog SET project_family_label_fr = project_family_label;

UPDATE rf.structuring_project_catalog SET project_family_label_en = 'Economic diversification'            WHERE project_family_code = 'ECONOMIC_DIVERSIFICATION';
UPDATE rf.structuring_project_catalog SET project_family_label_en = 'Environmental resilience'            WHERE project_family_code = 'ENVIRONMENTAL_RESILIENCE';
UPDATE rf.structuring_project_catalog SET project_family_label_en = 'Governance and stability'            WHERE project_family_code = 'GOVERNANCE_CAPACITY';
UPDATE rf.structuring_project_catalog SET project_family_label_en = 'Human capital and social resilience' WHERE project_family_code = 'HUMAN_CAPITAL';
UPDATE rf.structuring_project_catalog SET project_family_label_en = 'Security and defence resilience'     WHERE project_family_code = 'SECURITY_RESILIENCE';
UPDATE rf.structuring_project_catalog SET project_family_label_en = 'Mining value chain'                  WHERE project_family_code = 'MINING_VALUE_CHAIN';
UPDATE rf.structuring_project_catalog SET project_family_label_en = 'Monetary and financial resilience'   WHERE project_family_code = 'MONETARY_FINANCIAL_RESILIENCE';
UPDATE rf.structuring_project_catalog SET project_family_label_en = 'Digital sovereignty'                 WHERE project_family_code = 'DIGITAL_SOVEREIGNTY';
UPDATE rf.structuring_project_catalog SET project_family_label_en = 'Energy and water certification'      WHERE project_family_code = 'ENERGY_WATER_CERTIFICATION';
UPDATE rf.structuring_project_catalog SET project_family_label_en = 'Transport and sovereign logistics'   WHERE project_family_code = 'TRANSPORT_LOGISTICS';
