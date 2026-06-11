-- OSA Observatory — Traduction EN des 18 projets souverains
-- Sprint 21 — juin 2026
-- Migration : ajout colonnes bilingues + traductions anglaises
-- rf.sovereign_project_catalog

-- 1. Migration schéma (idempotente)
ALTER TABLE rf.sovereign_project_catalog
ADD COLUMN IF NOT EXISTS project_name_fr        text,
ADD COLUMN IF NOT EXISTS project_name_en        text,
ADD COLUMN IF NOT EXISTS project_description_fr text,
ADD COLUMN IF NOT EXISTS project_description_en text,
ADD COLUMN IF NOT EXISTS strategic_objective_fr text,
ADD COLUMN IF NOT EXISTS strategic_objective_en text,
ADD COLUMN IF NOT EXISTS deliverable_public_fr  text,
ADD COLUMN IF NOT EXISTS deliverable_public_en  text;

-- 2. Copier FR existant (idempotente)
UPDATE rf.sovereign_project_catalog
SET project_name_fr        = COALESCE(project_name_fr, project_name),
    project_description_fr = COALESCE(project_description_fr, project_description),
    strategic_objective_fr = COALESCE(strategic_objective_fr, strategic_objective),
    deliverable_public_fr  = COALESCE(deliverable_public_fr, deliverable_public);

-- 3. Traductions anglaises
UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'ECadastre -- Sovereign Digital Land Registry',
    project_description_en = 'Sovereign digital platform for land management and certification. Reduces land conflicts and strengthens property rights through transparent, immutable registration of land titles across African territories.',
    strategic_objective_en = 'Establish a sovereign, auditable digital land registry to secure property rights and reduce land-related conflicts.',
    deliverable_public_en  = 'Opportunity note ECadastre -- OSA Observatory'
WHERE project_acronym = 'ECadastre';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'UMOJA-DPI Agriculture -- Sovereign Digital Agricultural Platform',
    project_description_en = 'Sovereign public digital infrastructure for the African agricultural value chain. Covers traceability from farm to export, connects producers to markets, and enables real-time monitoring of food sovereignty indicators.',
    strategic_objective_en = 'Build a sovereign digital backbone for African agricultural value chains, reducing dependency on foreign intermediaries.',
    deliverable_public_en  = 'Opportunity note UMOJA-DPI -- OSA Observatory'
WHERE project_acronym = 'UMOJA-DPI';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'African Sovereign Carbon Exchange',
    project_description_en = 'African sovereign mechanism for carbon credit trading. Enables African states to valorise their natural assets (forests, mangroves, wetlands) through a sovereign, non-dependent carbon market infrastructure.',
    strategic_objective_en = 'Create a sovereign African carbon market that captures value for African states rather than exporting it to foreign financial intermediaries.',
    deliverable_public_en  = 'Opportunity note BCA -- OSA Observatory'
WHERE project_acronym = 'BCA';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'African Climate Land Registry',
    project_description_en = 'Sovereign mapping of climate risks on African land assets. Identifies high-risk zones, tracks land degradation, and provides actionable data for climate adaptation and sovereign resource planning.',
    strategic_objective_en = 'Build a sovereign climate-land information system to support evidence-based adaptation policies across African states.',
    deliverable_public_en  = 'Opportunity note CFC -- OSA Observatory'
WHERE project_acronym = 'CFC';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'Territorial Governance Observatory',
    project_description_en = 'Real-time monitoring platform for African territorial governance. Combines ACLED conflict data, governance indicators, and sovereign metrics to provide actionable alerts for decision-makers.',
    strategic_objective_en = 'Provide African states with a sovereign territorial governance monitoring tool grounded in verifiable behavioural data.',
    deliverable_public_en  = 'Opportunity note OGT -- OSA Observatory'
WHERE project_acronym = 'OGT';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'G2P Africa -- Sovereign Social Transfer Platform',
    project_description_en = 'Sovereign digital infrastructure for Government-to-Person transfers. Delivers social assistance directly to beneficiaries, eliminating intermediaries and reducing leakage of public resources.',
    strategic_objective_en = 'Build a sovereign, auditable G2P payment infrastructure that maximises the reach and integrity of social protection systems.',
    deliverable_public_en  = 'Opportunity note G2P-Africa -- OSA Observatory'
WHERE project_acronym = 'G2P-Africa';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'African Sovereign Social Registry',
    project_description_en = 'Unified national database of social programme beneficiaries. Technical foundation for the G2P-Africa platform, enabling cross-programme coordination and eliminating duplicate registrations.',
    strategic_objective_en = 'Establish a single, sovereign source of truth for social beneficiary data, enabling efficient and transparent social protection delivery.',
    deliverable_public_en  = 'Opportunity note RSS -- OSA Observatory'
WHERE project_acronym = 'RSS';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'AMAR Early Warning System -- National Deployment',
    project_description_en = 'National deployment of the OSA Observatory AMAR engine. Enables a state to monitor in real time the behavioural precursors of atrocities and conflicts, and activate early response protocols.',
    strategic_objective_en = 'Provide national authorities with a sovereign early warning capability grounded in the OSA AMAR doctrine.',
    deliverable_public_en  = 'Opportunity note AMAR-NAT -- OSA Observatory'
