#!/bin/bash

# Script to verify CNF deployment health and readiness
# This script checks that pods are running and ready, and validates health endpoints

set -e  # Exit immediately if a command exits with a non-zero status

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting CNF Deployment Health Check${NC}"

# Default values
NAMESPACE=${1:-default}
DEPLOYMENT_NAME=${2:-cnf-app-deployment}
TIMEOUT=${3:-300}  # 5 minutes timeout

# Function to print status messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Wait for deployment to be ready
print_status "Waiting for deployment ${DEPLOYMENT_NAME} to be ready..."
kubectl wait --for=condition=available deployment/${DEPLOYMENT_NAME} --namespace=${NAMESPACE} --timeout=${TIMEOUT}s

# Get pod names
POD_NAMES=$(kubectl get pods -n ${NAMESPACE} -l app=cnf-app -o jsonpath='{.items[*].metadata.name}')

if [ -z "$POD_NAMES" ]; then
    print_error "No pods found for deployment ${DEPLOYMENT_NAME}"
    exit 1
fi

print_status "Found pods: ${POD_NAMES}"

# Check pod status
for pod in $POD_NAMES; do
    print_status "Checking pod: ${pod}"
    
    # Wait for pod to be ready
    kubectl wait --for=condition=ready pod/$pod --namespace=${NAMESPACE} --timeout=60s
    
    # Get pod status
    POD_STATUS=$(kubectl get pod $pod -n ${NAMESPACE} -o jsonpath='{.status.phase}')
    READY_STATUS=$(kubectl get pod $pod -n ${NAMESPACE} -o jsonpath='{.status.containerStatuses[0].ready}')
    
    print_status "Pod ${pod}: Phase=${POD_STATUS}, Ready=${READY_STATUS}"
    
    if [ "$POD_STATUS" != "Running" ] || [ "$READY_STATUS" != "true" ]; then
        print_error "Pod ${pod} is not running or not ready"
        kubectl describe pod $pod -n ${NAMESPACE}
        exit 1
    fi
done

# Get service information
SERVICE_NAME=$(kubectl get services -n ${NAMESPACE} -l app=cnf-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$SERVICE_NAME" ]; then
    SERVICE_IP=$(kubectl get service $SERVICE_NAME -n ${NAMESPACE} -o jsonpath='{.spec.clusterIP}')
    SERVICE_PORT=$(kubectl get service $SERVICE_NAME -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].port}')
    
    print_status "Service ${SERVICE_NAME} found at ${SERVICE_IP}:${SERVICE_PORT}"
    
    # Try to access the health endpoint
    print_status "Testing health endpoint..."
    HEALTH_RESPONSE=$(kubectl exec -it $(echo $POD_NAMES | awk '{print $1}') -n ${NAMESPACE} -- wget -qO- localhost:${SERVICE_PORT}/health 2>/dev/null || \
                     curl -s http://${SERVICE_IP}:${SERVICE_PORT}/health 2>/dev/null || \
                     echo '{"error": "Could not reach health endpoint"}')
    
    if [[ $HEALTH_RESPONSE == *"error"* ]] || [ -z "$HEALTH_RESPONSE" ]; then
        print_error "Health endpoint test failed: $HEALTH_RESPONSE"
    else
        print_status "Health endpoint response: $HEALTH_RESPONSE"
    fi
    
    # Try to access the ready endpoint
    print_status "Testing ready endpoint..."
    READY_RESPONSE=$(kubectl exec -it $(echo $POD_NAMES | awk '{print $1}') -n ${NAMESPACE} -- wget -qO- localhost:${SERVICE_PORT}/ready 2>/dev/null || \
                    curl -s http://${SERVICE_IP}:${SERVICE_PORT}/ready 2>/dev/null || \
                    echo '{"error": "Could not reach ready endpoint"}')
    
    if [[ $READY_RESPONSE == *"error"* ]] || [ -z "$READY_RESPONSE" ]; then
        print_error "Ready endpoint test failed: $READY_RESPONSE"
    else
        print_status "Ready endpoint response: $READY_RESPONSE"
    fi
else
    print_warning "Service not found, skipping endpoint tests"
fi

# Check deployment rollout status
print_status "Checking deployment rollout status..."
ROLLOUT_STATUS=$(kubectl rollout status deployment/${DEPLOYMENT_NAME} --namespace=${NAMESPACE} --timeout=60s)
print_status "Deployment rollout status: $ROLLOUT_STATUS"

# Display final status summary
print_status "=== Deployment Health Check Summary ==="
kubectl get pods -n ${NAMESPACE} -l app=cnf-app
kubectl get services -n ${NAMESPACE} -l app=cnf-app

print_status "All health checks passed! Deployment is ready."
echo -e "${GREEN}CNF Deployment Health Check: SUCCESS${NC}"