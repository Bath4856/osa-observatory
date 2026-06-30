-- ============================================================
-- Sprint 30 Lot D2 -- Commentaires structures
-- Reserve aux comites de validation scientifique
-- (COMITE_TECH, COMITE_SCI, COMITE_ETHIQUE)
-- Date : 30 juin 2026
-- ============================================================

BEGIN;

CREATE TABLE mg.indicator_comments (
    id             SERIAL PRIMARY KEY,
    affiliate_id   INTEGER NOT NULL REFERENCES mg.affiliates(id),
    country_iso3   VARCHAR(3),
    pillar_code    VARCHAR(10),
    indicator_code VARCHAR(30),
    method         VARCHAR(20) NOT NULL,
    content        JSONB NOT NULL,
    status         VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    created_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_comment_method
        CHECK (method IN ('5W1H', 'SWOT', '5_POURQUOI')),
    CONSTRAINT chk_comment_status
        CHECK (status IN ('OPEN', 'RESOLVED', 'ARCHIVED')),
    CONSTRAINT chk_comment_scope
        CHECK (country_iso3 IS NOT NULL OR pillar_code IS NOT NULL OR indicator_code IS NOT NULL)
);

CREATE INDEX idx_indicator_comments_affiliate ON mg.indicator_comments(affiliate_id);
CREATE INDEX idx_indicator_comments_scope ON mg.indicator_comments(country_iso3, pillar_code, indicator_code);
CREATE INDEX idx_indicator_comments_status ON mg.indicator_comments(status);
CREATE INDEX idx_indicator_comments_date ON mg.indicator_comments(created_at DESC);

COMMIT;
