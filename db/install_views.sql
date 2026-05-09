-- ======================================================
-- INSTALLATION DES VUES OSA
-- ======================================================

\echo '>>> Installation vues ISA'

-- mapping quality
\i views/ma/v_mapping_quality_score.sql

-- indicator final
\i views/ma/v_indicator_values_final.sql

\echo '>>> Installation terminée'