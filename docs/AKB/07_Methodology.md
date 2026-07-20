# 07_Methodology — Doctrine scientifique et méthodes

*Section de l'OSA Architecture Knowledge Base (AKB). Sources : `docs.zip` (notes méthodologiques, décisions doctrinales, constats techniques). Établi le 14 juillet 2026.*

---

## ✅ 0. Constat critique — VÉRIFIÉ RÉSOLU le 19 juillet 2026

**Mise à jour du 19 juillet 2026** : le constat ci-dessous (Sprint 23, 14 juillet 2026) a été vérifié directement en base sur `osa_db` — **il ne reflète plus l'état réel du système**. Une correction en profondeur est intervenue entre le 17 et le 19 juillet 2026 (date/commit exacts non retracés dans cette mise à jour — à documenter si retrouvés).

**Preuves de vérification (osa_db, 19 juillet 2026)** :
- Requête de détection de doublons L3 (`GROUP BY indicator_code, country_iso3, year, layer_id HAVING COUNT(*) > 1` sur `layer_id = 3`) → **0 doublon**, contre une sur-représentation allant jusqu'à ~24,6x décrite par le constat d'origine.
- Plafonnement des scores à 1.000 (`ma.pillar_scores`, année 2024) : **2 pays sur 54** au plafond, contre un plafonnement quasi-systématique sur 8 piliers/10 (jusqu'à 54/54 pays) décrit par le constat d'origine. Les 2 seuls cas restants (`PNUM` : MAR — Maroc, MUS — Maurice) sont des scores plausibles et non suspects — ces deux pays comptent parmi les économies numériques les plus avancées du continent, cohérent avec un score plafonné légitime plutôt qu'un artefact de sur-sommation.

**Le constat original (ci-dessous) est conservé intact pour traçabilité** — conformément au Principe 5 du Volume 0 (« chaque donnée possède une origine, une histoire et une responsabilité »), on ne réécrit pas silencieusement un constat historique même une fois résolu. Ce qui suit décrit l'état du système tel qu'observé au Sprint 23 (14 juillet 2026), **pas l'état actuel**.

---

### [ARCHIVE — Sprint 23, 14 juillet 2026] Constat d'origine, non corrigé au moment de sa rédaction

`docs/CONSTAT_DUPLICATION_L3.md` (Sprint 23) documente un défaut **non corrigé, de sévérité CRITIQUE**, avec un impact direct suspecté sur les scores publiés en accès anticipé 2010-2024. Comme ce document ne semble être qu'un constat (« aucune action engagée sur ce sujet » selon son propre en-tête), il mérite d'être en tête de cette section plutôt qu'enterré dans le corps du texte.

### Le problème

La couche L3 (normalisation) de `ma.indicator_values` contient des lignes dupliquées à grande échelle pour un très grand nombre d'indicateurs — jusqu'à **~24,6x** de sur-représentation pour certains (`MIN_PRD_ALU`, `PTRA_LOG_LPI`). La fonction `ma.compute_pillar_score` agrège ces lignes par `SUM(...)`, qui n'est pas idempotent face aux doublons ; le résultat est ensuite tronqué par `LEAST(1.0, GREATEST(0.0, SUM(...)))`, qui **masque silencieusement** toute sur-sommation.

### L'ampleur mesurée

**8 piliers sur 10** présentent un comportement de plafonnement quasi-systématique du score à 1.000 sur tout ou partie de la période 2010-2024 (PENV, PHUM, PMIL, PMON, PMIN, PRES, PTRA, PNUM) — un score moyen de 1.000 sur 54/54 pays pendant 15 ans est, par construction, incompatible avec la définition même de l'ISA (hétérogénéité attendue entre 54 États). Seuls PGEO (0 pays à ≥0,999) et dans une moindre mesure PECO semblent épargnés — sans certitude que ce ne soit pas simplement dû à des poids plus faibles absorbant la sur-sommation sous le seuil de 1,0.

### La cause racine

Une contrainte `UNIQUE (indicator_code, country_iso3, year, layer_id, method_version_id)` est **silencieusement inopérante** dès lors que `method_version_id IS NULL` (règle SQL standard : NULL ≠ NULL), ce qui est systématiquement le cas pour les lignes L3 dupliquées. `ON CONFLICT DO NOTHING` ne protège donc jamais contre ces doublons, et chaque exécution du script de normalisation ajoute un lot complet supplémentaire de 810 lignes (54 pays × 15 ans) par indicateur. Un précédent correctif (Sprint 8, `patch_deduplicate_l1_only.sql`) avait déjà supprimé 106 884 doublons — mais uniquement en couche L1, laissant L2/L3 continuer à se dégrader depuis. L'outil d'audit existant (`collectors/check_l3.py`, contrôles C1-C10) ne contient aucun contrôle de cardinalité : la duplication lui est structurellement invisible.

### Ce qui reste ouvert (tel que documenté par le constat lui-même)

Ampleur exacte par pilier, sort de PGEO/PECO, stratégie de correction (dédupliquer L3, corriger la contrainte, rendre `compute_pillar_score` idempotent, ajouter un contrôle à `check_l3.py`), et implication sur la communication si les scores SOV_* déjà en accès anticipé doivent être recalculés.

**Statut au 19 juillet 2026 : correctif confirmé par vérification directe en base (voir encadré en tête de section).** Point réputé clos pour la publication institutionnelle de septembre 2027, sauf nouvelle régression détectée d'ici là — un contrôle de cardinalité L3 reste à ajouter à `collectors/check_l3.py` (jamais fait selon le constat d'origine) pour prévenir toute récidive silencieuse future.

