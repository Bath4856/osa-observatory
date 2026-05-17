# P7I-AMAR-GENECO — Notes méthodologiques
*Sprint 5 — Mai 2026 — Usage institutionnel interne*

---

## 1. Objet de ce document

Ce document consigne les limites méthodologiques identifiées lors de l'investigation Sprint 5 sur les pays historiquement classés BLACK (score >= 0.800) entre 2010 et 2021, et leur disparition de cette catégorie après 2021.

Il documente également les cas de sous-classement potentiel identifiés via la requête de surveillance `underclassification_watch`.

---

## 2. Limite principale : logistics_enabling_risk

### 2.1 Description du problème

Le composant `logistics_enabling_risk` (pondération 20% dans le score GENECO) est construit sur les piliers PTRA (corridors et logistique, 65%) et PMIL (coercition/sécurité, 35%).

La source de données actuelle pour PTRA **ne capture pas** les mouvements de groupes armés, les corridors d'approvisionnement en armes, ni les flux logistiques informels de conflit. Elle reflète principalement la connectivité infrastructurelle légale (ports, routes, chaînes d'approvisionnement formelles).

Conséquence : dans les zones de conflit actif où l'économie de guerre s'appuie sur des corridors informels, le `logistics_enabling_risk` sous-estime systématiquement la réalité.

### 2.2 Pays affectés — cas critiques

Ces pays présentent un `resource_capture_risk` documenté élevé (>= 0.700) mais un `logistics_enabling_risk` anormalement bas au regard de leur contexte conflictuel connu :

| Pays | Période | resource_capture | logistics | Gap | Contexte |
|---|---|---|---|---|---|
| TCD | 2017 | 0.857 | 0.387 | 0.221 | Conflit sahélien actif, corridors armés documentés |
| MLI | 2017–2019 | 0.715–0.804 | 0.334–0.392 | 0.10–0.18 | Conflit GSIM/JNIM, trafics transfrontaliers |
| CAF | 2019 | 0.717 | 0.362 | 0.101 | Conflit groupes armés, exploitation minière illégale |
| NER | 2010 | 0.835 | 0.420 | 0.201 | Période de tension pré-coup d'État |

**Décision institutionnelle** : les scores GENECO de ces pays sont potentiellement **sous-estimés**. Ils sont classés ORANGE (0.61–0.64) mais pourraient atteindre RED (>= 0.65) voire RED supérieur après correction.

### 2.3 Pays affectés — sous-classement analytiquement correct

Ces pays présentent le même pattern (resource élevé, logistics bas) mais pour des raisons géographiques structurelles, non liées à un défaut de données :

| Pays | Raison | Décision |
|---|---|---|
| SWZ (Eswatini) | Pays enclavé, absence de corridors de conflit | Sous-classement correct — à maintenir |
| ERI (Érythrée) | Isolement géopolitique, frontières fermées | À surveiller post-UCDP |
| LBR (Liberia 2018) | Période post-conflit stabilisée | Sous-classement correct |
| SLE (Sierra Leone 2014) | Période post-conflit, crise Ebola | À surveiller |

---

## 3. Disparition des pays BLACK après 2021

### 3.1 Verdict

L'investigation confirme que la disparition des pays BLACK après 2021 **n'est pas un artefact de données**. Le `geneco_confidence_score` baisse progressivement et modérément — il ne s'effondre pas brutalement.

### 3.2 Explication principale : chute du logistics score

Le facteur dominant est la chute du `logistics_enabling_risk` après 2021 pour tous les anciens pays BLACK. Exemples :

**COG (Congo) :**

| Année | Score | logistics |
|---|---|---|
| 2019 | 0.813 | 0.758 |
| 2021 | 0.804 | 0.664 |
| 2022 | 0.659 | **0.546** |
| 2024 | 0.636 | **0.491** |

**NGA (Nigeria) :**

| Année | Score | logistics |
|---|---|---|
| 2021 | 0.819 | 0.742 |
| 2022 | 0.687 | **0.640** |
| 2024 | 0.652 | **0.489** |

### 3.3 Deux profils distincts

**Profil A — Amélioration structurelle progressive (probable) :**
GHA, TZA, KEN. Scores en baisse régulière sur 10 ans, confiance stable, toutes composantes évoluent ensemble. Cohérent avec les trajectoires de gouvernance documentées pour ces pays.

**Profil B — Chute post-2021 à surveiller :**
COD, COG, NGA. Le `resource_capture_risk` reste très élevé (0.635–0.735) mais le score composite chute sous 0.800 à cause du logistics. Pour ces trois pays, l'amélioration réelle n'est pas confirmée. À réexaminer après intégration UCDP et EITI.

---

## 4. Correction attendue — Sprint 6

### 4.1 UCDP (Uppsala Conflict Data Program)

Impact attendu : correction directe du `logistics_enabling_risk` pour TCD, MLI, CAF et les pays du Profil B (COD, COG).

UCDP documente les événements de conflit armé avec géolocalisation et attributs d'acteurs — exactement ce qui manque à PTRA pour capturer les corridors informels de l'économie de guerre.

Pays qui devraient remonter après intégration UCDP :

| Pays | Score actuel 2024 | Score estimé post-UCDP |
|---|---|---|
| TCD | 0.655 (RED) | RED supérieur probable |
| MLI | 0.663 (RED) | RED supérieur probable |
| CAF | Non en top 30 | ORANGE → RED possible |
| COD | 0.636 (ORANGE) | ORANGE → RED possible |
| COG | 0.636 (ORANGE) | ORANGE → RED possible |

### 4.2 EITI (Extractive Industries Transparency Initiative)

Impact attendu : consolidation du `resource_capture_risk` pour COD, COG, NGA. Ces pays ont déjà des scores élevés — EITI améliorera surtout la confiance (confidence_score) plutôt que les classifications.

---

## 5. Traçabilité en base

Les cas identifiés sont persistés dans :

```sql
mg.geneco_underclassification_watch    -- table de suivi
mg.v_geneco_underclassification_watch  -- vue de consultation
```

Statuts :

| Statut | Signification |
|---|---|
| `OPEN` | Correction attendue Sprint 6 — à revalider après UCDP/EITI |
| `MONITOR` | Surveiller — résolution incertaine |
| `CLOSED` | Sous-classement analytiquement correct — pas de correction prévue |

Cas OPEN à date : TCD 2017, MLI 2017–2019, CAF 2019, NER 2010, ERI 2021.

---

## 6. Communication institutionnelle recommandée

Pour toute présentation externe des scores GENECO, inclure la mention suivante pour TCD, MLI et CAF :

> *"Les scores d'exposition à l'économie de conflit pour le Tchad, le Mali et la République centrafricaine sont potentiellement sous-estimés en raison d'une couverture insuffisante des corridors logistiques de conflit dans les sources de données actuelles. Une révision est prévue après l'intégration de données UCDP (Sprint 6). Les utilisateurs sont invités à appliquer un jugement d'expert pour ces pays lorsque le score GENECO est compris entre 0.60 et 0.65."*

---

*Rédigé lors de l'investigation Sprint 5 — Mai 2026.*
*À mettre à jour après intégration UCDP — Sprint 6.*
