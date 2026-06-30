-- ============================================================
-- Sprint 30 -- Revision affiliation R1 (AFFILIATION_WORKFLOW_REVISION_001)
-- Auto-activation par confirmation email -- remplace PENDING manuel
-- Date : 30 juin 2026
-- ============================================================

BEGIN;

ALTER TABLE mg.affiliates
    DROP CONSTRAINT chk_affiliate_status;

ALTER TABLE mg.affiliates
    ADD CONSTRAINT chk_affiliate_status
    CHECK (status IN (
        'PENDING_EMAIL',
        'AFFILIATED',
        'PENDING',
        'ACTIVE',
        'SUSPENDED',
        'WITHDRAWN',
        'REJECTED'
    ));

CREATE TABLE mg.email_confirmation_tokens (
    id            SERIAL PRIMARY KEY,
    affiliate_id  INTEGER NOT NULL REFERENCES mg.affiliates(id) ON DELETE CASCADE,
    token         UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    expires_at    TIMESTAMP NOT NULL,
    used_at       TIMESTAMP,
    created_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_email_tokens_token ON mg.email_confirmation_tokens(token);
CREATE INDEX idx_email_tokens_affiliate ON mg.email_confirmation_tokens(affiliate_id);

COMMIT;
