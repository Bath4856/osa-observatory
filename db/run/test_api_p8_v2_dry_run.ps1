param(
  [string]$ApiBase = "http://localhost:8000"
)

Write-Host "========================================="
Write-Host " OSA — API P8 V2 DRY RUN"
Write-Host "========================================="

function Test-Endpoint {
    param([string]$Url, [string]$Label, [hashtable]$Headers = @{})
    Write-Host ""
    Write-Host ">>> $Label"
    Write-Host "    GET $Url"
    try {
        $resp = Invoke-WebRequest -Uri $Url -Headers $Headers -UseBasicParsing -TimeoutSec 10
        $body = $resp.Content | ConvertFrom-Json
        $count = if ($body.count) { $body.count } else { "—" }
        Write-Host "    Status : $($resp.StatusCode) | rows : $count"
        if ($resp.StatusCode -ne 200) { throw "HTTP $($resp.StatusCode)" }
    } catch {
        Write-Host "    ❌ ERREUR : $_"
    }
}

# Health
Test-Endpoint "$ApiBase/"        "Root"
Test-Endpoint "$ApiBase/health"  "Health check"

# Release
Test-Endpoint "$ApiBase/api/v2/release"             "Release manifest"

# Countries
Test-Endpoint "$ApiBase/api/v2/countries"           "Countries latest"
Test-Endpoint "$ApiBase/api/v2/countries/MAR"       "Country profile MAR"
Test-Endpoint "$ApiBase/api/v2/countries/MAR/history"   "Country history MAR"
Test-Endpoint "$ApiBase/api/v2/countries/MAR/pillars"   "Country pillars MAR"

# Rankings
Test-Endpoint "$ApiBase/api/v2/rankings/latest"     "Rankings latest"
Test-Endpoint "$ApiBase/api/v2/rankings/year/2024"  "Rankings 2024"

# Predictive — public
Test-Endpoint "$ApiBase/api/v2/predictive/readiness"        "P7Z readiness all"
Test-Endpoint "$ApiBase/api/v2/predictive/readiness/MDG"    "P7Z readiness MDG"
Test-Endpoint "$ApiBase/api/v2/predictive/fragility"        "Sovereign fragility"

# Opportunities + Methodology
Test-Endpoint "$ApiBase/api/v2/opportunities"       "Opportunities"
Test-Endpoint "$ApiBase/api/v2/methodology"         "Methodology"

# OpenAPI export
Write-Host ""
Write-Host ">>> OpenAPI spec"
try {
    $spec = Invoke-WebRequest -Uri "$ApiBase/openapi.json" -UseBasicParsing
    $json = $spec.Content | ConvertFrom-Json
    Write-Host "    Endpoints définis : $($json.paths.PSObject.Properties.Count)"
    Write-Host "    Version : $($json.info.version)"
} catch {
    Write-Host "    ❌ OpenAPI non accessible : $_"
}

# Expert endpoint — sans clé (doit retourner 401)
Write-Host ""
Write-Host ">>> P7Z signals sans clé (doit retourner 401)"
try {
    Invoke-WebRequest -Uri "$ApiBase/api/v2/predictive/signals" -UseBasicParsing
    Write-Host "    ❌ ERREUR : devrait retourner 401"
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 401) {
        Write-Host "    ✅ 401 Unauthorized — accès expert protégé"
    } else {
        Write-Host "    ❌ Statut inattendu : $_"
    }
}

Write-Host ""
Write-Host "========================================="
Write-Host " ✅ API P8 V2 DRY RUN TERMINÉ"
Write-Host "========================================="
Write-Host ""
Write-Host ">>> Exporter la spec OpenAPI :"
Write-Host "    curl $ApiBase/openapi.json -o OPENAPI_P8_V2.json"
