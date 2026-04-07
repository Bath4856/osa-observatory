-- ============================================================
-- OSA / ISA OBSERVATORY
-- PATCH : collect.indicator_bounds + ma.indicator_values.value_status
-- Date   : 2026-03-31
-- Sprint : 3.5 — Qualité des données et gestion des bornes temporelles
--
-- Objectif :
--   1. Stocker les bornes réelles de disponibilité par indicateur/provider
--   2. Qualifier chaque valeur collectée (OBSERVED, INTERPOLATED, etc.)
--   3. Permettre un ISA honnête et traçable avec coefficient de confiance
-- ============================================================

BEGIN;

-- ============================================================
-- 1. TABLE collect.indicator_bounds
--    Bornes temporelles réelles par indicateur et provider
-- ============================================================

CREATE TABLE IF NOT EXISTS collect.indicator_bounds (
    -- Clé primaire
    indicator_code  VARCHAR(20)  NOT NULL
                    REFERENCES rf.indicators(code)
                    ON DELETE CASCADE,
    provider_code   VARCHAR(10)  NOT NULL,

    -- Bornes temporelles réelles
    year_min        SMALLINT     NOT NULL,  -- 1ère année disponible dans l'API
    year_max        SMALLINT     NOT NULL,  -- dernière année disponible dans l'API

    -- Qualité de la couverture
    countries_count SMALLINT     NOT NULL DEFAULT 0,
                                           -- nb pays avec données à year_max

    -- Suivi des collectes
    last_collected  SMALLINT     NULL,     -- dernière année effectivement insérée en base
    next_collect    SMALLINT     NULL,     -- prochaine année à collecter (calculée)

    -- Fréquence de publication
    pub_frequency   VARCHAR(20)  NOT NULL DEFAULT 'ANNUAL',
                                           -- ANNUAL, BIENNIAL, TRIENNIAL, IRREGULAR

    -- Statut
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    probe_status    VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
                                           -- PENDING, OK, PARTIAL, UNAVAILABLE

    -- Horodatage
    last_probed     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    -- Notes libres
    notes           TEXT         NULL,

    PRIMARY KEY (indicator_code, provider_code)
);

COMMENT ON TABLE collect.indicator_bounds IS
    'Bornes temporelles réelles de disponibilité par indicateur et provider. '
    'Mis à jour avant chaque collecte annuelle (juillet N). '
    'Pilote la collecte intelligente : year_from = last_collected+1, year_to = year_max.';

COMMENT ON COLUMN collect.indicator_bounds.year_min IS
    'Première année disponible dans l API source — peut différer de 2010.';
COMMENT ON COLUMN collect.indicator_bounds.year_max IS
    'Dernière année disponible — pilote la borne haute de collecte.';
COMMENT ON COLUMN collect.indicator_bounds.last_collected IS
    'Dernière année effectivement collectée et insérée dans ma.indicator_values.';
COMMENT ON COLUMN collect.indicator_bounds.next_collect IS
    'Prochaine année à collecter = last_collected + 1. NULL si à jour.';
COMMENT ON COLUMN collect.indicator_bounds.pub_frequency IS
    'Fréquence de publication : ANNUAL (1 an), BIENNIAL (2 ans), '
    'TRIENNIAL (3 ans), IRREGULAR (irrégulier).';
COMMENT ON COLUMN collect.indicator_bounds.probe_status IS
    'Statut du dernier sondage : PENDING (pas encore sondé), '
    'OK (API disponible), PARTIAL (données partielles), UNAVAILABLE (API inaccessible).';

-- Index pour requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_bounds_provider
    ON collect.indicator_bounds (provider_code);
CREATE INDEX IF NOT EXISTS idx_bounds_active
    ON collect.indicator_bounds (is_active, probe_status);
CREATE INDEX IF NOT EXISTS idx_bounds_next_collect
    ON collect.indicator_bounds (next_collect)
    WHERE next_collect IS NOT NULL;

