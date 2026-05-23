# EITI MIN_TAX — Procédure de mise à jour manuelle
# Sprint 11 — Mai 2026

## Fréquence
Annuelle — après publication des nouveaux rapports EITI (généralement mars-avril)

## Source
EITI Data Query Tool : https://eiti.org/data
- Sélectionner : Revenue data > Tous pays africains membres > Toutes années > Export Excel
- Placer dans : data/raw/pmin/eiti/EITI_revenue_data_query__version_1_.xlsx

## Commande de collecte
cd G:\osa-observatory\collectors
py -3.12 fetcher_eiti_csv.py --dir ..\data\raw\pmin\eiti --indicator MIN_TAX

## Automatisation prévue
Sprint 12 : exploration API energydata.info/EITI pour remplacement du téléchargement manuel
URL candidate : https://energydata.info/dataset/eiti-complete-summary-table
