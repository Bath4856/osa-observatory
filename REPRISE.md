# OSA / ISA Observatory — README de reprise
## État au 28 mars 2026 — après audit Sprints 1–3

Ce document est le point de reprise pour tout nouveau développeur ou toute
nouvelle session sur ce projet. Il remplace les instructions du README principal
pour la période post-audit.

---

## Ce qui a été fait

### Sprints 1–3 livrés (base de code originale)

| Sprint | Contenu | Statut |
|--------|---------|--------|
| 1 | Schéma RF canonique — 54 pays, 8 piliers, 120 indicateurs | ✅ Livré |
| 2 | Fetcher World Bank — 31 indicateurs WDI | ✅ Livré |
| 3 | Fetchers IMF, WHO, ITU, FAO — 45 indicateurs supplémentaires | ✅ Livré |

### Audit et corrections appliquées (28 mars 2026)

Neuf fichiers ont été modifiés ou créés. **Ils doivent remplacer leurs équivalents
dans le repository avant tout déploiement.**

| Fichier | Correction | Criticité |
|---------|-----------|-----------|
| `collectors/fetcher_fao.py` | Codes FAO en double : SDN→206, GMB→17 | 🔴 Bloquant |
| `db/patch_eco_une.sql` | Ajout ECO_UNE (chômage) dans RF + MA, poids PECO rééquilibrés à 1/16 | 🔴 Bloquant |
| `collectors/fetcher_wb.py` | Migration vers `BaseFetcher` (509→184 lignes), `ENDPOINT_CODE` corrigé | 🟠 Majeur |
| `collectors/fetcher_imf.py` | Pause 1s inter-pays dans `_fetch_ifs()` + retrait proxy `MON_STB` | 🟠 Majeur |
| `collectors/fetcher_who.py` | Filtre OData 2000→78 chars + retrait proxies `HUM_EDU`/`HUM_MIG` | 🟠 Majeur |
| `collectors/wb_indicator_map.py` | +3 codes WB : `MON_STB`, `HUM_MIG`, `HUM_EDU` | 🟠 Majeur |
| `db/patch_proxies_sprint3.sql` | `MON_AUT` désactivé, sources WB mises à jour | 🟡 Moyen |
| `collectors/run_collect_all.py` | `WBFetcher` intégré en 1re position (WB→IMF→WHO→ITU→FAO) | 🟡 Moyen |
| `db/04_ma_schema.sql` | `REFRESH MATERIALIZED VIEW` : 26→2 sur pipeline historique | 🟡 Moyen |

---

## Déploiement — ordre strict

> Consulter `OSA_Deploy_Guide_Sprint1-3.docx` pour le détail complet
> avec commandes, résultats attendus et critères go/no-go.

### Étape 0 — Prérequis

```bash
# Démarrer le Codespace puis vérifier
osa-check
psql-osa -c "SELECT COUNT(*) FROM rf.indicators;"  -- attendu : 120
psql-osa -c "SELECT COUNT(*) FROM rf.countries;"   -- attendu : 54
```

Copier les 9 fichiers corrigés dans leurs répertoires respectifs.

### Étape 1 — Patches SQL (ordre obligatoire)

```bash
psql-osa -f db/patch_eco_une.sql
# NOTICE: PATCH OK — ECO_UNE ajouté, PECO = 16 indicateurs, somme poids = 1.00000000

psql-osa -f db/patch_proxies_sprint3.sql
# NOTICE: PATCH OK — MON_AUT désactivé, MON_STB → FB.BNK.CAPA.ZS ...

psql-osa -f db/04_ma_schema.sql
# Idempotent — ne détruit pas les données existantes
```

### Étape 2 — Collecte de validation (3 ans avant l'historique complet)

```bash
cd collectors

# Dry-run d'abord
python run_collect_all.py --from 2020 --to 2022 --dry-run

# Collecte réelle (20–35 min)
python run_collect_all.py --from 2020 --to 2022

# Rapport de couverture — go/no-go avant pipeline
python run_collect_all.py --coverage-only
```

