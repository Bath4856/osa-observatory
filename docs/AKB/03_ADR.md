# 03_ADR — Architecture Decision Records

*Section de l'OSA Architecture Knowledge Base (AKB). Sources : `gaf.zip` (`gaf/sql/gaf_finding_adr001_identity_sync.sql`, `gaf_finding_adr002_e2e_validation_defects.sql`), `docs.zip` (`rapport_final_12_13_juillet_2026.docx`). Établi le 14 juillet 2026.*

---

## Avertissement méthodologique — à lire avant tout le reste

Aucun fichier `ADR-XXX.md` autonome n'existe dans les sources chargées. Les deux ADR ci-dessous n'ont donc pas le même statut documentaire :

| | ADR-001 | ADR-002 |
|---|---|---|
| **Nature de la source** | Décision d'architecture complète, rédigée comme telle, stockée comme payload d'un `INSERT` dans `ops.audit_findings` | Aucun document autonome retrouvé — seulement des **citations et références** dans un finding de défauts et un rapport de session |
| **Fiabilité** | Authentique, d'époque, intégral | Reconstitution éditoriale, partielle par construction |
| **Traitement dans ce document** | Extraction et reformatage fidèle, sans interprétation | Assemblage explicitement marqué, avec mention systématique de ce qui est **inféré** vs **absent** |

Cette distinction suit le Principe 5 du Volume 0 (« chaque donnée possède une origine, une histoire et une responsabilité ») : on ne fait pas passer une reconstruction pour un original.

---

## ADR-001 — Gouvernance événementielle des identités et synchronisation inter-environnements

| Champ | Valeur |
|---|---|
| **Code** | `ADR001_EVENT_DRIVEN_IDENTITY_SYNC` |
| **Statut** | Architecture actée · socle de données livré · service de synchronisation non implémenté au moment de la rédaction |
| **Sévérité GAF associée** | INFO |
| **Résout** | Sous-chantier B du finding #33 `IDENTITY_TRACEABILITY_BY_CONSENT` |
| **Déclencheur** | Session de cadrage du 12 juillet 2026 |
| **Organe de gouvernance** | Conseil scientifique OSA |
| **Source** | `gaf/sql/gaf_finding_adr001_identity_sync.sql` — extraction intégrale, aucune coupe de fond |

### Contexte

Le sous-chantier B (« propagation contrôlée DEV/PREPROD/PROD ») du finding #33 exigeait une architecture de synchronisation des identités entre les trois environnements OSA, sans compromettre la traçabilité par consentement explicite déjà actée.

### Décision

**Principe directeur : la synchronisation ne porte jamais sur des tables — elle porte sur des événements métier validés.** Architecture orientée événements (*event-driven governance*) : ce ne sont pas les bases de données qui sont synchronisées, mais les décisions de gouvernance déjà validées.

