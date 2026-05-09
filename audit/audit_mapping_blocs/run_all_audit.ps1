$files = @(
 "00_header.sql",
 "A_mapping_overview.sql",
 "B_mapped_indicators.sql",
 "C_unmapped_indicators.sql",
 "D_registry_status.sql",
 "E_provider_codes.sql",
 "F_mapping_coverage.sql",
 "G_registry_vs_mapping.sql",
 "H_orphan_data.sql",
 "Z_summary.sql"
)

foreach ($f in $files) {
  Write-Host ">>> Running $f"
  & "C:\Program Files\PostgreSQL\17\bin\psql.exe" `
    -U postgres `
    -d osa_db `
    -f "G:\osa-observatory\audit\audit_mapping_blocs\$f"
}