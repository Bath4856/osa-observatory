-- ============================================================
-- osoa.document_deposits -- ajout procurement_stage + outcome
-- 24 juillet 2026
-- ============================================================
-- procurement_stage (AMI/AO/AOI/DP) est DISTINCT de document_type
-- (REFERENCE/INSTITUTIONNEL/FINANCIER/TECHNIQUE/JURIDIQUE/
-- SCIENTIFIQUE, deja existant) -- ce dernier decrit la NATURE du
-- contenu (TECHNIQUE/FINANCIER correspondent aux parties PT/PF
-- d'une DP), procurement_stage decrit l'ETAPE du cycle. Collision
-- de nom evitee de justesse le 24 juillet 2026 -- verifie en base
-- avant de coder.
--
-- outcome capture le resultat de CE depot precis (pas de
-- l'opportunite globale) : SHORTLISTED/REJECTED pour AMI (se clot a
-- la shortlist), RETAINED/ELIMINATED pour AO/AOI/DP (se clot au
-- resultat de negociation). Une opportunite peut recevoir plusieurs
-- depots successifs dans le temps (ex. AMI puis DP une fois
-- shortlistee) -- chaque depot garde son propre type/issue, rien
-- n'est ecrase (doctrine de tracabilite).
--
-- Le statut de osoa.opportunities (ACTIVE/CLOSED/ABANDONED) se
-- deduira automatiquement de l'issue du dernier depot, cote
-- applicatif (pas de trigger SQL -- logique dans l'endpoint pour
-- rester lisible et testable).
--
-- A executer DEV -> PREPROD -> PROD.
-- ============================================================

BEGIN;

ALTER TABLE osoa.document_deposits
    ADD COLUMN procurement_stage character varying(10) NOT NULL;

ALTER TABLE osoa.document_deposits
    ADD CONSTRAINT document_deposits_procurement_stage_check
    CHECK (procurement_stage IN ('AMI', 'AO', 'AOI', 'DP'));

ALTER TABLE osoa.document_deposits
    ADD COLUMN outcome character varying(20);

ALTER TABLE osoa.document_deposits
    ADD CONSTRAINT document_deposits_outcome_check CHECK (
        outcome IS NULL
        OR (procurement_stage = 'AMI' AND outcome IN ('SHORTLISTED', 'REJECTED'))
        OR (procurement_stage IN ('AO', 'AOI', 'DP') AND outcome IN ('RETAINED', 'ELIMINATED'))
    );

COMMIT;

-- Verification post-execution
\d osoa.document_deposits
