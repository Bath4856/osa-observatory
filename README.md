# osa-observatory
 OSA-Observatory - Open source platform computing the African Sovereignty Index (ASI) — 54 African countries, 8 strategic pillars, 120 indicators, historical data 2010→N-2. Automated collection (WB, IMF, WHO, ITU, FAO), L1→L7 pipeline, ML predictions. Stack: PostgreSQL 15 · Python 3.11 · Streamlit · Docker.

# osa-observatory
Observatoire de la Souveraineté Africaine — Indice ISA

## SDMX mode expert

Le systeme OSA integre un moteur de decouverte automatique des structures statistiques SDMX pour identifier dynamiquement:
- datasets
- dimensions
- nomenclatures (codelists)

L integration effective des indicateurs repose ensuite sur une validation metier manuelle garantissant la coherence analytique et la souverainete des donnees.

### Doctrine d automatisation

- AUTOMATISER: decouverte SDMX, ingestion brute, versioning
- SEMI-AUTOMATISER: mapping indicateurs (assisté via suggestions)
- NE JAMAIS AUTOMATISER: validation finale, ponderations, interpretation

### Livrables techniques

- Crawler SDMX IMF + OECD: collectors/sdmx_crawler.py
- Patch SQL discovery + versioning: db/patch_sdmx_discovery.sql
- Pipeline discovery + mapping + validation: collectors/run_sdmx_pipeline.py

### Commandes utiles

- Decouverte IMF (demo live, 10 datasets):
	python collectors/sdmx_crawler.py --provider IMF --limit 10

- Demo live IMF (decouverte + ingestion brute IFS):
	python collectors/sdmx_crawler.py --provider IMF --limit 10 --ingest-dataset IFS --start-year 2020 --end-year 2024 --max-series 30 --db-write

- Decouverte OECD (persist en base):
	python collectors/sdmx_crawler.py --provider OECD --limit 20 --db-write

- Pipeline complet IMF (avec export file de validation):
	python collectors/run_sdmx_pipeline.py --provider IMF --discover-limit 25 --ingest-dataset IFS --validation-export logs/sdmx_validation_queue.csv

- Application reviewer des mappings APPROVED (vers mapping officiel):
	python collectors/run_sdmx_pipeline.py --provider IMF --skip-discovery --skip-ingestion --skip-mapping --apply-approved --reviewer analyste_osa

- Controle qualite des conflits APPROVED (avant application):
	python collectors/run_sdmx_pipeline.py --provider IMF --skip-discovery --skip-ingestion --skip-mapping --check-conflicts --conflicts-export logs/sdmx_conflicts_report.csv

Regle de securite:
- Si des conflits APPROVED existent (meme candidate_code approuve vers plusieurs indicator_code), l'application est bloquee par defaut.
- Forcage explicite possible: ajouter --force-apply-approved.

Exemple de validation manuelle d'une suggestion:
	UPDATE collect.sdmx_mapping_suggestions
	SET status = 'APPROVED', reviewer = 'analyste_osa', reviewed_at = now()
	WHERE id = 123;

## Matrice GO / PILOT / NO_GO

Fichier YAML operationnel:
- matrice_sources_go_nogo_osa.yaml

Patch SQL registry + procedure dynamique:
- db/patch_source_matrix_registry.sql

Parser YAML -> PostgreSQL:
- python collectors/load_source_matrix.py --file matrice_sources_go_nogo_osa.yaml

Plan d ingestion depuis la matrice (GO only):
- python collectors/run_ingestion_from_matrix.py --from 2018 --to 2024 --print-plan

Plan d ingestion depuis la matrice (GO + PILOT):
- python collectors/run_ingestion_from_matrix.py --from 2018 --to 2024 --include-pilot --print-plan

Execution complete avec rapport couverture:
- python collectors/run_ingestion_from_matrix.py --from 2018 --to 2024 --coverage-report

Dashboard GO / PILOT / NO_GO (snapshot):
- python collectors/source_matrix_dashboard.py

Export CSV audit (summary + live + fallback coverage):
- python collectors/source_matrix_dashboard.py --year 2024 --export-csv --export-dir logs/source_dashboard_exports

Preview fallback multi-source (exemple ECO_GDP 2024):
- python collectors/source_matrix_dashboard.py --fallback-indicator ECO_GDP --year 2024

Preview fallback depuis l orchestrateur matrice:
- python collectors/run_ingestion_from_matrix.py --from 2018 --to 2024 --print-plan --fallback-indicator ECO_GDP --fallback-year 2024

SQL fallback ponctuel (pays + indicateur):
- SELECT * FROM collect.resolve_fallback_value('ECO_GDP', 'SEN', 2024, FALSE, 1);

SQL fallback complet (indicateur + annee):
- SELECT * FROM collect.resolve_indicator_fallback_set('ECO_GDP', 2024, FALSE, 1);

SQL couverture fallback par source/indicateur:
- SELECT * FROM collect.v_fallback_coverage_by_source WHERE year = 2024 ORDER BY indicator_code, selected_source_priority;

## Pipeline complet production (L1 -> L6)

Patch SQL procedure maitre:
- db/patch_run_full_osa_pipeline.sql

Activation:
- psql -d osa_db -f db/patch_run_full_osa_pipeline.sql

Cycle complet (mode standard, validation requise):
- SELECT * FROM collect.run_full_osa_pipeline(2024, FALSE, 'OPS', 1, TRUE, NULL, 0.70);

Validation 4-eyes (apres creation d une demande):
- SELECT rf.validate_dataset(1, 'validator_a', 'validator_b', 'sig_hash_a', 'sig_hash_b');

Relance pipeline avec validation approuvee:
- SELECT * FROM collect.run_full_osa_pipeline(2024, FALSE, 'OPS', 1, TRUE, 1, 0.70);

Mode GO + PILOT:
- SELECT * FROM collect.run_full_osa_pipeline(2024, TRUE, 'OPS', 1, TRUE, 1, 0.70);

Suivi run:
- SELECT * FROM collect.pipeline_runs ORDER BY id DESC LIMIT 20;
- SELECT * FROM collect.pipeline_step_logs WHERE run_id = 1 ORDER BY id;
- SELECT * FROM collect.quality_gate_results ORDER BY id DESC LIMIT 20;

## Scheduler nocturne production

Orchestrateur complet (ingestion fetchers + pipeline SQL + export audit):
- python collectors/run_nightly_osa.py --year 2024 --requested-by SCHEDULER --export-audit-csv

Wrapper cron:
- bash ops/run_osa_nightly.sh

Installation cron automatique (idempotente):
- bash ops/install_cron.sh

Exemple crontab pret a copier:
- ops/cron_osa_example.txt

Alerte echec run nocturne (webhook):
- export OSA_ALERT_WEBHOOK_URL="https://votre-webhook"
- bash ops/run_osa_nightly.sh

Test securise du webhook (sans acces DB):
- python collectors/notify_pipeline_failure.py --year 2024 --test-alert --reason "Webhook test" --webhook-url "https://votre-webhook"

Mode recommande (validation humaine requise, pas d auto-approve):
- INCLUDE_PILOT=false REQUIRE_VALIDATION=true EXPORT_AUDIT_CSV=true bash ops/run_osa_nightly.sh

Mode technique (non recommande en production souveraine):
- REQUIRE_VALIDATION=false EXPORT_AUDIT_CSV=true bash ops/run_osa_nightly.sh

