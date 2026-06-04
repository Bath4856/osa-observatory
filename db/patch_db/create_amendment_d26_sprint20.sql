
BEGIN;

-- ============================================================
-- OSA Observatory -- D2.6 Procédure d'amendement
-- Vue mg.v_amendment_dashboard + fonction mg.fn_register_amendment
-- Sprint 20 -- 4 juin 2026
-- ============================================================

-- 1. Vue tableau de bord des amendements (temps réel, pas MV)
CREATE OR REPLACE VIEW mg.v_amendment_dashboard AS
SELECT
    -- Release active
    r.release_code,
    r.release_label,
    r.release_status,
    r.semantic_version,
    r.data_period_start,
    r.data_period_end,
    r.public_release_date,

    -- Compteurs amendements depuis pilot_tickets
    (SELECT COUNT(*) FROM mg.pilot_tickets
     WHERE pol_level IS NOT NULL) AS amendements_total,
    (SELECT COUNT(*) FROM mg.pilot_tickets
     WHERE pol_level = 'N1') AS errata_n1,
    (SELECT COUNT(*) FROM mg.pilot_tickets
     WHERE pol_level = 'N2') AS revisions_n2,
    (SELECT COUNT(*) FROM mg.pilot_tickets
     WHERE pol_level = 'N3') AS reemissions_n3,
    (SELECT COUNT(*) FROM mg.pilot_tickets
     WHERE pol_level = 'N4') AS editions_n4,

    -- Amendements en cours (non résolus)
    (SELECT COUNT(*) FROM mg.pilot_tickets
     WHERE pol_level IS NOT NULL
       AND status NOT IN ('RESOLU','FERME')) AS amendements_en_cours,

    -- Derniers événements audit
    (SELECT COUNT(*) FROM mg.publication_audit_log
     WHERE release_code = r.release_code) AS audit_events_total,
    (SELECT MAX(created_at) FROM mg.publication_audit_log
     WHERE release_code = r.release_code) AS dernier_audit,

    -- Datasets publiés
    (SELECT COUNT(*) FROM mg.publication_registry
     WHERE release_code = r.release_code) AS datasets_total,
    (SELECT COUNT(*) FROM mg.publication_registry
     WHERE release_code = r.release_code
       AND publication_status = 'OFFICIAL_CONSOLIDATED') AS datasets_consolides,

    now() AS generated_at

FROM mg.release_registry r
WHERE r.release_status IN ('ACTIVE_CANDIDATE','OFFICIAL','ACTIVE');

COMMENT ON VIEW mg.v_amendment_dashboard IS
    'Tableau de bord amendements OSA -- D2.6. '
    'Vue temps réel (pas MV) -- volumes pilote minuscules. '
    'Sources : release_registry + pilot_tickets + publication_audit_log. '
    'Sprint 20 -- 4 juin 2026.';

-- 2. Fonction d'enregistrement formel d'un amendement
CREATE OR REPLACE FUNCTION mg.fn_register_amendment(
    p_ticket_ref     TEXT,           -- Référence ticket OSA-YYYY-NNNN
    p_pol_level      VARCHAR(5),     -- N1/N2/N3/N4
    p_amendment_type VARCHAR(80),    -- ERRATUM/REVISION/REEMISSION/NOUVELLE_EDITION
    p_release_code   VARCHAR(40),    -- Code release concernée
    p_dataset_codes  TEXT[],         -- Datasets affectés
    p_description    TEXT,           -- Description de l'amendement
    p_actor          TEXT DEFAULT CURRENT_USER
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_audit_id     BIGINT;
    v_dataset      TEXT;
    v_new_version  TEXT;
    v_curr_version TEXT;
BEGIN
    -- Vérifier que le ticket existe et a le bon pol_level
    IF NOT EXISTS (
        SELECT 1 FROM mg.pilot_tickets
        WHERE ticket_ref = p_ticket_ref
          AND pol_level = p_pol_level
    ) THEN
        RAISE EXCEPTION 'Ticket % introuvable ou pol_level % non correspondant',
            p_ticket_ref, p_pol_level;
    END IF;

    -- Calculer la nouvelle version sémantique selon niveau
    SELECT semantic_version INTO v_curr_version
    FROM mg.release_registry WHERE release_code = p_release_code;

    IF v_curr_version IS NULL THEN
        RAISE EXCEPTION 'Release % introuvable', p_release_code;
    END IF;

    -- Incrémenter selon niveau POL-OSA-001
    -- N1 Erratum    : patch +0.0.1
    -- N2 Révision   : patch +0.0.1
    -- N3 Réémission : minor +0.1.0
    -- N4 Édition    : major +1.0.0
    SELECT CASE p_pol_level
        WHEN 'N1' THEN
            regexp_replace(v_curr_version,
                '(\d+)\.(\d+)\.(\d+)',
                '..' || (regexp_replace(v_curr_version,'^\d+\.\d+\.','')::int + 1)::text)
        WHEN 'N2' THEN
            regexp_replace(v_curr_version,
                '(\d+)\.(\d+)\.(\d+)',
                '..' || (regexp_replace(v_curr_version,'^\d+\.\d+\.','')::int + 1)::text)
        WHEN 'N3' THEN
            regexp_replace(v_curr_version,
                '(\d+)\.(\d+)\.\d+',
                '.' || (split_part(v_curr_version,'.',2)::int + 1)::text || '.0')
        WHEN 'N4' THEN
            (split_part(v_curr_version,'.',1)::int + 1)::text || '.0.0'
        END INTO v_new_version;

    -- Enregistrer dans publication_audit_log
    INSERT INTO mg.publication_audit_log
        (release_code, audit_event, audit_status, object_type, object_name,
         audit_message, audit_payload)
    VALUES (
        p_release_code,
        'AMENDMENT_' || p_pol_level || '_' || p_amendment_type,
        'REGISTERED',
        'AMENDMENT',
        p_ticket_ref,
        p_description,
        jsonb_build_object(
            'ticket_ref',     p_ticket_ref,
            'pol_level',      p_pol_level,
            'amendment_type', p_amendment_type,
            'datasets',       p_dataset_codes,
            'version_before', v_curr_version,
            'version_after',  v_new_version,
            'actor',          p_actor,
            'registered_at',  now()
        )
    )
    RETURNING audit_id INTO v_audit_id;

    -- Mettre à jour la version sémantique de la release
    UPDATE mg.release_registry
    SET semantic_version = v_new_version,
        updated_at       = now(),
        release_notes    = COALESCE(release_notes,'') || chr(10) ||
            to_char(now(),'YYYY-MM-DD') || ' [' || p_pol_level || '] ' || p_description
    WHERE release_code = p_release_code;

    -- Enregistrer dans l'audit trail par dataset
    FOREACH v_dataset IN ARRAY p_dataset_codes LOOP
        INSERT INTO mg.isa_publication_audit_trail
            (object_type, object_key, workflow_status, actor, audit_note)
        VALUES (
            'DATASET_AMENDMENT',
            v_dataset,
            'AMENDMENT_' || p_pol_level,
            p_actor,
            p_ticket_ref || ' -- ' || p_description
        );
    END LOOP;

    RETURN v_audit_id;
END;
$$;

COMMENT ON FUNCTION mg.fn_register_amendment IS
    'Enregistre formellement un amendement ISA. '
    'Lie ticket POL-OSA-001 -> publication_audit_log + release_registry (versionnage auto). '
    'Niveaux : N1 patch+1, N2 patch+1, N3 minor+1, N4 major+1. '
    'Sprint 20 -- D2.6 -- 4 juin 2026.';

COMMIT;
