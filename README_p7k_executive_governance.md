# P7K — Executive Pre-Governance / Board Preparation

P7K est la couche de pré-gouvernance exécutive de la chaîne analytique OSA. Elle transforme les décisions P7J en dossiers pré-board structurés, en portefeuilles souverains classés et en signaux d'escalation nationale.

> **P7K outputs are pre-governance signals, not final executive arbitration.**
>
> P7K prépare. P9 (futur) arbitrera définitivement.
> Les sorties P7K sont en attente de quantification prédictive P7Z et de publication P8.

## Position dans l'architecture

```text
P7F diagnostic
↓
P7G tendances forecast
↓
P7H simulation scénarios
↓
P7I early warning
↓
P7J décision intelligence
↓
P7K pré-gouvernance exécutive  ← ici
↓
P8 publication / delivery
↓
P7Z prédictif (futur)
↓
P9 gouvernance exécutive finale (futur)
```

## Ce que P7K produit

- **Executive priority portfolio** — portefeuille souverain national classé
- **Budget arbitration matrix** — signaux d'arbitrage budgétaire (pré-gouvernance)
- **Board decision pack** — dossiers pré-board identifiés
- **Governance heatmap** — carte de chaleur pays × piliers
- **Executive watchlist** — surveillance des dossiers fragiles
- **National escalation queue** — queue d'escalation institutionnelle

## Ce que P7K ne fait pas encore

- ❌ Arbitrage exécutif définitif → P9
- ❌ Simulation d'impact ML quantifié → P7Z
- ❌ Cockpit présidentiel complet → P9
- ❌ Certification et publication → P8

## Classes de décision pré-gouvernance

| Classe | Signification |
|---|---|
| EXEC_BOARD_PREPARED | Dossier pré-board prêt. Quantification P7Z requise avant soumission finale. |
| EXEC_FAST_TRACK_CANDIDATE | Candidat fast-track. Signal pré-gouvernance. |
| EXEC_PROGRAMME_CANDIDATE | Candidat programme. Note à confirmer après P7Z. |
| EXEC_WATCHLIST | Surveillance. Monitoring et documentation. |

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7k_executive_governance.ps1
.\db\run\test_p7k_dry_run.ps1
```

## Fichiers

```text
db/patch_db/patch_p7k_executive_governance.sql
db/views/ma/v_p7k_executive_source.sql
db/views/ma/v_isa_executive_priority_portfolio.sql
db/views/ma/v_isa_budget_arbitration_matrix.sql
db/views/ma/v_isa_board_decision_pack.sql
db/views/ma/v_isa_governance_heatmap.sql
db/views/ma/v_isa_executive_watchlist.sql
db/views/ma/v_isa_national_escalation_queue.sql
db/views/ma/v_isa_executive_governance_readiness.sql
audit/list_p7k_source_columns.sql
audit/p7k_executive_governance_report.sql
db/run/run_p7k_executive_governance.ps1
db/run/test_p7k_dry_run.ps1
```

## Dry-run

Le dry-run vérifie : dépendances, colonnes, cardinalité, anti-NULL, bornes 0..1,
classes pré-gouvernance, bandes budgétaires, board pack et escalation queue.
