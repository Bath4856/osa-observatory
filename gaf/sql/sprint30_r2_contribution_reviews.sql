-- ============================================================
-- Sprint 30 R2 -- File d'examen des contributions
-- Architecture 3 niveaux : referentiels / politiques / workflow
-- GAF AFFILIATION_WORKFLOW_REVISION_001 -- R2
-- Date : 1 juillet 2026
-- ============================================================

BEGIN;

-- ── Niveau 1 : Referentiels ───────────────────────────────────────────────────

CREATE TABLE mg.review_steps (
    step_number    INTEGER PRIMARY KEY,
    criterion      VARCHAR(20) NOT NULL UNIQUE,
    evaluator_role VARCHAR(30) NOT NULL,
    label_fr       VARCHAR(100) NOT NULL,
    label_en       VARCHAR(100) NOT NULL,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO mg.review_steps VALUES
    (1, 'TECHNICAL',  'COMITE_TECH',    'Evaluation technique',    'Technical evaluation',  TRUE),
    (2, 'SCIENTIFIC', 'COMITE_SCI',     'Evaluation scientifique', 'Scientific evaluation', TRUE),
    (3, 'ETHICAL',    'COMITE_ETHIQUE', 'Evaluation ethique',      'Ethical evaluation',    TRUE),
    (4, 'LINGUISTIC', 'COMITE_TECH',    'Conformite linguistique', 'Linguistic compliance', TRUE);

CREATE TABLE mg.review_verdicts (
    code        VARCHAR(30) PRIMARY KEY,
    criterion   VARCHAR(20) NOT NULL,
    label_fr    VARCHAR(100) NOT NULL,
    label_en    VARCHAR(100) NOT NULL,
    is_positive BOOLEAN NOT NULL
);

INSERT INTO mg.review_verdicts VALUES
    ('FEASIBLE',             'TECHNICAL',  'Faisable',                  'Feasible',                   TRUE),
    ('INSUFFICIENT_DATA',    'TECHNICAL',  'Donnees insuffisantes',     'Insufficient data',          FALSE),
    ('RESOURCE_CONSTRAINT',  'TECHNICAL',  'Contrainte de ressources',  'Resource constraint',        FALSE),
    ('ACCEPTED',             'SCIENTIFIC', 'Acceptee',                  'Accepted',                   TRUE),
    ('TO_DEEPEN',            'SCIENTIFIC', 'A approfondir',             'To deepen',                  FALSE),
    ('MERGED',               'SCIENTIFIC', 'Fusionnee avec une autre',  'Merged with another',        FALSE),
    ('OUT_OF_SCOPE',         'SCIENTIFIC', 'Hors perimetre',            'Out of scope',               FALSE),
    ('COMPLIANT',            'ETHICAL',    'Conforme',                  'Compliant',                  TRUE),
    ('NON_COMPLIANT',        'ETHICAL',    'Non conforme',              'Non compliant',              FALSE),
    ('REVISION_REQUIRED',    'LINGUISTIC', 'Revision requise',          'Revision required',          FALSE),
    ('LINGUISTIC_COMPLIANT', 'LINGUISTIC', 'Conforme linguistiquement', 'Linguistically compliant',   TRUE);

-- ── Niveau 2 : Politiques ─────────────────────────────────────────────────────

CREATE TABLE mg.review_policies (
    id           SERIAL PRIMARY KEY,
    criterion    VARCHAR(20) NOT NULL REFERENCES mg.review_steps(criterion),
    verdict_code VARCHAR(30) NOT NULL REFERENCES mg.review_verdicts(code),
    action       VARCHAR(25) NOT NULL,
    label_fr     VARCHAR(100),
    label_en     VARCHAR(100),
    CONSTRAINT chk_policy_action
        CHECK (action IN ('NEXT', 'REQUEST_REVISION', 'STOP', 'REJECT')),
    UNIQUE (criterion, verdict_code)
);

INSERT INTO mg.review_policies (criterion, verdict_code, action, label_fr, label_en) VALUES
    ('TECHNICAL',  'FEASIBLE',             'NEXT',             'Passer a evaluation scientifique', 'Proceed to scientific evaluation'),
    ('TECHNICAL',  'INSUFFICIENT_DATA',    'REQUEST_REVISION', 'Demander donnees complementaires', 'Request additional data'),
    ('TECHNICAL',  'RESOURCE_CONSTRAINT',  'STOP',             'Suspendre -- contrainte ressources','Suspend -- resource constraint'),
    ('SCIENTIFIC', 'ACCEPTED',             'NEXT',             'Passer a evaluation ethique',      'Proceed to ethical evaluation'),
    ('SCIENTIFIC', 'TO_DEEPEN',            'REQUEST_REVISION', 'Demander approfondissement',       'Request further development'),
    ('SCIENTIFIC', 'MERGED',               'NEXT',             'Fusionner et continuer',           'Merge and continue'),
    ('SCIENTIFIC', 'OUT_OF_SCOPE',         'REJECT',           'Rejeter -- hors perimetre OSA',    'Reject -- out of OSA scope'),
    ('ETHICAL',    'COMPLIANT',            'NEXT',             'Passer a verification linguistique','Proceed to linguistic check'),
    ('ETHICAL',    'NON_COMPLIANT',        'STOP',             'Suspendre -- non conformite ethique','Suspend -- ethical non-compliance'),
    ('LINGUISTIC', 'LINGUISTIC_COMPLIANT', 'NEXT',             'Prete pour decision finale',       'Ready for final decision'),
    ('LINGUISTIC', 'REVISION_REQUIRED',    'REQUEST_REVISION', 'Retourner pour revision redactionnelle','Return for editorial revision');

-- ── Niveau 3 : Workflow ───────────────────────────────────────────────────────

CREATE TABLE mg.workflow_states (
    code        VARCHAR(35) PRIMARY KEY,
    label_fr    VARCHAR(100) NOT NULL,
    label_en    VARCHAR(100) NOT NULL,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE
);

INSERT INTO mg.workflow_states VALUES
    ('SUBMITTED',               'Soumise',                      'Submitted',              FALSE),
    ('UNDER_TECHNICAL_REVIEW',  'En evaluation technique',      'Under technical review', FALSE),
    ('UNDER_SCIENTIFIC_REVIEW', 'En evaluation scientifique',   'Under scientific review',FALSE),
    ('UNDER_ETHICAL_REVIEW',    'En evaluation ethique',        'Under ethical review',   FALSE),
    ('UNDER_LINGUISTIC_REVIEW', 'En verification linguistique', 'Under linguistic review',FALSE),
    ('DECIDED',                 'Decision rendue',              'Decision rendered',      TRUE),
    ('ARCHIVED',                'Archivee',                     'Archived',               TRUE);

CREATE TABLE mg.workflow_transitions (
    id             SERIAL PRIMARY KEY,
    from_state     VARCHAR(35) NOT NULL REFERENCES mg.workflow_states(code),
    to_state       VARCHAR(35) NOT NULL REFERENCES mg.workflow_states(code),
    trigger_action VARCHAR(25),
    label_fr       VARCHAR(100),
    label_en       VARCHAR(100)
);

INSERT INTO mg.workflow_transitions (from_state, to_state, trigger_action, label_fr, label_en) VALUES
    ('SUBMITTED',               'UNDER_TECHNICAL_REVIEW',  'NEXT', 'Demarrer evaluation technique',   'Start technical evaluation'),
    ('UNDER_TECHNICAL_REVIEW',  'UNDER_SCIENTIFIC_REVIEW', 'NEXT', 'Passer a scientifique',           'Move to scientific'),
    ('UNDER_SCIENTIFIC_REVIEW', 'UNDER_ETHICAL_REVIEW',    'NEXT', 'Passer a ethique',                'Move to ethical'),
    ('UNDER_ETHICAL_REVIEW',    'UNDER_LINGUISTIC_REVIEW', 'NEXT', 'Passer a linguistique',           'Move to linguistic'),
    ('UNDER_LINGUISTIC_REVIEW', 'DECIDED',                 'NEXT', 'Rendre decision finale',          'Render final decision'),
    ('UNDER_TECHNICAL_REVIEW',  'ARCHIVED',                'STOP', 'Archiver -- contrainte technique', 'Archive -- technical constraint'),
    ('UNDER_SCIENTIFIC_REVIEW', 'ARCHIVED',               'REJECT','Archiver -- hors perimetre',      'Archive -- out of scope'),
    ('UNDER_ETHICAL_REVIEW',    'ARCHIVED',                'STOP', 'Archiver -- non conformite ethique','Archive -- ethical issue');

CREATE TABLE mg.workflow_history (
    id                SERIAL PRIMARY KEY,
    contribution_type VARCHAR(20) NOT NULL,
    contribution_id   INTEGER NOT NULL,
    from_state        VARCHAR(35) REFERENCES mg.workflow_states(code),
    to_state          VARCHAR(35) NOT NULL REFERENCES mg.workflow_states(code),
    trigger_action    VARCHAR(25),
    affiliate_id      INTEGER REFERENCES mg.affiliates(id),
    comment           TEXT,
    transitioned_at   TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_history_type
        CHECK (contribution_type IN ('TICKET', 'PROPOSAL'))
);

CREATE INDEX idx_history_contribution ON mg.workflow_history(contribution_type, contribution_id);
CREATE INDEX idx_history_date         ON mg.workflow_history(transitioned_at DESC);

-- ── Tables d'evaluation ───────────────────────────────────────────────────────

CREATE TABLE mg.contribution_reviews (
    id                SERIAL PRIMARY KEY,
    contribution_type VARCHAR(20) NOT NULL,
    contribution_id   INTEGER NOT NULL,
    step_number       INTEGER NOT NULL REFERENCES mg.review_steps(step_number),
    criterion_code    VARCHAR(20) NOT NULL REFERENCES mg.review_steps(criterion),
    verdict_code      VARCHAR(30) NOT NULL REFERENCES mg.review_verdicts(code),
    affiliate_id      INTEGER REFERENCES mg.affiliates(id),
    comment           TEXT,
    evaluated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_review_type CHECK (contribution_type IN ('TICKET', 'PROPOSAL')),
    UNIQUE (contribution_type, contribution_id, step_number)
);

CREATE TABLE mg.contribution_decisions (
    id                SERIAL PRIMARY KEY,
    contribution_type VARCHAR(20) NOT NULL,
    contribution_id   INTEGER NOT NULL UNIQUE,
    final_decision    VARCHAR(25) NOT NULL,
    justification     TEXT,
    decided_by        INTEGER REFERENCES mg.affiliates(id),
    decided_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_final_decision
        CHECK (final_decision IN ('APPROVED','REVISION_REQUESTED','REJECTED','ARCHIVED')),
    CONSTRAINT chk_decision_type CHECK (contribution_type IN ('TICKET','PROPOSAL'))
);

CREATE INDEX idx_reviews_contribution ON mg.contribution_reviews(contribution_type, contribution_id);
CREATE INDEX idx_reviews_step         ON mg.contribution_reviews(step_number);
CREATE INDEX idx_decisions_contrib    ON mg.contribution_decisions(contribution_type, contribution_id);

-- ── Colonnes workflow_state sur contributions ─────────────────────────────────

ALTER TABLE mg.pilot_tickets
    ADD COLUMN workflow_state VARCHAR(35) NOT NULL DEFAULT 'SUBMITTED'
    REFERENCES mg.workflow_states(code);

ALTER TABLE mg.methodological_proposals
    ADD COLUMN workflow_state VARCHAR(35) NOT NULL DEFAULT 'SUBMITTED'
    REFERENCES mg.workflow_states(code);

COMMIT;
