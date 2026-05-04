-- ================================================================
-- M1 : Création ma.country_monetary_regime
-- SCD Type 2 — gouvernance monétaire par pays
-- OSA Observatory — Mai 2026
-- ================================================================

CREATE TABLE ma.country_monetary_regime (
    id              BIGSERIAL      NOT NULL,
    country_iso3    CHAR(3)        NOT NULL
                    REFERENCES rf.countries(iso3),
    regime_type     VARCHAR(30)    NOT NULL
                    CHECK (regime_type IN (
                        'INDEPENDENT',
                        'UNION_SAHEL',
                        'CFA_UEMOA',
                        'CFA_CEMAC',
                        'ZAR_RAND',
                        'DOLLARIZED',
                        'PEGGED_EUR',
                        'PEGGED_BASKET'
                    )),
    mon_sov_factor  NUMERIC(3,2)   NOT NULL
                    CHECK (mon_sov_factor BETWEEN 0 AND 1),
    valid_from      SMALLINT       NOT NULL,
    valid_to        SMALLINT,
    is_current      BOOLEAN        NOT NULL DEFAULT true,
    source_note     TEXT,
    decision_ref    TEXT,
    created_at      TIMESTAMP      DEFAULT now(),
    updated_by      VARCHAR(100)   DEFAULT 'OSA-team',
    PRIMARY KEY (id),
    UNIQUE (country_iso3, valid_from)
);

COMMENT ON TABLE ma.country_monetary_regime IS
'Regimes monetaires des 54 pays OSA — SCD Type 2.
valid_to NULL = regime actuel en vigueur.
is_current = true sur une seule ligne par pays a la fois.
mon_sov_factor : autonomie monetaire reelle (0=nulle, 1=totale).';

CREATE INDEX idx_cmr_current
    ON ma.country_monetary_regime (country_iso3, is_current);
CREATE INDEX idx_cmr_year
    ON ma.country_monetary_regime (country_iso3, valid_from, valid_to);

-- Verification
SELECT 'ma.country_monetary_regime creee' AS statut;
\d ma.country_monetary_regime