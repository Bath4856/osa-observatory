-- ============================================================
-- Sprint 30 Lot D3 -- Votes methodologiques
-- Vote exclusif COMITE_SCI (GAF EPARTICIPATION_ROLE_MATRIX_001)
-- Echelle 1-5, deadline fixe, resultats visibles a la cloture
-- Date : 30 juin 2026
-- ============================================================

BEGIN;

CREATE TABLE mg.methodological_proposals (
    id            SERIAL PRIMARY KEY,
    initiated_by  INTEGER NOT NULL REFERENCES mg.affiliates(id),
    title         VARCHAR(300) NOT NULL,
    description   TEXT NOT NULL,
    deadline      TIMESTAMP NOT NULL,
    status        VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    closed_at     TIMESTAMP,
    CONSTRAINT chk_proposal_status
        CHECK (status IN ('OPEN', 'CLOSED'))
);

CREATE TABLE mg.proposal_votes (
    id            SERIAL PRIMARY KEY,
    proposal_id   INTEGER NOT NULL REFERENCES mg.methodological_proposals(id) ON DELETE CASCADE,
    affiliate_id  INTEGER NOT NULL REFERENCES mg.affiliates(id),
    score         INTEGER NOT NULL,
    comment       TEXT,
    voted_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_vote_score
        CHECK (score BETWEEN 1 AND 5),
    UNIQUE (proposal_id, affiliate_id)
);

CREATE INDEX idx_proposals_status   ON mg.methodological_proposals(status);
CREATE INDEX idx_proposals_deadline ON mg.methodological_proposals(deadline);
CREATE INDEX idx_votes_proposal     ON mg.proposal_votes(proposal_id);

COMMIT;