1. **Rôle des environnements**
   - **DEV** : développement logiciel, comptes de test libres, données fictives autorisées — exclu du mécanisme de synchronisation.
   - **PREPROD** : référence opérationnelle — toutes les décisions métier (cooptations, création d'affiliés, validation KYC, affectations comité/pilier/groupe de travail) y sont prises.
   - **PROD** : exploitation officielle, ne prend aucune décision organisationnelle directement, reçoit uniquement les décisions déjà validées en préprod.

2. **Déclenchement automatique après validation métier** — pas d'action manuelle régulière de l'administrateur. Ceci ne contredit pas le principe de traçabilité par consentement explicite (finding #33) : le moment explicite est la validation elle-même (cooptation approuvée, confirmation d'email + KYC complétés) ; la propagation qui en découle est l'exécution fidèle d'une décision déjà prise, pas une nouvelle décision silencieuse.

3. **Clé de correspondance stable entre environnements** : `affiliate_uuid` (nouvelle colonne `mg.affiliates.identity_uuid`, générée à la création, jamais modifiée), en complément de la contrainte unique existante sur l'email. Un UUID stable résiste à un changement d'adresse email futur.

4. **Données propagées** : identité (`identity_uuid`, `email`, `first_name`, `last_name`), profil (`function_title`, `org_name`, `country`), gouvernance (statut, comité(s), pilier(s), groupe(s) de travail, rôle(s), dates de prise d'effet).

5. **Données explicitement exclues**, propres à chaque environnement : `password_hash`, `mg.affiliate_sessions`, `mg.refresh_tokens`, `mg.revoked_tokens`, `mg.otp_codes`, historique de connexion, journaux techniques.

6. **Cooptation** : `mg.cooptation_proposals` (documents de travail) ne sont jamais synchronisées — seule la décision finale (l'affiliation validée : `committee_memberships` / `working_group_members`) est propagée.

7. **Journal d'événements `mg.identity_events`** — registre de référence des synchronisations : identifiant d'événement, type (via `rf.identity_event_types`), `affiliate_uuid` concerné, environnement source et cible, horodatages création/validation/propagation, service propagateur, statut, et un instantané (payload) des données propagées avec hash d'intégrité.

### Conséquences

- **Livré avec cette décision** : `rf.identity_event_types`, `mg.affiliates.identity_uuid`, `mg.identity_events`.
- **Hors périmètre à ce stade** : le service « OSA Identity Synchronizer » lui-même — le mécanisme de consommation des événements (push temps réel vs scrutation périodique) restait à trancher selon la maturité d'infrastructure disponible, avant développement.
- Suite directe documentée : la validation end-to-end de ce mécanisme (12 juillet 2026) a révélé cinq défauts latents — voir ADR-002 ci-dessous.

---

## ADR-002 — Revue d'architecture avant extension du moteur de synchronisation *(reconstitution éditoriale)*

> ⚠️ **Ceci n'est pas le texte original de l'ADR-002.** Aucun document autonome portant cette décision n'a été retrouvé dans les sources chargées (`docs.zip`, `db.zip`, `gaf.zip`, `api.zip`, `portail.zip`). Ce qui suit est reconstitué à partir de **citations indirectes** trouvées dans deux documents qui, eux, sont authentiques : le finding de défauts `gaf_finding_adr002_e2e_validation_defects.sql` (qui cite explicitement les paragraphes §2, §4, §6 et §8 de l'ADR-002) et `rapport_final_12_13_juillet_2026.docx` (qui la résume en une phrase de contexte). Les sections numérotées ci-dessous ne couvrent donc que ce qui est cité ailleurs — **les §1, §3, §5 et §7 (s'ils existent) n'ont pas pu être reconstitués : aucune source ne les mentionne.**

| Champ | Valeur |
|---|---|
| **Code (déduit)** | `ADR-002` — nom informel : « Architecture Readiness Review » |
| **Statut** | Décision actée avant le 12 juillet 2026 ; **validée end-to-end pour la première fois** le 12 juillet 2026 |
| **Objet (tel que cité)** | « Revue d'architecture avant extension du moteur de synchronisation » |
| **Sources indirectes** | `gaf_finding_adr002_e2e_validation_defects.sql` (§2, §4, §6, §8 cités) ; `docs/rapport_final_12_13_juillet_2026.docx` (contexte, synthèse narrative) |
| **Document original** | **Non retrouvé** |

### Ce que les citations permettent de reconstituer

**§2 (cité)** — Interdit explicitement toute séparation fondée sur une branche conditionnelle `OSA_ENVIRONMENT` pour distinguer les parcours de cooptation encadrée (PREPROD) et d'affiliation volontaire ouverte (PROD). L'obligation de KYC doit être déduite de l'état réel des données (existence préalable d'un rattachement à un comité ou groupe de travail), jamais d'un test sur l'environnement d'exécution.

**§4 (cité)** — Exige des contraintes d'idempotence sur les tables d'affiliation touchées par la synchronisation (`mg.committee_memberships`, `mg.working_group_members`), pour que la logique `ON CONFLICT DO NOTHING` déjà présente dans `apply_sync_event()` offre une protection réelle contre les doublons en cas de rejeu d'événement.

**§6 (cité)** — Définit le cycle de démonstration attendu : **Cooptation → Validation → Événement → Synchronisation → Compte PROD → Activation → Connexion**. C'est ce cycle précis, in extenso, qui a été exécuté et validé pour la première fois le 12 juillet 2026.

**§8 (cité)** — Fixe les critères d'acceptation du chantier, satisfaits lors de cette même validation du 12 juillet (cycle complet exécuté avec un affilié de test, nettoyage confirmé, aucune trace résiduelle).

### Contexte (reconstitué à partir du rapport de synthèse)

D'après `rapport_final_12_13_juillet_2026.docx` : *« L'ADR-001 (gouvernance événementielle des identités) et l'ADR-002 (revue d'architecture avant extension du moteur de synchronisation) avaient livré un socle de données complet — table d'événements, clé stable inter-environnements, service de synchronisation — mais aucun événement réel n'avait encore transité de bout en bout. »*

Autrement dit : l'ADR-002 semble être la décision qui a validé, sur le papier, l'extension du mécanisme prévu par l'ADR-001 vers un service de synchronisation opérationnel (`identity_synchronizer.py`) — mais cette extension architecturale n'avait jamais été exercée en conditions réelles avant le 12 juillet 2026.

### Ce que la validation du 12 juillet a révélé (traité en détail dans le finding associé)

Cinq défauts latents, qu'aucune revue de code n'avait détectés, ont été découverts lors de la première exécution réelle du cycle §6 :

| # | Sévérité | Défaut | Statut |
|---|---|---|---|
| 1 | HIGH | Nginx production ne proxifiait jamais `/api/` (405 sur tout appel externe) | Résolu |
| 2 | HIGH | `mg.password_reset_tokens` absente sur `osa_db` et `osa_dev` | Résolu |
| 3 | MEDIUM | KYC rendu obligatoire à tort pour l'affiliation volontaire (violation du §2) | Résolu |
| 4 | MEDIUM | Absence de contraintes d'idempotence (violation du §4) | Résolu |
| 5 | LOW | Interpolation de variables `psql` non fonctionnelle dans `identity_synchronizer.py` | Résolu |

Deux de ces cinq défauts (le nginx et la table manquante) affectaient déjà la production **indépendamment** de ce chantier, de manière latente, avant même la mise en place du moteur de synchronisation — ce n'étaient pas des défauts introduits par l'ADR-002, mais des angles morts préexistants que sa validation a mis en lumière.

### Ce qui reste ouvert

- Vérifier si le portail React/Vite en production était affecté en usage réel par le défaut nginx #1, ou si ses appels passaient par un chemin distinct.
- Divergence de schéma notée entre le rate-limiting applicatif (`key_type`/`key_value`/`count`) et `osa_db` (`identifier`/`window_type`/`counter`) — absorbée en *fail-open*, non investiguée lors de cette session (traitée séparément le 13 juillet, cf. finding `#37`, hors périmètre strict de l'ADR-002).
- Politique de secrets distincts par environnement à formaliser comme principe permanent (mentionnée en points de suivi du rapport du 12-13 juillet, également hors périmètre strict de l'ADR-002).

---

## Synthèse pour la suite de l'AKB

- **ADR-001** peut être cité et référencé sans réserve dans les autres sections (`04_SQL`, `05_API`, `08_Governance`) comme une décision d'architecture à part entière.
- **ADR-002** ne devrait être cité qu'avec la réserve ci-dessus — en particulier, ne jamais présenter les sections §1/§3/§5/§7 reconstituées comme existantes : elles ne le sont pas dans les sources disponibles.
- Si le document original de l'ADR-002 existe quelque part (traitement de texte, canal de discussion, autre dépôt), son ajout remplacerait avantageusement cette reconstitution.
