# Projet de Governance Audit Finding — GTM_DELIVERABLES_CATALOG_MODEL_001

*Brouillon rédigé le 14 juillet 2026, à valider et déposer par vous dans `ops.audit_findings` selon la procédure habituelle (vérification de l'`audit_id` actif avant insertion). Ce document suit le format observé dans les fichiers `gaf/sql/gaf_finding_*.sql` déjà catalogués en `02_GAF`.*

---

| Champ | Valeur proposée |
|---|---|
| **Code finding** | `GTM_DELIVERABLES_CATALOG_MODEL_001` |
| **Module** | `GOVERNANCE-PRODUCT` *(nouveau module — aucun des modules existants ne couvre le catalogue de produits ; à confirmer ou remplacer par un code déjà en usage si vous préférez ne pas en créer un nouveau)* |
| **Sévérité** | INFO — décision de gouvernance et d'architecture, non bloquante, aucun impact sur une publication existante |
| **Statut proposé** | ORIENTED |
| **Sprint** | à déterminer (le dernier sprint documenté dans les sources chargées est le Sprint 31, clôturé le 3 juillet 2026) |
| **Publication impact** | NONE |

## 1. Constat

Le Livre Blanc Go-To-Market (adopté, texte fourni le 14 juillet 2026) définit un modèle de valeur à quatre familles de produits (Data / Knowledge / Decision / Implementation Products), deux niveaux de diffusion (ouvert / enrichi) et un catalogue de livrables normalisé (§10 : objectif, données d'entrée, méthode, livrables, usages, bénéficiaires, conditions de diffusion). **Aucune structure de données correspondante n'existe aujourd'hui.**

Constat complémentaire, à votre initiative (14 juillet 2026) : à ce jour, seule la famille **Data Products** existe réellement en production (portail + API open data). Les familles Knowledge Products, Decision Products et Implementation Products sont décrites dans la doctrine mais n'ont pas de représentation opérationnelle — ni dans la base, ni dans l'API, ni dans le portail.

## 2. Proposition d'orientation

Créer un schéma `gtm` minimal (référentiels `rf.product_families`, `rf.diffusion_levels`, `rf.beneficiary_types` + table `gtm.deliverables` + table de liaison + vue de consultation), permettant de commencer à cataloguer dès aujourd'hui les livrables **Data Products** déjà existants, sans attendre que les trois autres familles soient opérationnelles. Un projet de script SQL a été préparé (`create_gtm_schema.sql`, 14 juillet 2026) mais **n'a pas été exécuté** — il attend la validation de ce GAF et de l'ADR associé (voir document séparé).

## 3. Périmètre explicitement exclu de cette proposition

- Le contrôle d'accès effectif entre Niveau 1 (ouvert) et Niveau 2 (enrichi) au niveau API — sujet distinct, à traiter dans un GAF ultérieur une fois le modèle de données validé.
- L'implémentation des Knowledge/Decision/Implementation Products — la structure de données les prévoit (colonne `product_family_code`), mais aucun contenu réel n'est attendu tant que ces familles ne sont pas opérationnelles.
- Toute page portail ou tout endpoint API exposant ce catalogue.

## 4. Décision requise

Ce finding, s'il est orienté favorablement, devrait être suivi d'un ADR formalisant le choix d'architecture (voir `ADR-003 (proposition)` séparé) avant toute exécution du script SQL en DEV.