-- Trigger de mise à jour automatique de updated_at
CREATE OR REPLACE FUNCTION collect.update_bounds_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    -- Recalculer next_collect automatiquement
    IF NEW.last_collected IS NOT NULL THEN
        NEW.next_collect = CASE
            WHEN NEW.last_collected < NEW.year_max THEN NEW.last_collected + 1
            ELSE NULL  -- déjà à jour
        END;
    ELSE
        NEW.next_collect = NEW.year_min;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bounds_updated_at
    BEFORE UPDATE ON collect.indicator_bounds
    FOR EACH ROW EXECUTE FUNCTION collect.update_bounds_timestamp();

-- ============================================================
-- 2. COLONNE value_status dans ma.indicator_values
--    Qualifie chaque valeur collectée
-- ============================================================

-- Ajouter la colonne value_status
ALTER TABLE ma.indicator_values
    ADD COLUMN IF NOT EXISTS value_status VARCHAR(20) NOT NULL DEFAULT 'OBSERVED';

-- Ajouter la colonne confidence_score (0.0 → 1.0)
ALTER TABLE ma.indicator_values
    ADD COLUMN IF NOT EXISTS confidence_score NUMERIC(4,3) NOT NULL DEFAULT 1.000;

-- Commentaires
COMMENT ON COLUMN ma.indicator_values.value_status IS
    'Qualité de la valeur :
     OBSERVED     — donnée réelle collectée depuis une API source
     INTERPOLATED — interpolation linéaire entre deux valeurs observées
     EXTRAPOLATED — projection au-delà de la dernière valeur observée
     IMPUTED      — valeur imputée par le modèle ML
     MISSING      — absence documentée, aucune estimation possible';

COMMENT ON COLUMN ma.indicator_values.confidence_score IS
    'Coefficient de confiance de la valeur (0.0 → 1.0) :
     1.000 — OBSERVED (valeur réelle)
     0.800 — INTERPOLATED (interpolation fiable)
     0.600 — EXTRAPOLATED (projection court terme < 2 ans)
     0.400 — EXTRAPOLATED (projection long terme ≥ 2 ans)
     0.700 — IMPUTED par ML (modèle validé)
     0.000 — MISSING (valeur absente)';

-- Contrainte de validation
ALTER TABLE ma.indicator_values
    ADD CONSTRAINT chk_value_status
    CHECK (value_status IN (
        'OBSERVED', 'INTERPOLATED', 'EXTRAPOLATED', 'IMPUTED', 'MISSING'
    ));

ALTER TABLE ma.indicator_values
    ADD CONSTRAINT chk_confidence_score
    CHECK (confidence_score BETWEEN 0.0 AND 1.0);

-- Index pour filtrer par qualité
CREATE INDEX IF NOT EXISTS idx_iv_value_status
    ON ma.indicator_values (value_status);
CREATE INDEX IF NOT EXISTS idx_iv_confidence
    ON ma.indicator_values (confidence_score)
    WHERE confidence_score < 1.0;

-- ============================================================
-- 3. VUE collect.bounds_summary
--    Rapport de couverture par provider
-- ============================================================

CREATE OR REPLACE VIEW collect.bounds_summary AS
SELECT
    b.provider_code,
    COUNT(*)                                        AS total_indicateurs,
    COUNT(*) FILTER (WHERE b.probe_status = 'OK')   AS ok,
    COUNT(*) FILTER (WHERE b.probe_status = 'PARTIAL') AS partial,
    COUNT(*) FILTER (WHERE b.probe_status = 'UNAVAILABLE') AS unavailable,
    COUNT(*) FILTER (WHERE b.probe_status = 'PENDING') AS pending,
    MIN(b.year_min)                                 AS year_min_global,
    MAX(b.year_max)                                 AS year_max_global,
    AVG(b.countries_count)::INT                     AS avg_countries,
    COUNT(*) FILTER (WHERE b.next_collect IS NOT NULL) AS a_collecter,
    MAX(b.last_probed)                              AS dernier_sondage
