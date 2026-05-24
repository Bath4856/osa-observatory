INSERT INTO rf.indicator_versions (indicator_code, action, replaced_by, reason, sprint)
VALUES ('AMAR_THRESHOLDS', 'PATCHED', NULL,
'Rupture apparente GREEN->YELLOW en 2020 identifiee par healthcheck automatise Sprint 11. Cause : seuils AMAR non recalibres apres desactivations Sprint 10/11 (WGI + Wikipedia). Scores ISA observes stables sur 2018-2021 (avg 0.14) - rupture dans moteur AMAR, pas dans les donnees. Recalibration seuils AMAR inscrite Sprint 12 P1 avant lancement septembre 2026.',
'Sprint11');