WHERE project_acronym = 'AMAR-NAT';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'Sovereign Tokenised Fund on Mineral Resources',
    project_description_en = 'Tokenisation mechanism for mining revenues as sovereign digital assets. Enables transparent, traceable management of accumulation funds derived from mineral extraction, anchored to certified physical resources.',
    strategic_objective_en = 'Create a sovereign savings and investment mechanism anchored to certified physical mineral resources.',
    deliverable_public_en  = 'Opportunity note FST -- OSA Observatory'
WHERE project_acronym = 'FST';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'African Mineral Certification Laboratory',
    project_description_en = 'Network of independent regional laboratories for physical and chemical certification of minerals. Provides sovereign, verifiable proof of mineral origin and quality, supporting EITI compliance and export credibility.',
    strategic_objective_en = 'Build a sovereign African mineral certification infrastructure that reduces dependency on foreign assay houses.',
    deliverable_public_en  = 'Opportunity note LACM -- OSA Observatory'
WHERE project_acronym = 'LACM';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'Sovereign Digital Mineral Certification and Traceability System',
    project_description_en = 'Blockchain platform for certification and traceability of critical minerals from extraction to export. Guarantees sovereign control over the mineral value chain and supports conflict-free mineral certification.',
    strategic_objective_en = 'Establish a sovereign, blockchain-based traceability system for critical minerals across the full value chain.',
    deliverable_public_en  = 'Opportunity note SNCTM -- OSA Observatory'
WHERE project_acronym = 'SNCTM';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'African Regional Clearing Chamber',
    project_description_en = 'African mechanism for settling intra-African transactions in local currencies. Reduces dependency on the US dollar and euro for intra-continental trade, strengthening monetary sovereignty.',
    strategic_objective_en = 'Build a sovereign African payment and clearing infrastructure that reduces foreign currency dependency for intra-African trade.',
    deliverable_public_en  = 'Opportunity note CCRA -- OSA Observatory'
WHERE project_acronym = 'CCRA';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'Sovereign GovTech Platform',
    project_description_en = 'Ecosystem of sovereign government digital services: digital identity, electronic signature, e-procurement, and open data. Reduces dependency on foreign technology providers for critical public infrastructure.',
    strategic_objective_en = 'Build a sovereign African GovTech stack that ensures digital independence for core government functions.',
    deliverable_public_en  = 'Opportunity note GovTech-AF -- OSA Observatory'
WHERE project_acronym = 'GovTech-AF';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'National Sovereignty Observatory -- OSA Replication',
    project_description_en = 'National replication of the OSA Observatory for real-time monitoring of sovereignty indicators. Provides governments with a sovereign analytical tool calibrated to their national context.',
    strategic_objective_en = 'Enable African states to operate a sovereign, nationally-calibrated observatory aligned with the OSA ISA methodology.',
    deliverable_public_en  = 'Opportunity note ONS -- OSA Observatory'
WHERE project_acronym = 'ONS';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'Sovereign Energy Mini-Grids',
    project_description_en = 'Decentralised network of sovereign micro energy plants (solar, hydro, biomass) for rural electrification. Reduces energy dependency on national grids and foreign suppliers while building local energy sovereignty.',
    strategic_objective_en = 'Achieve sovereign energy access for underserved African communities through decentralised, locally-owned energy infrastructure.',
    deliverable_public_en  = 'Opportunity note MGS -- OSA Observatory'
WHERE project_acronym = 'MGS';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'Sovereign Certified Water Network',
    project_description_en = 'Certification and real-time monitoring system for sovereign water resources. Combines IoT sensors, satellite data, and sovereign analytics to track water availability, quality, and usage across African territories.',
    strategic_objective_en = 'Build a sovereign water monitoring and certification infrastructure to support evidence-based water sovereignty policies.',
    deliverable_public_en  = 'Opportunity note RECS -- OSA Observatory'
WHERE project_acronym = 'RECS';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'Pan-African Digital Corridor',
    project_description_en = 'Sovereign fibre optic infrastructure connecting major African metropolises. Reduces routing of African internet traffic through foreign nodes, lowering costs and strengthening digital sovereignty.',
    strategic_objective_en = 'Build a sovereign pan-African digital backbone that keeps African data traffic on African infrastructure.',
    deliverable_public_en  = 'Opportunity note CNA -- OSA Observatory'
WHERE project_acronym = 'CNA';

UPDATE rf.sovereign_project_catalog SET
    project_name_en = 'African Sovereign Logistics Hub',
    project_description_en = 'Sovereign multimodal logistics platform at strategic African nodes. Reduces logistics costs, eliminates dependency on foreign operators, and captures value from intra-African trade flows.',
    strategic_objective_en = 'Build sovereign logistics infrastructure at key African trade nodes to reduce costs and capture value from intra-continental trade.',
    deliverable_public_en  = 'Opportunity note HLS -- OSA Observatory'
WHERE project_acronym = 'HLS';
