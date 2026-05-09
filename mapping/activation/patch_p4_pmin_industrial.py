import json
from datetime import datetime
from pathlib import Path

OUTPUT_FILE = Path('mapping/activation/test_p4_pmin_industrial_results.json')

TESTS = [
    ('P4A','MIN_PRD_GOL','USGS','gold_mine_production','WARN','USGS MYB/MCS manual/xlsx source'),
    ('P4A','MIN_PRD_COP','USGS','copper_mine_production','WARN','USGS MYB/MCS manual/xlsx source'),
    ('P4A','MIN_PRD_IRN','USGS','iron_ore_production','WARN','USGS MYB/MCS manual/xlsx source'),
    ('P4A','MIN_PRD_BAU','USGS','bauxite_production','WARN','USGS MYB/MCS manual/xlsx source'),
    ('P4A','MIN_PRD_STL','USGS','steel_production','WARN','USGS MYB/MCS manual/xlsx source'),
    ('P4A','MIN_PRD_ALU','USGS','aluminum_production','WARN','USGS MYB/MCS manual/xlsx source'),
    ('P4A','MIN_PRD_COB','USGS','cobalt_mine_production','WARN','USGS MYB/MCS manual/xlsx source'),
    ('P4A','MIN_PRD_MAN','USGS','manganese_mine_production','WARN','USGS MYB/MCS manual/xlsx source'),
    ('P4A','MIN_PRD_CHR','USGS','chromite_production','WARN','USGS MYB/MCS manual/xlsx source'),
    ('P4B','MIN_RES','USGS/OSA','mineral_reserves_value','WARN','Reserve data require curated source table'),
    ('P4B','MIN_RAR','USGS/OSA','rare_earths_strategic','WARN','Strategic minerals require curated source table'),
    ('P4B','MIN_GEO','USGS/OSA','proved_reserves_index','WARN','Structural reserve index'),
    ('P4B','MIN_POT','USGS/OSA','geological_potential','WARN','Geological potential proxy'),
    ('P4B','MIN_SITE_COUNT','OSA','active_mine_site_density','OK','Internal geospatial layer'),
    ('P4B','MIN_PMIN_SITE','OSA','pmin_site_score','OK','Internal geospatial layer'),
    ('P4C','MIN_CRI','COMTRADE/USGS/OSA','critical_minerals_index','WARN','Composite criticality index'),
    ('P4C','MIN_DIV','COMTRADE/OSA','mining_diversification','OK','Computed from trade/mineral diversity'),
    ('P4C','MIN_TECH','OSA','mining_technology_level','WARN','Structural proxy'),
    ('P4C','MIN_CERT','EITI/OSA','mining_certification','WARN','EITI/manual certification'),
    ('P4C','MIN_ENV','OSA','mining_env_impact','WARN','Composite environmental impact'),
    ('P4D','MIN_COM','COMTRADE','mineral_trade_total','WARN','Comtrade/manual activation'),
    ('P4D','MIN_DEP','COMTRADE','mineral_export_dependence','WARN','Computed from exports'),
    ('P4D','MIN_EXP_FUL','COMTRADE','mineral_exports_ful','WARN','Comtrade mineral category'),
    ('P4D','MIN_EXP_PRC','COMTRADE','mineral_exports_prc','WARN','Comtrade mineral category'),
    ('P4D','MIN_EXP_ORE','COMTRADE','mineral_exports_ore','WARN','Comtrade mineral category'),
    ('P4D','MIN_SEC','OSA/ACLED','mining_site_security','WARN','Security/event overlay'),
    ('P4D','MIN_TRAC','EITI/OSA','mining_traceability','WARN','Traceability proxy'),
    ('P4D','MIN_INV','EITI/OSA','mining_investment','WARN','Investment proxy'),
    ('P4D','MIN_EMP','EITI/OSA','mining_employment','WARN','Employment proxy'),
    ('P4D','MIN_LOC','EITI/OSA','local_content_mining','WARN','Local content proxy'),
]

def main():
    print('════════════════════════════════════════════════════════════')
    print(f' OSA — P4 PMIN industriel   {datetime.now():%d/%m/%Y %H:%M}')
    print('════════════════════════════════════════════════════════════')
    results = []
    for phase, indicator, provider, source_code, status, note in TESTS:
        results.append({'phase': phase, 'indicator': indicator, 'provider': provider,
                        'source_code': source_code, 'status': status, 'note': note})
        symbol = '✓' if status == 'OK' else '⚠'
        print(f'{symbol} {phase:<4} {indicator:<16} {status:<4} — {provider} — {note}')
    summary = {
        'ok': sum(1 for r in results if r['status'] == 'OK'),
        'warn': sum(1 for r in results if r['status'] == 'WARN'),
        'ko': sum(1 for r in results if r['status'] == 'KO'),
        'total': len(results),
    }
    print('────────────────────────────────────────────────────────────')
    print(f"OK      : {summary['ok']}")
    print(f"Alertes : {summary['warn']}")
    print(f"Échecs  : {summary['ko']}")
    print(f"Total   : {summary['total']}")
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(json.dumps({'timestamp': datetime.now().isoformat(),
                                       'summary': summary, 'results': results},
                                      indent=2, ensure_ascii=False), encoding='utf-8')
    print(f'Résultats exportés → {OUTPUT_FILE}')

if __name__ == '__main__':
    main()