FROM collect.indicator_bounds b
WHERE b.is_active
GROUP BY b.provider_code
ORDER BY b.provider_code;

COMMENT ON VIEW collect.bounds_summary IS
    'Rapport de couverture des bornes par provider. '
    'Consulter avant chaque collecte annuelle.';

-- ============================================================
-- 4. VUE ma.indicator_values_quality
--    Rapport de qualité des valeurs par pilier/année
-- ============================================================

CREATE OR REPLACE VIEW ma.indicator_values_quality AS
SELECT
    i.pillar_code,
    iv.year,
    COUNT(*)                                                    AS total_valeurs,
    COUNT(*) FILTER (WHERE iv.value_status = 'OBSERVED')        AS observed,
    COUNT(*) FILTER (WHERE iv.value_status = 'INTERPOLATED')    AS interpolated,
    COUNT(*) FILTER (WHERE iv.value_status = 'EXTRAPOLATED')    AS extrapolated,
    COUNT(*) FILTER (WHERE iv.value_status = 'IMPUTED')         AS imputed,
    COUNT(*) FILTER (WHERE iv.value_status = 'MISSING')         AS missing,
    ROUND(AVG(iv.confidence_score)::NUMERIC, 3)                 AS avg_confidence,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE iv.value_status = 'OBSERVED')
        / NULLIF(COUNT(*), 0), 1
    )                                                           AS pct_observed
FROM ma.indicator_values iv
JOIN rf.indicators i ON i.code = iv.indicator_code
GROUP BY i.pillar_code, iv.year
ORDER BY iv.year DESC, i.pillar_code;

COMMENT ON VIEW ma.indicator_values_quality IS
    'Rapport de qualité des valeurs collectées par pilier et année. '
    'Utilisé pour valider la fiabilité de l ISA avant publication.';

-- ============================================================
-- 5. Vérifications post-patch
-- ============================================================

DO $$
DECLARE
    v_bounds_exists  BOOLEAN;
    v_status_exists  BOOLEAN;
    v_conf_exists    BOOLEAN;
BEGIN
    -- Vérifier table indicator_bounds
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'collect'
        AND table_name = 'indicator_bounds'
    ) INTO v_bounds_exists;

    -- Vérifier colonne value_status
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'ma'
        AND table_name = 'indicator_values'
        AND column_name = 'value_status'
    ) INTO v_status_exists;

    -- Vérifier colonne confidence_score
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'ma'
        AND table_name = 'indicator_values'
        AND column_name = 'confidence_score'
    ) INTO v_conf_exists;

    IF NOT v_bounds_exists THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : table collect.indicator_bounds manquante';
    END IF;
    IF NOT v_status_exists THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : colonne ma.indicator_values.value_status manquante';
    END IF;
    IF NOT v_conf_exists THEN
        RAISE EXCEPTION 'PATCH ÉCHOUÉ : colonne ma.indicator_values.confidence_score manquante';
    END IF;

    RAISE NOTICE 'PATCH OK —';
    RAISE NOTICE '  collect.indicator_bounds  : créée';
    RAISE NOTICE '  ma.indicator_values.value_status : ajoutée (défaut OBSERVED)';
    RAISE NOTICE '  ma.indicator_values.confidence_score : ajoutée (défaut 1.000)';
    RAISE NOTICE '  collect.bounds_summary    : vue créée';
    RAISE NOTICE '  ma.indicator_values_quality : vue créée';
    RAISE NOTICE '';
    RAISE NOTICE 'Prochaine étape : lancer python3 run_collect_all.py --probe';
    RAISE NOTICE 'pour peupler collect.indicator_bounds avant la collecte réelle.';
END;
$$;

COMMIT;
