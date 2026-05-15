BEGIN;

DROP TABLE IF EXISTS rf.isa_executive_priority_recalibration;

CREATE TABLE rf.isa_executive_priority_recalibration (
    executive_decision_class     TEXT PRIMARY KEY,
    min_score                    NUMERIC(6,3),
    max_score                    NUMERIC(6,3),
    target_distribution_pct      NUMERIC(6,3),
    scarcity_penalty             NUMERIC(6,3)
);

INSERT INTO rf.isa_executive_priority_recalibration VALUES
('EXEC_BOARD_PREPARED',0.850,1.000,0.020,0.120),
('EXEC_FAST_TRACK_CANDIDATE',0.720,0.850,0.050,0.080),
('EXEC_PROGRAMME_CANDIDATE',0.450,0.720,0.250,0.030),
('EXEC_WATCHLIST',0.000,0.450,0.680,0.000);

COMMIT;