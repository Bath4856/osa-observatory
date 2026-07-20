# ADR-009 — Durcissement pré-onboarding réel

**Statut :** ACCEPTED
**Décidé le :** 20 juillet 2026
**Finding associé :** ADR009_HARDENING_PRE_ONBOARDING_20260720

## Contexte

Jusqu'à ce jour, aucun onboarding réel n'avait eu lieu — tous les comptes créés en
PREPROD et PROD relevaient de tests techniques (Phase 3 ADR-003/004, comptes
jetables, etc.). La collecte des données 2025 approche de son terme, et la
question du calendrier de validation s'est posée.

## Décision actée

La validation des données 2025 sera réalisée par l'équipe fondatrice de 24 à 50
personnes, **constituée progressivement** (sans seuil ni date fixe de
complétude), en **production réelle**, avant la consolidation officielle des
équipes (février/mars 2027) et le premier cycle de validation officiel (août
2027, portant sur les données 2026, conformément au rythme annuel de
`rf.publication_policy`).

Cette validation 2025 n'est **pas officielle** au sens de la doctrine de
publication existante — elle constitue une mise en production réelle et
irréversible du mécanisme d'onboarding, avec de vraies personnes.

**Point de doctrine confirmé** : conformément à ADR-001 (identité) et
ADR-003/004 (bus de gouvernance générique), toute décision de cooptation
(rattachement comité ou groupe de travail) **naît en PREPROD**, environnement
de référence organisationnelle, puis se **synchronise vers PROD** via le
mécanisme de propagation d'événements. Les affiliés volontaires (hors
cooptation, formulaire public `/register` en PROD) restent seuls à s'inscrire
directement en PROD ; tous les comités (Technique, Scientifique, Éthique) et
groupes de travail sont décidés en PREPROD.

**Conséquence directe** : l'irréversibilité de cette validation (« pas de
retour en arrière ») élève au rang de prérequis bloquant tout ce qui protège
l'intégrité et la sécurité des comptes réels créés à partir de maintenant —
avant même la publication institutionnelle de 2027, qui n'était jusqu'ici
l'échéance de référence pour ce type de durcissement.

## Socle de durcissement pré-onboarding

| # | Action | Statut au 20 juillet 2026 |
|---|---|---|
| 1 | Rotation `IDENTITY_SYNC_SECRET` (exposé en clair dans une session de travail) | ✅ Fait — nouvelle valeur générée, déployée PROD, vérifiée fonctionnelle |
| 2 | Rotation `OSA_SMTP_PASSWORD` (exposé en clair dans une session de travail) | ✅ Fait — changé sur Gandi, testé réellement, déployé sur les 3 environnements |
| 3 | Nettoyage des comptes de test résiduels (`mg.affiliates`, PROD) | ✅ Fait — compte "Test FlyerFinal" supprimé |
| 4 | `/terms` (CGU) | ⏸️ **Explicitement reporté** — un brouillon existe (`docs/AKB` et session du 19 juillet), mais couvre uniquement le périmètre affiliation/E-Participation ; OIM et OSOA n'ont pas encore fourni leur volet contractuel (contrats, KYC clients externes, conditions commerciales OSOA). Publication prématurée sans ce volet jugée incomplète. Reporté jusqu'à mise en œuvre d'OSOA — choix assumé, pas un oubli. |
| 5 | `gaf/GAF_DEPLOY_PROCEDURE.sh` — mot de passe DB en clair (Sprint 24, ancien) | ⏳ Ouvert — à vérifier si déjà couvert par une rotation antérieure |
| 6 | Premier onboarding réel isolé avant scale à 24-50 | 📋 Recommandé, non tranché — même logique que DEV→PREPROD→PROD appliquée au pipeline humain |

## Conséquences

- Phase 6 du plan de migration ADR-003 (décommissionnement de
  `mg.identity_events` / `rf.identity_event_types`) reste **explicitement hors
  scope** de cette décision — reportée après que les onboardings réels aient
  prouvé le bus générique en conditions réelles, pas seulement via le test
  jetable du 19 juillet 2026.
- `/terms` ne bloque pas l'onboarding malgré son statut d'item de durcissement
  générique — décision explicite de le traiter comme un chantier distinct,
  séquencé après OSOA plutôt qu'avant l'onboarding.
- Toute nouvelle exposition de secret en clair (session de travail, historique
  shell, log) doit désormais déclencher une rotation immédiate, sans attendre
  un cycle de durcissement planifié — le contexte de production réelle imminente
  réduit la tolérance au risque acceptée jusqu'ici.
