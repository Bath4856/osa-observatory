-- ============================================================
-- Creation du compte fondateur sur osa_preprod (D1, D2, D6)
-- Theo D. Bakang -- role ADMIN + sieges dans les 3 comites
-- 5 juillet 2026
-- ============================================================
-- Contexte : osa_preprod n'avait aucun affilie (mg.affiliates vide).
-- Ce script cree le tout premier compte, avec role ADMIN reel et
-- activation immediate (D2), et l'inscrit directement dans les 3
-- comites (action fondatrice, pas une cooptation -- il n'existe pas
-- encore d'autre affilie pour proposer/valider).
-- ============================================================
-- EXECUTION (sur osa_preprod, pas osa_db) :
--   docker exec -i osa-db psql -U postgres -d osa_preprod \
--     < create_founder_account_preprod.sql
-- ============================================================

BEGIN;

DO $$
DECLARE
    v_affiliate_id integer;
BEGIN
    INSERT INTO mg.affiliates (
        last_name, first_name, function_title, email,
        org_name, affiliate_type, country, status, password_hash
    ) VALUES (
        'Bakang', 'Théo', 'Fondateur', 'theophile.bakang@gmail.com',
        'OSA Observatory', 'FONDATEUR', NULL, 'ACTIVE',
        '$2b$12$iaMuyCdP30./0a3JLTyhI.I/7b3WLvM7HR03zmUP3B5euUMxHGhOC'
    )
    RETURNING id INTO v_affiliate_id;

    INSERT INTO mg.affiliate_roles (affiliate_id, role_code, granted_by)
    VALUES (v_affiliate_id, 'ADMIN', 'BOOTSTRAP_PREPROD');

    INSERT INTO mg.committee_memberships (affiliate_id, committee, start_date, status)
    VALUES
        (v_affiliate_id, 'COMITE_TECH', CURRENT_DATE, 'ACTIVE'),
        (v_affiliate_id, 'COMITE_SCI', CURRENT_DATE, 'ACTIVE'),
        (v_affiliate_id, 'COMITE_ETHIQUE', CURRENT_DATE, 'ACTIVE');

    RAISE NOTICE 'Compte fondateur cree avec id = %', v_affiliate_id;
END $$;

COMMIT;

-- Verification
SELECT a.id, a.email, a.status, r.role_code
FROM mg.affiliates a
LEFT JOIN mg.affiliate_roles r ON r.affiliate_id = a.id
WHERE a.email = 'theophile.bakang@gmail.com';

SELECT affiliate_id, committee, status FROM mg.committee_memberships;
