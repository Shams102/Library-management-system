# =============================================================================
# pipeline.ps1 – Local CI/CD Pipeline for Library Management System
# =============================================================================
# Usage:   .\pipeline.ps1
# Purpose: Automates testing, building, deploying, and verifying the app.
# =============================================================================

# --- Configuration ---
$ImageName   = "library-management"
$ImageTag    = "v1"
$FullImage   = "${ImageName}:${ImageTag}"
$ComposeFile = "docker-compose.yml"
$HealthUrl   = "http://localhost:5000/health"
$MaxWaitSecs = 60

# --- Helper: print a stage banner ---
function Write-Stage {
    param([string]$Number, [string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  STAGE ${Number}: ${Title}" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}

# --- Helper: print result ---
function Write-Pass {
    param([string]$Message)
    Write-Host "[PASS] $Message" -ForegroundColor Green
}
function Write-Fail {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

# ======================= PIPELINE START ======================================

$startTime = Get-Date
Write-Host ""
Write-Host ("*" * 60) -ForegroundColor Yellow
Write-Host "  LIBRARY MANAGEMENT SYSTEM – CI/CD PIPELINE" -ForegroundColor Yellow
Write-Host "  Started: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
Write-Host ("*" * 60) -ForegroundColor Yellow

# =============================================================================
# STAGE 1 – ENVIRONMENT CHECK
# =============================================================================
Write-Stage "1" "ENVIRONMENT CHECK"

# Check Python
try {
    $pyVersion = & python --version 2>&1
    Write-Pass "Python found: $pyVersion"
} catch {
    Write-Fail "Python is not installed or not in PATH."
    exit 1
}

# Check Docker
try {
    $dkVersion = & docker --version 2>&1
    Write-Pass "Docker found: $dkVersion"
} catch {
    Write-Fail "Docker is not installed or not in PATH."
    exit 1
}

# =============================================================================
# STAGE 2 – RUN AUTOMATED TESTS
# =============================================================================
Write-Stage "2" "AUTOMATED TESTING (pytest)"

Write-Host "Installing Python dependencies..." -ForegroundColor Gray
& pip install -r requirements.txt --quiet 2>&1 | Out-Null

Write-Host "Running test suite..." -ForegroundColor Gray
& python -m pytest tests/ -v
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Tests failed! Deployment aborted."
    Write-Host ""
    Write-Host "Fix the failing tests before re-running the pipeline." -ForegroundColor Red
    exit 1
}
Write-Pass "All tests passed."

# =============================================================================
# STAGE 3 – BUILD DOCKER IMAGE
# =============================================================================
Write-Stage "3" "BUILD DOCKER IMAGE ($FullImage)"

& docker build -t $FullImage .
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Docker image build failed."
    exit 1
}
Write-Pass "Docker image '$FullImage' built successfully."

# =============================================================================
# STAGE 4 – DEPLOY WITH DOCKER COMPOSE
# =============================================================================
Write-Stage "4" "DEPLOY APPLICATION"

# Bring up (or recreate) the services
# Note: We explicitly load both compose files. The override adds the "build:" directive.
& docker compose -f $ComposeFile -f docker-compose.override.yml up -d --build --force-recreate
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Docker Compose deployment failed."
    exit 1
}
Write-Pass "Application containers started."

# =============================================================================
# STAGE 5 – WAIT FOR HEALTHY STATUS
# =============================================================================
Write-Stage "5" "WAITING FOR APPLICATION TO BECOME HEALTHY"

$elapsed = 0
$healthy = $false

while ($elapsed -lt $MaxWaitSecs) {
    Start-Sleep -Seconds 3
    $elapsed += 3

    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $healthy = $true
            break
        }
    } catch {
        # Not ready yet – keep waiting
    }

    Write-Host "  Waiting... ($elapsed/$MaxWaitSecs seconds)" -ForegroundColor Gray
}

if (-not $healthy) {
    Write-Fail "Application did not become healthy within $MaxWaitSecs seconds."
    Write-Host "Check logs with: docker compose logs" -ForegroundColor Yellow
    exit 1
}
Write-Pass "Application is healthy (responded in $elapsed seconds)."

# =============================================================================
# STAGE 6 – POST-DEPLOYMENT HEALTH CHECK
# =============================================================================
Write-Stage "6" "POST-DEPLOYMENT VERIFICATION"

try {
    $healthResponse = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5
    $healthBody = $healthResponse.Content | ConvertFrom-Json

    if ($healthBody.status -eq "healthy") {
        Write-Pass "Health check passed: status=$($healthBody.status), service=$($healthBody.service)"
    } else {
        Write-Fail "Unexpected health response: $($healthResponse.Content)"
        exit 1
    }
} catch {
    Write-Fail "Post-deployment health check failed: $_"
    exit 1
}

# Also verify the home page loads
try {
    $homeResponse = Invoke-WebRequest -Uri "http://localhost:5000/" -UseBasicParsing -TimeoutSec 5
    if ($homeResponse.StatusCode -eq 200) {
        Write-Pass "Home page is accessible at http://localhost:5000/"
    }
} catch {
    Write-Fail "Home page is not accessible: $_"
    exit 1
}

# =============================================================================
# STAGE 7 – PIPELINE SUMMARY
# =============================================================================
$endTime  = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host ("*" * 60) -ForegroundColor Green
Write-Host "  PIPELINE COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "  Duration : $([math]::Round($duration, 1)) seconds" -ForegroundColor Green
Write-Host "  Image    : $FullImage" -ForegroundColor Green
Write-Host "  App URL  : http://localhost:5000/" -ForegroundColor Green
Write-Host "  Health   : $HealthUrl" -ForegroundColor Green
Write-Host ("*" * 60) -ForegroundColor Green
Write-Host ""
