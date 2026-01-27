#!/bin/bash

# Deployment script for O-Cloud Application
# This script handles the deployment of the O-Cloud application using Helm

set -e  # Exit immediately if a command exits with a non-zero status

# Default values
ENVIRONMENT="dev"
NAMESPACE="default"
TIMEOUT="600s"
DRY_RUN=false

# Function to print status
print_status() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

# Function to print success
print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

# Function to print warning
print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# Function to print error
print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Print usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -e, --environment ENV    Set environment (dev, staging, prod) [default: dev]"
    echo "  -n, --namespace NS       Set namespace [default: default]"
    echo "  -t, --timeout TIMEOUT   Set deployment timeout [default: 600s]"
    echo "  --dry-run               Perform a dry run without actual deployment"
    echo "  -h, --help              Show this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate environment
case $ENVIRONMENT in
    dev|staging|prod)
        ;;
    *)
        print_error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
        exit 1
        ;;
esac

print_status "Starting deployment for environment: $ENVIRONMENT"
print_status "Namespace: $NAMESPACE"
print_status "Timeout: $TIMEOUT"

if [[ "$DRY_RUN" == "true" ]]; then
    print_warning "DRY RUN MODE: No actual deployment will occur"
fi

# Validate prerequisites
print_status "Validating prerequisites..."

if ! command -v helm &> /dev/null; then
    print_error "helm is not installed"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

# Run validation script first
print_status "Running infrastructure validation..."
if [[ "$DRY_RUN" == "false" ]]; then
    if ! ./validate.sh; then
        print_error "Validation failed. Aborting deployment."
        exit 1
    fi
    print_success "Validation passed"
fi

# Determine values file based on environment
VALUES_FILE="charts/ocloud-app/values.yaml"
ENV_VALUES_FILE="charts/ocloud-app/values-$ENVIRONMENT.yaml"

if [[ -f "$ENV_VALUES_FILE" ]]; then
    VALUES_FILE="$ENV_VALUES_FILE"
    print_status "Using environment-specific values file: $VALUES_FILE"
else
    print_warning "Environment-specific values file not found: $ENV_VALUES_FILE"
    print_status "Using default values file: $VALUES_FILE"
fi

# Create namespace if it doesn't exist
if [[ "$DRY_RUN" == "false" ]]; then
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_status "Creating namespace: $NAMESPACE"
        kubectl create namespace "$NAMESPACE"
    fi
fi

# Prepare extra values based on environment
EXTRA_VALUES=""
case $ENVIRONMENT in
    prod)
        EXTRA_VALUES="--set replicaCount=3 --set resources.requests.cpu=500m --set resources.requests.memory=1Gi --set resources.limits.cpu=1000m --set resources.limits.memory=2Gi"
        ;;
    staging)
        EXTRA_VALUES="--set replicaCount=2 --set resources.requests.cpu=250m --set resources.requests.memory=512Mi --set resources.limits.cpu=500m --set resources.limits.memory=1Gi"
        ;;
    dev)
        EXTRA_VALUES="--set replicaCount=1 --set resources.requests.cpu=100m --set resources.requests.memory=128Mi --set resources.limits.cpu=200m --set resources.limits.memory=256Mi"
        ;;
esac

# Perform the deployment
DEPLOYMENT_NAME="ocloud-app-$ENVIRONMENT"

print_status "Deploying application: $DEPLOYMENT_NAME"

HELM_COMMAND="helm upgrade --install $DEPLOYMENT_NAME charts/ocloud-app -f $VALUES_FILE --namespace $NAMESPACE --timeout $TIMEOUT $EXTRA_VALUES --wait"

if [[ "$DRY_RUN" == "true" ]]; then
    print_status "Would execute: $HELM_COMMAND"
else
    print_status "Executing: $HELM_COMMAND"
    eval $HELM_COMMAND
    
    if [[ $? -ne 0 ]]; then
        print_error "Helm deployment failed"
        exit 1
    fi
    
    print_success "Helm deployment completed"
fi

# Verify deployment status
if [[ "$DRY_RUN" == "false" ]]; then
    print_status "Verifying deployment status..."
    
    # Wait for pods to be ready
    PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=ocloud-app -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $PODS; do
        print_status "Waiting for pod $pod to be ready..."
        kubectl wait --for=condition=Ready pod/"$pod" -n "$NAMESPACE" --timeout="$TIMEOUT"
    done
    
    print_success "All pods are ready"
    
    # Get service information
    SERVICES=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=ocloud-app -o jsonpath='{.items[*].metadata.name}')
    for service in $SERVICES; do
        SERVICE_INFO=$(kubectl get svc "$service" -n "$NAMESPACE" -o wide)
        print_status "Service information for $service:\n$SERVICE_INFO"
    done
fi

# Display deployment summary
print_status "Deployment Summary:"
if [[ "$DRY_RUN" == "false" ]]; then
    kubectl get pods,services,ingresses -n "$NAMESPACE" -l app.kubernetes.io/name=ocloud-app
fi

print_success "Deployment completed successfully for environment: $ENVIRONMENT"