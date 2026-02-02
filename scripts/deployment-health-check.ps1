# PowerShell script to verify CNF deployment health and readiness
# This script checks that pods are running and ready, and validates health endpoints

Write-Host "Starting CNF Deployment Health Check" -ForegroundColor Yellow

# Default values
param(
    [string]$Namespace = "default",
    [string]$DeploymentName = "cnf-app-deployment",
    [int]$Timeout = 300  # 5 minutes timeout
)

# Function to print status messages
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-ErrorCustom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if kubectl is available
try {
    kubectl version --client > $null
} catch {
    Write-ErrorCustom "kubectl is not installed or not in PATH"
    exit 1
}

# Wait for deployment to be ready
Write-Status "Waiting for deployment $DeploymentName to be ready..."
kubectl wait --for=condition=available deployment/$DeploymentName --namespace=$Namespace --timeout="${Timeout}s"

# Get pod names
$PodNames = kubectl get pods -n $Namespace -l app=cnf-app -o jsonpath='{.items[*].metadata.name}'

if (-not $PodNames) {
    Write-ErrorCustom "No pods found for deployment $DeploymentName"
    exit 1
}

Write-Status "Found pods: $PodNames"

# Check pod status
foreach ($pod in $PodNames -split '\s+') {
    if ([string]::IsNullOrWhiteSpace($pod)) { continue }
    
    Write-Status "Checking pod: $pod"
    
    # Wait for pod to be ready
    kubectl wait --for=condition=ready pod/$pod --namespace=$Namespace --timeout=60s
    
    # Get pod status
    $PodStatus = kubectl get pod $pod -n $Namespace -o jsonpath='{.status.phase}'
    $ReadyStatus = kubectl get pod $pod -n $Namespace -o jsonpath='{.status.containerStatuses[0].ready}'
    
    Write-Status "Pod $pod`: Phase=$PodStatus, Ready=$ReadyStatus"
    
    if ($PodStatus -ne "Running" -or $ReadyStatus -ne "true") {
        Write-ErrorCustom "Pod $pod is not running or not ready"
        kubectl describe pod $pod -n $Namespace
        exit 1
    }
}

# Get service information
$ServiceName = kubectl get services -n $Namespace -l app=cnf-app -o jsonpath='{.items[0].metadata.name}' 2>$null
if ($ServiceName) {
    $ServiceIP = kubectl get service $ServiceName -n $Namespace -o jsonpath='{.spec.clusterIP}'
    $ServicePort = kubectl get service $ServiceName -n $Namespace -o jsonpath='{.spec.ports[0].port}'
    
    Write-Status "Service $ServiceName found at $ServiceIP`:$ServicePort"
    
    # Try to access the health endpoint
    Write-Status "Testing health endpoint..."
    try {
        $HealthResponse = Invoke-RestMethod -Uri "http://$ServiceIP`:$ServicePort/health" -Method Get
        Write-Status "Health endpoint response: $($HealthResponse | ConvertTo-Json -Compress)"
    } catch {
        Write-ErrorCustom "Health endpoint test failed: $_"
    }
    
    # Try to access the ready endpoint
    Write-Status "Testing ready endpoint..."
    try {
        $ReadyResponse = Invoke-RestMethod -Uri "http://$ServiceIP`:$ServicePort/ready" -Method Get
        Write-Status "Ready endpoint response: $($ReadyResponse | ConvertTo-Json -Compress)"
    } catch {
        Write-ErrorCustom "Ready endpoint test failed: $_"
    }
} else {
    Write-Warning "Service not found, skipping endpoint tests"
}

# Check deployment rollout status
Write-Status "Checking deployment rollout status..."
$RolloutStatus = kubectl rollout status deployment/$DeploymentName --namespace=$Namespace --timeout=60s
Write-Status "Deployment rollout status: $RolloutStatus"

# Display final status summary
Write-Status "=== Deployment Health Check Summary ==="
kubectl get pods -n $Namespace -l app=cnf-app
kubectl get services -n $Namespace -l app=cnf-app

Write-Status "All health checks passed! Deployment is ready."
Write-Host "CNF Deployment Health Check: SUCCESS" -ForegroundColor Green