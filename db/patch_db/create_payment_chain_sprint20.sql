BEGIN;

ALTER TABLE rf.affiliations
    ADD COLUMN IF NOT EXISTS payment_status   VARCHAR(30) NOT NULL DEFAULT 'FREE_PILOT'
        CHECK (payment_status IN ('FREE_PILOT','PENDING_INVOICE','PAID','OVERDUE','SUSPENDED','CANCELLED')),
    ADD COLUMN IF NOT EXISTS payment_method   VARCHAR(30) NULL
        CHECK (payment_method IN ('MANUAL','BANK_TRANSFER','MOBILE_MONEY','STRIPE','PAYDUNYA') OR payment_method IS NULL),
    ADD COLUMN IF NOT EXISTS payment_currency CHAR(3)     NULL DEFAULT 'USD',
    ADD COLUMN IF NOT EXISTS monthly_fee      NUMERIC(10,2) NULL,
    ADD COLUMN IF NOT EXISTS next_invoice_date DATE        NULL,
    ADD COLUMN IF NOT EXISTS payment_notes    TEXT        NULL;

CREATE TABLE IF NOT EXISTS mg.invoices (
    invoice_id      BIGSERIAL     PRIMARY KEY,
    invoice_ref     TEXT          NOT NULL UNIQUE,
    affiliation_id  BIGINT        NOT NULL REFERENCES rf.affiliations(affiliation_id) ON DELETE RESTRICT,
    invoice_status  VARCHAR(30)   NOT NULL DEFAULT 'DRAFT'
        CHECK (invoice_status IN ('DRAFT','SENT','PAID','OVERDUE','CANCELLED')),
    invoice_period  VARCHAR(20)   NOT NULL,
    access_level    VARCHAR(20)   NOT NULL,
    currency        CHAR(3)       NOT NULL DEFAULT 'USD',
    amount_ht       NUMERIC(10,2) NOT NULL,
    amount_ttc      NUMERIC(10,2) NOT NULL,
    tax_rate        NUMERIC(5,3)  NOT NULL DEFAULT 0.000,
    payment_method  VARCHAR(30)   NULL,
    payment_ref     TEXT          NULL,
    issued_at       DATE          NOT NULL DEFAULT CURRENT_DATE,
    due_at          DATE          NOT NULL,
    paid_at         DATE          NULL,
    notes           TEXT          NULL,
    created_at      TIMESTAMP     NOT NULL DEFAULT now(),
    updated_at      TIMESTAMP     NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invoices_affiliation ON mg.invoices (affiliation_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status      ON mg.invoices (invoice_status);
CREATE INDEX IF NOT EXISTS idx_invoices_due         ON mg.invoices (due_at)
    WHERE invoice_status NOT IN ('PAID','CANCELLED');

CREATE SEQUENCE IF NOT EXISTS mg.invoice_seq START 1;

CREATE OR REPLACE FUNCTION mg.generate_invoice_ref()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.invoice_ref IS NULL OR NEW.invoice_ref = '' THEN
        NEW.invoice_ref := 'INV-' || to_char(now(),'YYYY') || '-'
                        || lpad(nextval('mg.invoice_seq')::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION mg.set_invoice_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_invoice_ref        ON mg.invoices;
DROP TRIGGER IF EXISTS trg_invoice_updated_at ON mg.invoices;

CREATE TRIGGER trg_invoice_ref
    BEFORE INSERT ON mg.invoices
    FOR EACH ROW EXECUTE FUNCTION mg.generate_invoice_ref();

CREATE TRIGGER trg_invoice_updated_at
    BEFORE UPDATE ON mg.invoices
    FOR EACH ROW EXECUTE FUNCTION mg.set_invoice_updated_at();

CREATE OR REPLACE VIEW mg.v_payment_dashboard AS
SELECT
    a.affiliation_id, a.institution_name, a.access_level,
    a.payment_status, a.payment_method, a.payment_currency,
    a.monthly_fee, a.next_invoice_date, a.subscription_end,
    (SELECT COUNT(*) FROM mg.invoices i
     WHERE i.affiliation_id = a.affiliation_id) AS invoices_total,
    (SELECT COUNT(*) FROM mg.invoices i
     WHERE i.affiliation_id = a.affiliation_id
       AND i.invoice_status = 'PAID') AS invoices_paid,
    (SELECT COUNT(*) FROM mg.invoices i
     WHERE i.affiliation_id = a.affiliation_id
       AND i.invoice_status = 'OVERDUE') AS invoices_overdue,
    (SELECT SUM(amount_ttc) FROM mg.invoices i
     WHERE i.affiliation_id = a.affiliation_id
       AND i.invoice_status = 'PAID') AS total_encaisse,
    (SELECT MAX(paid_at) FROM mg.invoices i
     WHERE i.affiliation_id = a.affiliation_id
       AND i.invoice_status = 'PAID') AS dernier_paiement
FROM rf.affiliations a
WHERE a.status = 'ACTIVE'
ORDER BY a.access_level DESC, a.payment_status;

COMMENT ON TABLE mg.invoices IS
    'Facturation OSA -- Sprint 20 -- workflow manuel Sprint 21 -- automatique Lot 2.';
COMMENT ON VIEW mg.v_payment_dashboard IS
    'Tableau de bord paiements -- Sprint 20.';

COMMIT;
