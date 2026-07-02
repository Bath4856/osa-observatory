-- ============================================================
-- Sprint 30 Lot D1 -- Contributions tracables
-- Ajout colonne affiliate_id (distincte de affiliation_id legacy)
-- affiliation_id (bigint) -> rf.affiliations (systeme API premium, Sprint 17+)
-- affiliate_id (integer)  -> mg.affiliates (systeme E-Participation, Sprint 30)
-- Date : 30 juin 2026
-- ============================================================

ALTER TABLE mg.pilot_tickets
ADD COLUMN affiliate_id INTEGER REFERENCES mg.affiliates(id);

CREATE INDEX idx_pilot_tickets_affiliate_id ON mg.pilot_tickets(affiliate_id);
