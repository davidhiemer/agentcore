# Build and Push Agent Images to ECR
# Usage: .\build-and-push.ps1 -AccountId 574816783000 -Region us-west-2 -AgentName customer-support

param(
    [Parameter(Mandatory=$true)]
    [string]$AccountId,
    
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$true)]
    [string]$AgentName,
    
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

# Repository name (uses slash separator: agentcore-v2-dev/customer-support)
$REPO_NAME = "agentcore-v2-$Environment/$AgentName"

# ECR repository URL
$ECR_REPO = "$AccountId.dkr.ecr.$Region.amazonaws.com/$REPO_NAME"

Write-Host "Building and pushing image for agent: $AgentName" -ForegroundColor Cyan

# Login to ECR
Write-Host "Logging into ECR..." -ForegroundColor Yellow
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin "$AccountId.dkr.ecr.$Region.amazonaws.com"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to login to ECR" -ForegroundColor Red
    exit 1
}

# Check if repository exists
Write-Host "Checking if ECR repository[$REPO_NAME] exists..." -ForegroundColor Yellow
$ErrorActionPreference = "Continue"
aws ecr describe-repositories --repository-names $REPO_NAME --region $Region 2>&1 | Out-Null
$repoCheckResult = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($repoCheckResult -ne 0) {
    Write-Host "ERROR: ECR repository '$REPO_NAME' does not exist." -ForegroundColor Red
    Write-Host "Please create it first using Terraform before running this script." -ForegroundColor Yellow
    exit 1
}
Write-Host "Repository exists" -ForegroundColor Green

# Build and push image in one step
# --platform linux/arm64 is required by Bedrock AgentCore
# --provenance=false disables attestation manifests that ECR rejects
# --push pushes directly to ECR after build
Write-Host "Building and pushing Docker image (arm64)..." -ForegroundColor Yellow
docker buildx build --platform linux/arm64 --provenance=false --push -t "${ECR_REPO}:latest" ./hello-world
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build/push Docker image" -ForegroundColor Red
    exit 1
}

# Get the digest
Write-Host "Getting image digest..." -ForegroundColor Yellow
$DIGEST = aws ecr describe-images --repository-name $REPO_NAME --region $Region --query 'imageDetails[?imageTags[?contains(@, `latest`)]].imageDigest' --output text
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($DIGEST)) {
    Write-Host "Failed to get image digest" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Image pushed successfully!" -ForegroundColor Green
Write-Host "Repository: $ECR_REPO" -ForegroundColor White
Write-Host "Digest: $DIGEST" -ForegroundColor White
Write-Host ""
Write-Host "Update your terraform.tfvars with:" -ForegroundColor Yellow
Write-Host "  container_image_digest = `"$DIGEST`"" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Green


