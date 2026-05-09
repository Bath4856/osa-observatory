## Un bloc :

& "C:\Program Files\PostgreSQL\17\bin\psql.exe" `
  -U postgres `
  -d osa_db `
  -f "G:\osa-observatory\audit\audit_maping_blocs\A_mapping_overview.sql"

##Tous les blocs (batch) :
run_all_audit.ps1

Via vue :
Intallation des vues dans powershell

cd G:\osa-observatory\db
.\run_mapping_views.ps1

ou

G:\osa-observatory\db\run_mapping_views.ps1

Write-Host ">>> Installation des vues OSA ISA..."

& "C:\Program Files\PostgreSQL\17\bin\psql.exe" `
  -U postgres `
  -d osa_db `
  -f "G:\osa-observatory\db\install_views.sql"

Write-Host ">>> Terminé."

## Utlisation

🔍 📊 COMMENT L’UTILISER

🟢 1. Voir les pires indicateurs
SELECT *
FROM ma.v_mapping_quality_score
WHERE quality_class = 'D — CRITIQUE'
ORDER BY mapping_quality_score;

🔴 2. Identifier les ORPHELINS (Bloc H automatique)
SELECT *
FROM ma.v_mapping_quality_score
WHERE orphan_flag = 'ORPHELIN';

🟡 3. Contrôle ISA
SELECT *
FROM ma.v_mapping_quality_score
WHERE isa_status = 'EXCLU ISA';

🟣 4. Score moyen par pilier
SELECT
    pillar_code,
    ROUND(AVG(mapping_quality_score), 3) AS avg_score
FROM ma.v_mapping_quality_score
GROUP BY pillar_code
ORDER BY avg_score;