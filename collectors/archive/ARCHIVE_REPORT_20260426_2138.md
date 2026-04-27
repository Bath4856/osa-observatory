# Rapport d'archivage OSA collectors
**Date** : 2026-04-26 21:38  
**Mode** : RÉEL  

## Fichiers archivés (11)

- `wb_indicator_map_patch_wgi.py` — PATCH — intégrer dans wb_indicator_map.py puis archiver
- `wb_indicator_map_pmil_patch.py` — PATCH — intégrer dans wb_indicator_map.py puis archiver
- `wb_indicator_map_pnum_patch.py` — PATCH — intégrer dans wb_indicator_map.py puis archiver
- `wb_indicator_map_pres_patch.py` — PATCH — intégrer dans wb_indicator_map.py puis archiver
- `wb_indicator_map_ptra_patch.py` — PATCH — remplacé par ptra_final_patch
- `wb_indicator_map_ptra_final_patch.py` — PATCH — intégrer dans wb_indicator_map.py puis archiver
- `imputer_ptra_patch.py` — PATCH — intégrer dans imputer_v3.py puis archiver
- `imputer_sprint6_patch.py` — PATCH — intégrer dans imputer_v3.py puis archiver
- `fetcher_imf_weo_csv.py` — ANCIEN — remplacé par fetcher_imf_weo_v2.py (Sprint 7)
- `fetcher_fao.py` — ANCIEN — remplacé par fetcher_fao_csv.py (CSV bulk, plus fiable)
- `fetcher_undp.py` — ANCIEN — remplacé par fetcher_undp_csv.py

## Fichiers récupérés de collector_v2 (0)


## Actions manuelles restantes

1. Vérifier `imputer.py` vs `imputer_v3.py` (diff manuel) et archiver le plus ancien
2. Exécuter `merge_patches.py` pour intégrer les patches dans `wb_indicator_map.py`
3. Vérifier que `fetcher_wb_pres_pmil_pnum.py` importe bien depuis `wb_indicator_map.py`
4. Tester la collecte après archivage : `python collectors/run_pipeline_sprint7.py --probe`

## collector_v2
- Dossier `collector_v2/` supprimé
- Fichiers utiles récupérés dans `collectors/`