-- ============================================================
-- Ajout ADR-008 (OSOA) au registre -- jamais numerote formellement
-- dans aucun document recu, contrairement a GTM (005), pilier par
-- pilier (006), OIM (007). Mise a jour ADR-007 -- raccordement
-- externe complete.
-- 17 juillet 2026
-- ============================================================

BEGIN;

INSERT INTO rf.adr_registry (adr_code, title_fr, title_en, status, former_codes, related_finding_code, document_path, decided_on, description, needs_completion) VALUES
('ADR-008', 'OSA Strategic Opportunity Assessment (OSOA)', 'OSA Strategic Opportunity Assessment (OSOA)',
 'ACCEPTED', NULL, NULL, 'gaf/sql/osoa_phase1_schema.sql', '2026-07-17',
 'Moteur d''evaluation des opportunites d''engagement d''OSA lui-meme (appels d''offres, financements, partenariats) -- distinct d''ADR-006/007 qui etudient les pays africains. Deux sources d''entree symetriques : interne (Famille de projets compatibles issue d''OIM) et externe (AMI/DP/AO qualifie par un client tiers, avec KYC propre, distinct de mg.affiliates). Pas de mecanisme de paiement -- negociation contractuelle, livraison = produit intellectuel du travail d''analyse OSOA (Decision Products du catalogue GTM, ADR-005). Phase 1 (osoa.opportunities, strategic_analyses, scenarios, recommendations, validations, clients, document_deposits, contracts + 2 referentiels rf) construite, testee bout en bout (chemin interne ET externe), deployee sur DEV/PREPROD/PROD le 17 juillet 2026. Aucun rattachement a un organe de gouvernance doctrinal -- explicitement non tranche par le Volume 0 OSOA (Encadre 8.1), a trancher lors d''une future revision. Gestion documentaire detaillee (Phase 2 complete) et retour d''experience (Phase 8) volontairement hors perimetre de cette premiere increment.',
 false)
ON CONFLICT (adr_code) DO NOTHING;

UPDATE rf.adr_registry SET
    description = description || ' Chemin externe complete le 17 juillet 2026 : mg.transformation_requirements.opportunity_id relie desormais a osoa.opportunities (ADR-008), teste bout en bout jusqu''a un patron d''intervention partage avec le chemin interne.'
WHERE adr_code = 'ADR-007';

COMMIT;

SELECT adr_code, status FROM rf.adr_registry ORDER BY adr_code;
