# P7I-AMAR — Atrocity & Mass Atrocity Risk Extension

## 1. Décision d’architecture

Ce pack respecte la décision suivante :

```text
KEEP P7G
KEEP P7I CORE
EXTEND P7I
OPTIONALLY ENRICH P7H SCENARIOS
```

Il ne remplace pas :

```text
ma.v_p7i_risk_source
ma.v_isa_early_warning_engine
ma.v_isa_risk_escalation_engine
ma.v_isa_early_warning_country_year
```

Il ajoute uniquement une extension métier :

```text
P7I-AMAR
```

## 2. Objectif

P7I-AMAR ajoute un domaine d’alerte précoce orienté :

- protection des civils
- signaux précurseurs d’atrocités de masse
- fragilité structurelle
- escalade sécuritaire
- stress humanitaire
- polarisation informationnelle
- conflit de ressources

## 3. Important : formulation institutionnelle

À utiliser :

```text
Atrocity precursor early warning
Civilian protection risk
Mass violence prevention signal
```

À éviter dans l’API publique :

```text
genocide prediction
legal genocide classification
responsibility attribution
```

P7I-AMAR ne qualifie juridiquement ni génocide, ni crime contre l’humanité, ni crime de guerre.

## 4. Entrées utilisées

La vue principale utilisée est :

```text
ma.v_p7i_risk_source
```

Colonnes utilisées :

```text
country_iso3
year
pillar_code
weakness_score
threat_score
strategic_risk_score
vulnerability_observed_score
resilience_observed_score
observation_confidence
forecast_observation_confidence
isa_trend_slope
isa_volatility
stress_isa_delta
stress_simulation_confidence
central_isa_delta
forecast_trend_status
forecast_blocking_reason
strategic_attention_class
strategic_diagnostic_role
```

## 5. Sorties créées

```text
ma.v_p7i_amar_atrocity_precursor_engine
ma.v_p7i_amar_dashboard
mg.v_public_p7i_amar_alerts
mg.risk_taxonomy
mg.early_warning_alerts
```

## 6. Échelle de scoring

Le score AMAR est sur une échelle `0–1`.

```text
GREEN  < 0.25
YELLOW < 0.45
ORANGE < 0.65
RED    < 0.80
BLACK  >= 0.80
```

`BLACK` signifie : revue urgente de protection des civils.  
Ce n’est pas une qualification juridique.

## 7. Installation

Depuis la racine du projet :

```powershell
cd G:\osa-observatory
```

Copier les fichiers du pack dans la racine du dépôt, puis lancer :

```powershell
.\db\run\run_p7i_amar_extension.ps1
```

## 8. Test

```powershell
.\db\run\test_p7i_amar_dry_run.ps1
```

## 9. Audit

```powershell
psql -h 127.0.0.1 -U postgres -d osa_db -f audit\p7i_amar_report.sql
```

## 10. Rollback

```powershell
.\db\run\rollback_p7i_amar_extension.ps1
```

Le rollback supprime les vues et objets AMAR, sans toucher au P7I Core.

## 11. Prochaine étape recommandée

Après validation technique :

- ajouter endpoints API `/api/v1/p7i/amar`
- ajouter documentation Swagger
- enrichir éventuellement P7H avec scénarios :
  - ELECTION_CRISIS
  - RESOURCE_CAPTURE
  - BORDER_ESCALATION
  - FOOD_SHOCK
  - MILITIA_SURGE
  - INFO_WARFARE
