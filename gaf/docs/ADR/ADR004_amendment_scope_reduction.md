# Amendement à ADR-004 — Recadrage de périmètre suite à ADR-OSA-OIM-001

*Note d'amendement du 14 juillet 2026. Ne remplace pas ADR-004 en entier : en modifie uniquement la section "1. La chaîne actée" et la section "Conséquences".*

---

## Ce qui change

La chaîne actée à la Décision §1 d'ADR-004 comptait onze nœuds, jusqu'à « Contribution stratégique attendue ». Suite à ADR-OSA-OIM-001, **ADR-004 s'arrête désormais à « Objectif stratégique »**. Les nœuds suivants (Matching des projets, Projet recommandé, Explication, Contribution stratégique attendue) sont retirés d'ADR-004 et relèvent intégralement d'ADR-OSA-OIM-001, sous une forme révisée (Transformation Requirement, Patrons compatibles, Instanciation, Famille de projets compatibles).

### Nouvelle chaîne actée pour ADR-004 (sept nœuds, pas onze)

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
```

ADR-004 est désormais une chaîne de **diagnostic exclusivement** : elle répond à « pourquoi faut-il agir ? » et s'arrête au moment où elle formule un objectif stratégique explicite. Elle ne matche plus aucun projet, ne recommande rien, ne produit aucune famille de projets — cette responsabilité appartient entièrement à OIM.

## Ce qui ne change pas

- Les tables de Phase 1 d'ADR-004 restent identiques : `mg.pillar_5whys_analysis`, `mg.pillar_root_causes`, `mg.strategic_levers`, `mg.root_cause_levers`, `mg.strategic_objectives`, `mg.lever_objectives`.
- La séparation raisonnement/décision (5 Pourquoi vs cause racine validée) reste inchangée.
- Le statut non-doctrinal du levier stratégique reste inchangé.
- La gouvernance (Conseil technique OSA, pas le Conseil scientifique) reste inchangée.

## Ce qui disparaît de la Phase 2 d'ADR-004

La Phase 2 telle que décrite initialement dans ADR-004 (« Matching, révision de `mg.project_coverage_policies`, `ma.mv_pillar_project_ranking` ») est retirée d'ADR-004 : elle devient la Phase 1 d'OIM, sous une architecture révisée (Transformation Requirement → Patrons compatibles → Instanciation), et non plus un matching direct objectif→projet.

## Ce qu'il reste à faire avant d'écrire du SQL

Le finding GAF `PILLAR_STRATEGIC_CHAIN_ARCHITECTURE` (déjà mis à jour une fois le 14 juillet) devra être mis à jour une seconde fois pour refléter ce recadrage, et un nouveau finding GAF devra être ouvert pour OIM (`OIM_ENGINE_CREATION` ou équivalent) avant toute exécution SQL — cohérent avec le cycle de gouvernance déjà suivi aujourd'hui pour le catalogue Go-To-Market et pour ADR-004 lui-même.