**Critère go/no-go : couverture globale ≥ 55% avant d'activer le pipeline.**

### Étape 3 — Pipeline analytique

```bash
# Test sur 3 ans
psql-osa -c "CALL ma.run_pipeline_year(2020, 1);"
psql-osa -c "CALL ma.run_pipeline_year(2021, 1);"
psql-osa -c "CALL ma.run_pipeline_year(2022, 1);"

# Vérifier les scores
psql-osa -c "SELECT pillar_code, country_iso3, year, ROUND(score*100,1)
             FROM ma.pillar_scores WHERE year = 2022
             ORDER BY pillar_code, score DESC LIMIT 20;"
```

### Étape 4 — Historique complet (en session tmux)

```bash
tmux new -s osa
python run_collect_all.py --from 2010 --to 2022
# Ctrl+B D pour détacher — tmux attach -t osa pour revenir

psql-osa -c "CALL ma.run_pipeline_historical(2010, 2022);"
```

---

## État des indicateurs après audit

### Indicateurs modifiés

| Code OSA | Pilier | Modification |
|----------|--------|-------------|
| `ECO_UNE` | PECO | **Ajouté** — taux de chômage IMF WEO `LUR`. 16e indicateur PECO. |
| `MON_STB` | PMON | **Source remplacée** — `FB.BNK.CAPA.ZS` WB (capital bancaire / actifs). Ancien : population totale IMF `LP`. |
| `MON_AUT` | PMON | **Désactivé** — aucun proxy API acceptable. Reprise Sprint 5. |
| `HUM_MIG` | PHUM | **Source remplacée** — `SM.POP.NETM` WB (solde migratoire). Ancien : mortalité MNT WHO. |
| `HUM_EDU` | PHUM | **Source remplacée** — `SE.SEC.ENRR` WB (scolarisation secondaire). Ancien : densité médecins WHO. À remplacer par IDH éducation UNDP en Sprint 4. |

### Poids PECO

Rééquilibrés de 1/15 à **1/16** suite à l'ajout de `ECO_UNE`. La somme des poids reste exactement 1.0 (16 × 0.06250000).

### Providers par pilier (état actuel)

| Pilier | Indicateurs actifs | Sources principales |
|--------|--------------------|---------------------|
| PMIN | 15 | — (données SNCTM, import manuel) |
| PMON | 14 (MON_AUT désactivé) | WB, IMF WEO, IMF IFS |
| PECO | 16 | WB, IMF WEO |
| PGEO | 15 | WB (WGI) |
| PMIL | 15 | — (SIPRI, import manuel) |
| PHUM | 15 | WB, WHO GHO |
| PENV | 15 | WB, FAO |
| PNUM | 15 | WB, ITU |

---

## Architecture des fetchers

```
fetcher_base.py         Classe abstraite BaseFetcher — connexion, retry HTTP,
                        insertion raw_data + indicator_values, journalisation
    │
    ├── fetcher_wb.py   World Bank WDI — 34 indicateurs, batch 54 pays/requête
    ├── fetcher_imf.py  IMF WEO + IFS — 15 indicateurs PMON
    │                   [IFS : pause 1s inter-pays, 54 requêtes séquentielles]
    ├── fetcher_who.py  WHO GHO — 9 indicateurs PHUM
    │                   [Filtre OData années seules, filtrage pays côté Python]
    ├── fetcher_itu.py  ITU Datahub — 10 indicateurs PNUM
    └── fetcher_fao.py  FAOSTAT — 10 indicateurs PENV + PHUM

run_collect_all.py      Orchestrateur global WB→IMF→WHO→ITU→FAO
wb_indicator_map.py     Mapping OSA_CODE → code WDI (34 entrées)
```

---

## Points de vigilance pour Sprint 4

### À faire en priorité

1. **Remplacer `HUM_EDU`** par la composante éducation IDH (UNDP) — le fetcher
   UNDP est prévu dans `collect.provider_endpoints` mais pas encore implémenté.
   `SE.SEC.ENRR` est un proxy acceptable pour démarrer.

