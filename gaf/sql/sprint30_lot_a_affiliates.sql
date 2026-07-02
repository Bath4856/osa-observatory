-- ============================================================
-- Sprint 30 Lot A -- Modele utilisateurs OSA
-- Schema : mg
-- Tables : affiliates, affiliate_roles, affiliate_sessions
-- 5 roles : ADMIN, COMITE_TECH, COMITE_SCI, AFFILIE, OBSERVATEUR
-- Statuts : PENDING, ACTIVE, SUSPENDED, REJECTED
-- Date : 27 juin 2026
-- ============================================================

BEGIN;

CREATE TABLE mg.affiliates (
    id                SERIAL PRIMARY KEY,
    last_name         VARCHAR(100) NOT NULL,
    first_name        VARCHAR(100) NOT NULL,
    function_title    VARCHAR(200),
    email             VARCHAR(255) NOT NULL UNIQUE,
    org_name          VARCHAR(300) NOT NULL,
    affiliate_type    VARCHAR(50)  NOT NULL,
    country           VARCHAR(100),
    motivation        TEXT,
    status            VARCHAR(30)  NOT NULL DEFAULT 'PENDING',
    password_hash     VARCHAR(255),
    created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
    validated_at      TIMESTAMP,
    validated_by      VARCHAR(100),
    ticket_ref        VARCHAR(50),
    CONSTRAINT chk_affiliate_status
        CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','REJECTED'))
);

CREATE TABLE mg.affiliate_roles (
    id            SERIAL PRIMARY KEY,
    affiliate_id  INTEGER NOT NULL REFERENCES mg.affiliates(id) ON DELETE CASCADE,
    role_code     VARCHAR(30) NOT NULL,
    granted_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    granted_by    VARCHAR(100),
    CONSTRAINT chk_role_code
        CHECK (role_code IN ('ADMIN','COMITE_TECH','COMITE_SCI','AFFILIE','OBSERVATEUR')),
    UNIQUE (affiliate_id, role_code)
);

CREATE TABLE mg.affiliate_sessions (
    id            SERIAL PRIMARY KEY,
    affiliate_id  INTEGER NOT NULL REFERENCES mg.affiliates(id) ON DELETE CASCADE,
    token_hash    VARCHAR(255) NOT NULL UNIQUE,
    expires_at    TIMESTAMP NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    ip_address    VARCHAR(45),
    user_agent    TEXT
);

CREATE INDEX idx_affiliates_email        ON mg.affiliates(email);
CREATE INDEX idx_affiliates_status       ON mg.affiliates(status);
CREATE INDEX idx_affiliate_roles_id      ON mg.affiliate_roles(affiliate_id);
CREATE INDEX idx_affiliate_sessions_hash ON mg.affiliate_sessions(token_hash);
CREATE INDEX idx_affiliate_sessions_exp  ON mg.affiliate_sessions(expires_at);

COMMIT;
