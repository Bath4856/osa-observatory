-- ============================================================
-- Sous-chantier C -- Multi-affiliation controlee (max 3 piliers actifs)
-- 16 juillet 2026
-- ============================================================
-- Cf. finding GAF MULTI_AFFILIATION_CONTROLLED_LIMIT pour la doctrine
-- complete. mg.committee_memberships reste inchangee (deja flexible) --
-- seule mg.working_group_members est concernee.
-- ============================================================
-- EXECUTION -- sur chaque environnement (osa_db, osa_preprod ; osa_dev
-- si des tests y sont un jour necessaires) :
--   docker exec -i osa-db psql -U postgres -d <base> \
--     < sub_c_multi_affiliation_limit.sql
-- ============================================================

BEGIN;

-- 1) Table referentielle -- meme convention que rf.access_level_policy
--    et les autres tables *_policy deja existantes. La limite est un
--    parametre, jamais une valeur en dur dans le code ou la contrainte.
CREATE TABLE IF NOT EXISTS rf.membership_policy (
    policy_code   text PRIMARY KEY,
    max_value     integer NOT NULL,
    description   text
);

INSERT INTO rf.membership_policy (policy_code, max_value, description) VALUES
    ('MAX_ACTIVE_WORKING_GROUPS_PER_AFFILIATE', 3,
     'Nombre maximum de groupes de travail actifs simultanément pour un même affilié -- décision du 16 juillet 2026, résout le sous-chantier C (multi-affiliation).')
ON CONFLICT (policy_code) DO NOTHING;

-- 2) Retrait de la contrainte trop stricte ("exactement un", tous
--    piliers confondus). uq_working_group_member_active est conservee
--    telle quelle -- elle empeche seulement le doublon sur un meme
--    pilier, toujours utile.
DROP INDEX IF EXISTS mg.idx_wgm_one_active;

-- 3) Declencheur appliquant la limite a l'ecriture -- lit la valeur
--    depuis rf.membership_policy, jamais codee en dur.
CREATE OR REPLACE FUNCTION mg.enforce_max_active_working_groups()
RETURNS trigger AS $$
DECLARE
    max_allowed integer;
    current_count integer;
BEGIN
    IF NEW.status <> 'ACTIVE' THEN
        RETURN NEW;
    END IF;

    SELECT max_value INTO max_allowed
    FROM rf.membership_policy
    WHERE policy_code = 'MAX_ACTIVE_WORKING_GROUPS_PER_AFFILIATE';

    SELECT count(*) INTO current_count
    FROM mg.working_group_members
    WHERE affiliate_id = NEW.affiliate_id
      AND status = 'ACTIVE'
      AND id <> COALESCE(NEW.id, -1);

    IF current_count >= max_allowed THEN
        RAISE EXCEPTION
            'Limite de % groupes de travail actifs simultanés atteinte pour cet affilié (rf.membership_policy).',
            max_allowed;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_max_active_working_groups ON mg.working_group_members;

CREATE TRIGGER trg_enforce_max_active_working_groups
    BEFORE INSERT OR UPDATE ON mg.working_group_members
    FOR EACH ROW
    EXECUTE FUNCTION mg.enforce_max_active_working_groups();

COMMIT;

-- Verification post-execution
SELECT policy_code, max_value FROM rf.membership_policy;
SELECT indexname FROM pg_indexes WHERE tablename = 'working_group_members' AND indexname = 'idx_wgm_one_active';
SELECT tgname FROM pg_trigger WHERE tgname = 'trg_enforce_max_active_working_groups';