---

## 1. Doctrine conséquentialiste : exclusion des indices perceptuels

Décision doctrinale Sprint 21 (11 juin 2026) : les indicateurs WGI (Worldwide Governance Indicators, Banque Mondiale) sont désactivés (`rf.indicators.is_active = false`) — `GEO_STAB`, `PGEO_COR`, `PMIL_STABILITY_WGI`. Motivation explicite (Principe P7E) : les WGI agrègent des sondages d'experts, d'entreprises et de citoyens, ce qui introduit un biais évaluateur (organisations majoritairement OCDE), une opacité méthodologique (pondérations modifiées annuellement sans transparence complète), une confusion temporelle (la perception retarde sur le comportement réel), et une auto-référence (certaines sources WGI se citent mutuellement).

Cette décision s'inscrit dans une continuité documentée : CPI (Transparency International) exclu depuis Sprint 10, Freedom House Index exclu depuis Sprint 10, Bertelsmann Transformation Index exclu depuis Sprint 12, WGI exclu Sprint 21. **Aucun de ces indices n'a jamais contribué aux scores ISA publiés** (les indicateurs WGI étaient collectés en L1/L2/L3 mais absents de `ma.computed_indicators` avant même leur désactivation formelle) — la décision Sprint 21 formalise et documente un état déjà en vigueur, elle ne change aucun score publié.

**Remplacement fonctionnel par des indicateurs comportementaux** : `GEO_STAB` → `GEO_CONF` + `GEO_TER` + `PGEO_EVT` + `PGEO_FAT` + `PGEO_TRD` (sources UCDP + ACLED — conflits, fatalités, tendances observées directement) ; `PGEO_COR` → `GEO_SOVEREIGN_MARGIN` + `PGEO_INT` + `ECO_FISCAL_*` (marge fiscale souveraine, comportementale).

## 2. La classe IOSA : indicateurs non comparatifs

