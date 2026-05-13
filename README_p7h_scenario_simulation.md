# P7H — ISA Scenario Simulation Intelligence Engine

## Mission

P7H transforme :

- P7F strategic diagnostic intelligence
- P7G forecast intelligence

En simulations déterministes :

- what-if
- policy simulation
- investment scenario
- stress test
- simulated ISA delta

P7H ne certifie pas, ne publie pas officiellement, ne crée pas de premium trigger.

## Architecture

```text
db/patch_db/patch_p7h_scenario_simulation.sql

db/views/ma/v_p7h_scenario_source.sql
db/views/ma/v_isa_scenario_policy_engine.sql
db/views/ma/v_isa_scenario_simulation_engine.sql
db/views/ma/v_isa_scenario_country_year.sql
db/views/ma/v_isa_scenario_readiness.sql

audit/list_p7h_source_columns.sql
audit/p7h_scenario_simulation_report.sql

db/run/run_p7h_scenario_simulation.ps1
db/run/test_p7h_dry_run.ps1
```

## Scénarios

- BASELINE
- CONSERVATIVE
- CENTRAL
- AMBITIOUS
- STRESS

## Outputs principaux

- simulated_isa_delta
- simulated_sovereignty_delta
- simulated_vulnerability_delta
- simulated_resilience_delta
- simulated_isa_score
- simulation_confidence
- simulation_decision

## Exécution

```powershell
cd G:\osa-observatory
.\db\run\run_p7h_scenario_simulation.ps1
.\db\run\test_p7h_dry_run.ps1
```

## Gouvernance

P7H est une couche simulationnelle. Les opportunités validées et produits investisseurs seront traités dans P7J.