2. **Réactiver `MON_AUT`** avec un indicateur institutionnel — l'indice
   Dincer-Eichengreen d'indépendance des banques centrales est la référence,
   mais n'est pas disponible via API. Alternative : construire un proxy composite
   à partir des indicateurs WGI disponibles.

3. **Valider la cohérence ISA** — après la première collecte réelle, comparer
   les scores 2022 avec la littérature (Mo Ibrahim Index, Human Development Index).
   Afrique du Sud, Maroc, Maurice, Kenya devraient figurer dans le top 10.

4. **Ajouter `FB.AST.NPER.ZS`** (ratio NPL) comme 2e composante de `MON_STB`.
   Le ratio capital seul n'est pas suffisant pour mesurer la solidité bancaire.

### Contraintes connues

- `MON_AUT` : 14 indicateurs actifs sur 15 dans PMON. `compute_pillar_score()`
  normalise automatiquement sur les indicateurs disponibles — pas de bug,
  mais les scores PMON sont légèrement sous-estimés.
- PMIN et PMIL : aucune source API disponible — données manuelles SNCTM/SIPRI
  attendues. Ces piliers produiront 0 scores jusqu'à l'import manuel.
- FAO `ENV_WAT` (Aquastat) : fréquence quinquennale — interpolation nécessaire
  pour les années intermédiaires avant le pipeline L3.

---

## Commandes utiles

```bash
# Couverture des données par pilier
python collectors/run_collect_all.py --coverage-only

# Relancer un provider seul
python collectors/run_collect_all.py --year 2022 --provider WB
python collectors/run_collect_all.py --year 2022 --provider IMF

# Vérifier les ingestions récentes
psql-osa -c "SELECT indicator_code, status, records_inserted, execution_date
             FROM collect.ingestion_registry
             ORDER BY execution_date DESC LIMIT 20;"

# État des indicateurs actifs/désactivés
psql-osa -c "SELECT i.pillar_code, COUNT(*) FILTER (WHERE ml.is_active) AS actifs,
                    COUNT(*) FILTER (WHERE NOT ml.is_active) AS inactifs
             FROM rf.indicator_meta_link ml
             JOIN rf.indicators i ON i.code = ml.indicator_code
             GROUP BY i.pillar_code ORDER BY i.pillar_code;"

# Réinitialiser la base (repart de zéro)
bash .devcontainer/reset_db.sh
```

---

## Fichiers livrés lors de l'audit

```
db/
  patch_eco_une.sql           → À appliquer en 1er
  patch_proxies_sprint3.sql   → À appliquer en 2e
  04_ma_schema.sql            → Redéployer (REFRESH optimisé)

collectors/
  fetcher_fao.py              → Remplacer
  fetcher_wb.py               → Remplacer (migration BaseFetcher)
  fetcher_imf.py              → Remplacer (pause IFS + retrait MON_STB)
  fetcher_who.py              → Remplacer (filtre OData + retrait proxies)
  wb_indicator_map.py         → Remplacer (+3 codes WB)
  run_collect_all.py          → Remplacer (WB intégré)

OSA_Deploy_Guide_Sprint1-3.docx  → Guide complet avec go/no-go
```

---

## Sprints

| Sprint | Statut | Contenu |
|--------|--------|---------|
| 1 | ✅ Livré + audité | RF canonique — schéma SQL complet |
| 2 | ✅ Livré + audité | Fetcher World Bank (34 indicateurs après audit) |
| 3 | ✅ Livré + audité | Fetchers IMF, WHO, ITU, FAO — proxies corrigés |
| 4 | 🔜 Prochain | Pipeline L3→L7 validé sur données réelles, fetcher UNDP |
| 5 | Prévu | Calcul ISA 2010→N-2, qualité proxies (MON_AUT, HUM_MIG) |
| 6 | Prévu | ML — prédictions N-1 |
| 7 | Prévu | Open Data — exports publics |
| 8 | Prévu | Dashboard Streamlit |
| 9 | Prévu | Monétisation |
