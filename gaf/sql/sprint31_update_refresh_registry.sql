-- ============================================================
-- Sprint 31 -- Mise a jour du registre central de rafraichissement
-- pub.refresh_materialized_views()
-- 4 juillet 2026
-- ============================================================
-- Constat : cette fonction (creee Sprint 16) ne rafraichissait que
-- les 3 vues materialisees du schema pub existantes a l'epoque.
-- Deux vues materialisees creees dans des sprints ulterieurs n'y ont
-- jamais ete ajoutees, et ne sont donc jamais rafraichies par
-- run_full_pipeline.ps1 option [8] :
--   - ma.mv_p7i_amar_composite_dashboard   (Sprint 29 Lot C)
--   - ma.mv_isa_project_opportunity_catalog (Sprint 31, ce soir)
-- Une fonction Postgres peut rafraichir des vues d'un autre schema
-- sans restriction -- le nom pub.refresh_materialized_views() est
-- historique, pas une limite technique.
-- Les deux vues ont deja un index unique (verifie), CONCURRENTLY
-- reste utilisable pour les deux.
-- ============================================================
-- EXECUTION :
--   docker exec -i osa-db psql -U postgres -d osa_db \
--     < sprint31_update_refresh_registry.sql
-- ============================================================

CREATE OR REPLACE FUNCTION pub.refresh_materialized_views()
RETURNS TEXT AS $$
DECLARE
    t0 TIMESTAMPTZ := NOW();
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY pub.mv_isa_country_latest;
    REFRESH MATERIALIZED VIEW CONCURRENTLY pub.mv_isa_country_rankings;
    REFRESH MATERIALIZED VIEW CONCURRENTLY pub.mv_isa_pillar_breakdown;
    REFRESH MATERIALIZED VIEW CONCURRENTLY ma.mv_p7i_amar_composite_dashboard;
    REFRESH MATERIALIZED VIEW CONCURRENTLY ma.mv_isa_project_opportunity_catalog;
    RETURN 'OK -- ' || EXTRACT(EPOCH FROM (NOW() - t0))::INT || 's';
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION pub.refresh_materialized_views() IS
'Registre central de rafraichissement des vues materialisees ISA/AMAR/GENECO/POA.
Appelee par run_full_pipeline.ps1 (option [8], fonction Run-AlertRefresh) apres
chaque pipeline L3. Mis a jour Sprint 31 (4 juillet 2026) : ajout des vues
ma.mv_p7i_amar_composite_dashboard et ma.mv_isa_project_opportunity_catalog,
creees en Sprint 29 et Sprint 31 mais jamais enregistrees jusqu''ici.
Toute nouvelle vue materialisee doit etre ajoutee ici pour beneficier du
rafraichissement automatique apres pipeline.';

-- Verification -- test d'execution reel
SELECT pub.refresh_materialized_views();
