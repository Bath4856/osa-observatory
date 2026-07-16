# Projet d'ADR-003 — Modèle de données du catalogue de livrables Go-To-Market

*Brouillon rédigé le 14 juillet 2026, sur le même format qu'ADR-001 (`gaf_finding_adr001_identity_sync.sql`). À formaliser en base une fois validé, avec le vrai identifiant ADR qui lui sera attribué (ce document utilise « ADR-003 » à titre indicatif, à confirmer selon votre numérotation réelle).*

---

| Champ | Valeur |
|---|---|
| **Code** | `ADR003_GTM_DELIVERABLES_MODEL` *(proposition)* |
| **Statut** | PROPOSITION — non validé, non implémenté |
| **Résout** | GAF `GTM_DELIVERABLES_CATALOG_MODEL_001` (voir document séparé) |
| **Déclencheur** | Livre Blanc Go-To-Market (adopté 14 juillet 2026) |
| **Organe de gouvernance requis** | À déterminer — le Conseil scientifique panafricain n'est pas encore constitué (lancement prévu septembre 2027, cf. `08_Governance`) ; en son absence, ce type de décision relève vraisemblablement du Comité technique ou de vous-même en tant qu'architecte principal |

## Contexte

Le Livre Blanc décrit un modèle de valeur à quatre familles de produits et une politique de diffusion à deux niveaux, mais ne prescrit aucune structure de données. Aujourd'hui, rien n'existe : ni catalogue, ni référentiel de familles de produits, ni référentiel de niveaux de diffusion.

## Décision proposée

1. **Un schéma dédié `gtm`**, séparé de `rf`/`mm`/`collect`/`ma`, pour ne pas mélanger le modèle commercial avec le modèle scientifique — cohérent avec la séparation déjà actée entre ces quatre schémas (chacun sa doctrine propre, documentée en `04_SQL`).
2. **Les taxonomies stables (familles de produits, niveaux de diffusion, catégories de bénéficiaires) vivent dans `rf`**, pas dans `gtm` — application directe de la doctrine déjà en vigueur (« `rf` immuable après déploiement initial »), le catalogue de livrables lui-même (évolutif, appelé à grandir) vit dans `gtm`.
3. **Le catalogue est versionné** (`version`, `valid_from`, `valid_to`, `is_active`) plutôt que mutable en place — cohérent avec le Principe 5 (chaque donnée a une origine, une histoire) et avec le pattern déjà utilisé pour `mm.indicator_method_versions`.
4. **Aucun contrôle d'accès n'est implémenté à ce stade** — le modèle de données prépare la distinction Niveau 1/Niveau 2 (colonne `requires_auth` sur `rf.diffusion_levels`) mais son application réelle (au niveau API ou portail) est explicitement hors périmètre de cette décision.
5. **Seule la famille Data Products est peuplée dans un premier temps** — les trois autres familles existent dans le référentiel mais restent vides tant qu'elles ne sont pas opérationnelles, pour ne pas cataloguer des livrables qui n'existent pas encore.

## Conséquences

- Livrable technique : `create_gtm_schema.sql` (rédigé le 14 juillet 2026, non exécuté).
- Ce script devra être rejoué sur `osa_dev` en premier lieu, conformément à la pratique habituelle, une fois ce projet d'ADR validé.
- Aucun impact sur les schémas existants (`rf`, `mm`, `collect`, `ma`) autre que l'ajout de trois nouvelles tables dans `rf`.
- Prochaine étape naturelle, une fois ce socle validé : un second GAF pour cadrer l'exposition API du catalogue (probablement un nouvel endpoint `GET /api/v1/gtm/catalog`, à ajouter à `05_API` sans reproduire les anomalies déjà relevées — pas de câblage dupliqué, pas de chemin Windows codé en dur).

## Ce que ce document n'est pas

Ce n'est pas une validation. C'est un projet destiné à être examiné, corrigé et formellement adopté (ou rejeté) par vous avant toute exécution en base — conformément à ce que vous avez demandé : GAF et ADR avant toute mise en œuvre.
