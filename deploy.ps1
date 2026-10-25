# =============================================================================
# deploy.ps1 – Pull from GHCR and Deploy Locally
# =============================================================================
# Usage:
#   .\deploy.ps1                     # Deploy the "latest" image
#   .\deploy.ps1 -Tag "sha-abc123"   # Deploy a specific commit
#
# This script:
#   1. Logs into GitHub Container Registry (GHCR)
#   2. Pulls the specified image tag
#   3. Recreates the application container using Docker Compose
#   4. Waits for the application to become healthy
#   5. Verifies the deployment
#
# Prerequisites:
#   - Docker Desktop running
#   - A GitHub Personal Access Token (classic) with "read:packages" scope
#     stored in the environment variable GHCR_TOKEN, or you will be prompted.
# =============================================================================

param(
    [string]$Tag = "latest"
)

# --- Configuration ---
$GhcrRepo    = "ghcr.io/shams102/library-management-system"
$ComposeFile = "docker-compose.yml"     # Deliberately NOT using override
$HealthUrl   = "http://localhost:5000/health"
$MaxWaitSecs = 60

# --- Helper functions ---
function Write-Stage {
    param([string]$Number, [string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  STAGE ${Number}: ${Title}" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}
function Write-Pass {
    param([string]$Message)
    Write-Host "[PASS] $Message" -ForegroundColor Green
}
function Write-Fail {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

# ======================= DEPLOY START ========================================

$startTime = Get-Date
Write-Host ""
Write-Host ("*" * 60) -ForegroundColor Magenta
Write-Host "  GHCR DEPLOYMENT – Library Management System" -ForegroundColor Magenta
Write-Host "  Image Tag : $Tag" -ForegroundColor Magenta
Write-Host "  Started   : $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Magenta
Write-Host ("*" * 60) -ForegroundColor Magenta

# =============================================================================
# STAGE 1 – AUTHENTICATE WITH GHCR
# =============================================================================
Write-Stage "1" "AUTHENTICATE WITH GHCR"

$ghcrToken = $env:GHCR_TOKEN
if (-not $ghcrToken) {
    Write-Host "No GHCR_TOKEN environment variable found." -ForegroundColor Yellow
    Write-Host "Enter a GitHub PAT with 'read:packages' scope:" -ForegroundColor Yellow
    $ghcrToken = Read-Host -AsSecureString | ConvertFrom-SecureString -AsPlainText
}

# Log in to GHCR
$ghcrToken | docker login ghcr.io -u shams102 --password-stdin 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Fail "GHCR authentication failed. Check your token."
    exit 1
}
Write-Pass "Authenticated with GHCR."

# =============================================================================
# STAGE 2 – PULL THE IMAGE
# =============================================================================
Write-Stage "2" "PULL IMAGE (${GhcrRepo}:${Tag})"

& docker pull "${GhcrRepo}:${Tag}"
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Failed to pull image. Is the tag correct?"
    exit 1
}
Write-Pass "Image pulled successfully."

# =============================================================================
# STAGE 3 – DEPLOY WITH DOCKER COMPOSE
# =============================================================================
Write-Stage "3" "DEPLOY APPLICATION"

# Set environment variables for Compose (uses only docker-compose.yml, NOT override)
$env:IMAGE_NAME = $GhcrRepo
$env:IMAGE_TAG  = $Tag

# Recreate the container with the new image (preserves the data volume)
& docker compose -f $ComposeFile up -d --force-recreate --no-build
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Docker Compose deployment failed."
    exit 1
}
Write-Pass "Application container recreated."

# =============================================================================
# STAGE 4 – WAIT FOR HEALTHY STATUS
# =============================================================================
Write-Stage "4" "WAITING FOR APPLICATION TO BECOME HEALTHY"

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
        # Not ready yet
    }
    Write-Host "  Waiting... ($elapsed/$MaxWaitSecs seconds)" -ForegroundColor Gray
}

if (-not $healthy) {
    Write-Fail "Application did not become healthy within $MaxWaitSecs seconds."
    Write-Host "Check logs: docker compose -f $ComposeFile logs" -ForegroundColor Yellow
    exit 1
}
Write-Pass "Application is healthy (responded in $elapsed seconds)."

# =============================================================================
# STAGE 5 – VERIFY DEPLOYMENT
# =============================================================================
Write-Stage "5" "POST-DEPLOYMENT VERIFICATION"

try {
    $healthResponse = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5
    $healthBody = $healthResponse.Content | ConvertFrom-Json
    if ($healthBody.status -eq "healthy") {
        Write-Pass "Health check passed: status=$($healthBody.status)"
    } else {
        Write-Fail "Unexpected health response: $($healthResponse.Content)"
        exit 1
    }
} catch {
    Write-Fail "Health check failed: $_"
    exit 1
}

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
# SUMMARY
# =============================================================================
$endTime  = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host ("*" * 60) -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "  Duration : $([math]::Round($duration, 1)) seconds" -ForegroundColor Green
Write-Host "  Image    : ${GhcrRepo}:${Tag}" -ForegroundColor Green
Write-Host "  App URL  : http://localhost:5000/" -ForegroundColor Green
Write-Host "  Health   : $HealthUrl" -ForegroundColor Green
Write-Host ("*" * 60) -ForegroundColor Green
Write-Host ""