Décision doctrinale Sprint 27 (23 juin 2026, GAF finding #30 `IOSA_CLASS_CREATION`) : institution d'une nouvelle classe d'indicateurs — **Indicateurs d'Observation Souveraine Autonome (IOSA)** — non comparatifs, non imputables, pays-spécifiques, auditables. Trois indicateurs concernés, développés Sprints 21-26 mais maintenus hors calcul ISA : `PHUM_VALUE_CAPTURE` (rétention du capital humain, Banque Mondiale), `PMIN_VALUE_LEAKAGE` (fuite de valeur ajoutée minérale, BACI/CEPII), `PMIN_SMUGGLING_SIGNAL_RANK` (signal ordinal de contrebande minière, BACI × USGS).

**Principe doctrinal — non-comparabilité souveraine** : un score ISA est conçu pour être comparé entre pays (normalisation min-max, bornes communes, poids partagés). Ces trois indicateurs ne répondent pas à ce critère de comparabilité inter-pays — ils ne sont pas moins valides pour autant, mais leur nature exige un traitement distinct plutôt qu'une inclusion forcée dans un cadre comparatif qui ne leur convient pas. C'est une distinction méthodologique fine, cohérente avec le refus doctrinal (Volume 0, Principe 3) de faire dire aux chiffres plus que ce qu'ils permettent d'établir.

## 3. Limites méthodologiques documentées du moteur GENECO

`docs/METHODOLOGICAL_NOTES_GENECO.md` (Sprint 5, investigation sur la disparition des pays classés BLACK après 2021) documente une limite précise et chiffrée : le composant `logistics_enabling_risk` (20 % du score GENECO, piliers PTRA 65 % + PMIL 35 %) **sous-estime systématiquement** le risque dans les zones de conflit actif, parce que sa source de données ne capture pas les corridors informels/armés — seulement la connectivité infrastructurelle légale.

**Quatre pays identifiés comme potentiellement sous-classés** (statut `OPEN` dans `mg.geneco_underclassification_watch`) : Tchad (2017), Mali (2017-2019), Centrafrique (2019), Niger (2010) — classés ORANGE (0,61-0,64) alors que leur `resource_capture_risk` documenté (≥0,700) suggérerait un classement RED. Distinction importante établie par le document : certains pays présentant le même profil (Eswatini, Liberia 2018) sont sous-classés **à raison** pour des motifs géographiques structurels, pas par défaut de méthode.

La disparition des pays BLACK après 2021 est confirmée **ne pas être un artefact de données** (le score de confiance décline progressivement, pas brutalement), mais deux profils distincts sont proposés : une amélioration structurelle probable pour certains pays (Ghana, Tanzanie, Kenya), et une chute post-2021 non confirmée et à réexaminer pour d'autres (RDC, Congo, Nigeria), en attendant l'intégration de données UCDP et EITI (Sprint 6). Communication institutionnelle recommandée pour toute présentation externe : mention explicite du risque de sous-estimation pour TCD/MLI/CAF.

## 4. Le moteur de génération automatique AMAR/GENECO

`docs/amar-automation.md` documente le générateur de texte des rapports publics AMAR et Conflict Economy : un moteur de règles déterministe, **sans IA générative**, où chaque phrase est sélectionnée par une règle explicite et reproductible (75 combinaisons possibles par indicateur : 5 niveaux × 5 tendances × 3 niveaux de confiance). Cohérent avec le Principe 3 du Volume 0 (l'observation précède l'interprétation) et la doctrine P7E citée explicitement dans le document.

**Périmètre 2020-2024 : un choix doctrinal, pas une limite technique.** Les indicateurs SWOT (`WKN_`, `THR_`, `STR_`, `OPP_`) qui alimentent AMAR/GENECO résident dans des tables partitionnées par année qui n'existent tout simplement pas avant 2020. Une tentative d'extension à 15 ans via les vues moteur live (plutôt que les vues publiques persistées) a été revertée le jour même (21 juin 2026) : 48 à 112 secondes de temps de réponse par pays, inutilisable en production — et de toute façon sans intérêt réel puisque le SWOT n'a structurellement aucune donnée avant 2020. Enseignement méthodologique retenu explicitement dans le document : *« à ne pas reproduire »*.

## 5. Collecte de données — exemple EITI

`docs/EITI_MIN_TAX_procedure_collecte.md` documente une procédure de mise à jour manuelle annuelle (après publication des rapports EITI, généralement mars-avril) : téléchargement depuis EITI Data Query Tool, placement dans `data/raw/pmin/eiti/`, exécution de `fetcher_eiti_csv.py`. Automatisation via l'API `energydata.info/EITI` envisagée mais non réalisée à la date du document (Sprint 11).

## 6. Ce que cette section n'a pas couvert

- Les documents `OSA_Modele_Scientifique_ISA_v2_Mai2026.docx`, `OSA_Monte_Carlo_ISA_v2_2022_20260524.docx`, `OSA_Monte_Carlo_Recommandations_Conseil_Scientifique_v1.docx`, `5w1h_zachman_publication_isa_historique.docx`, `OSA_Zachman_Matrice_Complete_Sprint11.docx` et `rapport_couverture_donnees_isa_2021_2024.docx` n'ont pas été dépouillés en détail dans cette passe (constat prioritaire oblige — voir section 0). Ils restent à traiter si cette section doit être complétée.
- Cette section documente la doctrine et les constats méthodologiques ; elle ne revérifie aucun calcul ni aucune donnée par elle-même.
