# ADR-004 (proposition) — Chaîne de recommandation stratégique par pilier

*Rédigé le 14 juillet 2026, sur la base des arbitrages doctrinaux transmis ce même jour. Numérotation indicative (ADR-001 et la proposition ADR-003 du 14 juillet existent déjà dans cette conversation) — à aligner sur votre registre réel d'ADR avant publication.*

---

| Champ | Valeur |
|---|---|
| **Code** | `ADR004_PILLAR_STRATEGIC_CHAIN_ARCHITECTURE` *(proposition)* |
| **Statut** | Conception figée (doctrine) — développement non démarré |
| **Résout** | GAF `PILLAR_STRATEGIC_CHAIN_ARCHITECTURE`, mis à jour le 14 juillet 2026 (voir `UPDATE_gaf_finding_chaine_pilier_projet_v2.sql`) |
| **Déclencheur** | Revue de la page PGEO, absence de démonstration comparative et de chaîne causale derrière la recommandation de projet unique livrée en Sprint 31 |
| **Organe de gouvernance** | Conseil technique OSA — ne relève pas du Conseil scientifique panafricain (aucun nouvel objet doctrinal, hiérarchie OSA→ISA→POA→AMAR→GENECO inchangée) |
| **Chantier distinct de** | Le Livre Blanc Go-To-Market (`ADR-003` proposition, schéma `gtm`) — voir clause de raccordement en fin de document |

## Contexte

L'OSA a livré en Sprint 31 une recommandation de projet unique par pays sur la page PGEO, sans chaîne causale explicite ni possibilité de comparer plusieurs pistes. La présente décision fixe l'architecture qui remplace cette recommandation ad hoc par un moteur explicable, traçable et auditable, conforme au Principe 2 du Volume 0 (auditabilité comme exigence permanente).

## Décision

### 1. La chaîne actée (onze nœuds)

```
Pilier
   ↓
Analyse stratégique
   ↓
Diagnostic stratégique
   ↓
5 Pourquoi
   ↓
Cause racine
   ↓
Levier(s) stratégique(s)
   ↓
Objectif stratégique
   ↓
Matching des projets
   ↓
Projet recommandé
   ↓
Explication
   ↓
Contribution stratégique attendue
```

Le pilier reste l'unité de diagnostic — pas l'ISA, qui se contente d'orienter vers les piliers prioritaires (principe déjà acté dans la v1 du finding).

### 2. Séparation stricte raisonnement / décision

Le 5 Pourquoi (`mg.pillar_5whys_analysis`) est un processus analytique versionnable et rejouable. La cause racine retenue (`mg.pillar_root_causes`) est sa conclusion validée — seule celle-ci alimente le moteur de recommandation. Cette séparation protège la possibilité de faire évoluer ou rejouer une analyse sans jamais modifier le modèle de recommandation lui-même.

### 3. Le levier stratégique n'est pas un objet doctrinal

`mg.strategic_levers` est un axe d'intervention, pas un phénomène observé : il n'entre pas dans la hiérarchie OSA→ISA→POA→AMAR→GENECO et ne requiert pas de validation du Conseil scientifique. Les POA restent intacts et inchangés. Gardé volontairement minimal — son contenu relève du référentiel métier et peut évoluer sans remettre en cause les relations déjà modélisées.

### 4. Deux relations N:N pondérées, symétriques

- `mg.root_cause_levers(cause_code, lever_code, relevance_weight)` — une cause peut appeler plusieurs leviers, un levier peut répondre à plusieurs causes.
- `mg.lever_objectives(lever_code, objective_code, relevance_weight)` — un levier peut servir plusieurs objectifs, un objectif peut être atteint par la combinaison de plusieurs leviers.

Ces deux tables partagent la même forme délibérément : c'est ce qui rend la chaîne entièrement référentiel-driven, sans branche de logique métier cachée dans le code applicatif.

### 5. L'objectif stratégique, nœud central de raccordement

`mg.strategic_objectives(objective_code, lever_code, title, description, valid_from, valid_to)` introduit un objet propre plutôt qu'un champ de texte libre. Le projet n'est plus relié directement à une faiblesse : il est relié à un objectif stratégique explicitement formulé, qui devient le pont entre le levier et le projet recommandé.

### 6. Deux usages de Zachman, non fusionnés

- **Zachman n°1** — cadre méthodologique de gouvernance et de publication ISA (`5w1h_zachman_publication_isa_historique.docx`). Indépendant, hors périmètre de cette décision.
- **Zachman n°2** — matrice de conception et de gouvernance au niveau du projet, traitée en Phase 3. Finalité différente ; ne jamais confondre les deux dans la documentation ou le code.

### 7. La catégorisation 5M reste inchangée

Les « 5M » correspondent à la catégorisation des causes déjà en usage dans `cause_category_5m`. Aucun nouveau référentiel n'est créé pour cela.

### 8. Phasage

| Phase | Contenu |
|---|---|
| **1 — Architecture du diagnostic** | `pillar_5whys_analysis`, `pillar_root_causes`, `strategic_levers`, `root_cause_levers`, `strategic_objectives`, `lever_objectives` |
| **2 — Moteur de recommandation** | Matching, révision de `mg.project_coverage_policies` (pointer sur `lever_code` plutôt que `cause_category_5m`), `ma.mv_pillar_project_ranking` |
| **3 — Dossiers stratégiques des projets** | Résumé exécutif, analyse stratégique, réponse au diagnostic, 5 Pourquoi, 5M, matrice Zachman version projet (n°2), gouvernance, calendrier, risques, contribution stratégique attendue |
| **4 — Généralisation** | Extension progressive de cette logique à POA, AMAR, GENECO |

## Conséquences

- `mg.sovereign_capabilities` n'est **pas** créée : objet conceptuel jugé ni nécessaire au moteur, ni défini dans la doctrine actuelle.
- Aucun impact sur la hiérarchie doctrinale OSA→ISA→POA→AMAR→GENECO ni sur les scores déjà publiés.
- La Phase 2 reste bloquée tant que `mg.project_coverage_policies` n'a pas été révisée vers `lever_code` — préalable déjà identifié avant cette décision et confirmé ici.
- La Phase 3 ne doit pas démarrer avant que les Phases 1 et 2 soient opérationnelles : un dossier Zachman n°2 sans projet réellement matché documenterait une coquille vide.

## Clause de raccordement avec le Livre Blanc Go-To-Market (chantier distinct)

Le « Projet recommandé » produit en sortie de la Phase 2 est, par nature, une instance de **Decision Product** au sens du §7 du Livre Blanc Go-To-Market. Cette décision **ne crée aucun lien technique** entre le schéma `mg` (présent ADR) et le schéma `gtm` (ADR-003, catalogue de livrables) — les deux chantiers avancent indépendamment. Elle acte cependant, pour mémoire, qu'**une clause de raccordement devra être examinée en Phase 2 ou 3** : chaque projet recommandé par ce moteur constituera vraisemblablement une ligne candidate dans `gtm.deliverables` (`product_family_code = 'DECISION'`). Ce raccordement n'est pas conçu ici et ne doit pas être anticipé dans le schéma de la Phase 1.
