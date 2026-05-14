BEGIN;
CREATE SCHEMA IF NOT EXISTS rf;
CREATE SCHEMA IF NOT EXISTS ma;
CREATE SCHEMA IF NOT EXISTS mg;
CREATE TABLE IF NOT EXISTS rf.package_lifecycle (
 package_code VARCHAR(20) PRIMARY KEY,
 package_label TEXT NOT NULL DEFAULT '',
 package_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 replacement_package VARCHAR(20),
 notes TEXT,
 updated_at TIMESTAMP DEFAULT NOW()
);
ALTER TABLE rf.package_lifecycle
 ADD COLUMN IF NOT EXISTS package_label TEXT NOT NULL DEFAULT '',
 ADD COLUMN IF NOT EXISTS package_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 ADD COLUMN IF NOT EXISTS replacement_package VARCHAR(20),
 ADD COLUMN IF NOT EXISTS notes TEXT,
 ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();
DELETE FROM rf.package_lifecycle WHERE package_code='P7J';
INSERT INTO rf.package_lifecycle(package_code,package_label,package_status,replacement_package,notes,updated_at)
VALUES('P7J','Decision Support & Intervention Prioritization v2','ACTIVE',NULL,
'P7J v2 recalibrates decision priority classes with alert-level caps and stricter country-level aggregation.',NOW());
DROP TABLE IF EXISTS rf.isa_decision_alert_cap_policy CASCADE;
CREATE TABLE rf.isa_decision_alert_cap_policy(
 sovereign_alert_level TEXT PRIMARY KEY,
 max_decision_priority_class VARCHAR(30) NOT NULL,
 max_decision_rank INTEGER NOT NULL,
 cap_policy_note TEXT
);
INSERT INTO rf.isa_decision_alert_cap_policy VALUES
('GREEN','DECISION_STANDARD',2,'GREEN cannot produce HIGH or CRITICAL decisions.'),
('YELLOW','DECISION_HIGH',3,'YELLOW cannot produce CRITICAL decisions.'),
('ORANGE','DECISION_CRITICAL',4,'ORANGE can produce CRITICAL decisions if score is high.'),
('RED','DECISION_CRITICAL',4,'RED can produce CRITICAL decisions.');
DO $$ DECLARE n INTEGER; BEGIN SELECT COUNT(*) INTO n FROM rf.isa_decision_alert_cap_policy; RAISE NOTICE 'P7J v2 alert cap policy lignes : %', n; END $$;
COMMIT;
