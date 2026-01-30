#!/bin/bash

# Script to demonstrate different Kubernetes deployment strategies
# This script shows examples of Rolling Updates, Blue-Green, and Canary deployments

set -e  # Exit immediately if a command exits with a non-zero status

NAMESPACE="ocloud"
APP_NAME="ocloud-app"
NEW_IMAGE_TAG="v2.0.0"

echo "=== Kubernetes Deployment Strategies Demo ==="

# Function to print status
print_status() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

# Function to print success
print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

# Function to print error
print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Function to perform a rolling update
rolling_update() {
    print_status "Performing Rolling Update..."

    # Update the deployment with a new image
    kubectl set image deployment/$APP_NAME $APP_NAME=$APP_NAME:$NEW_IMAGE_TAG -n $NAMESPACE
    
    # Monitor the rollout
    if kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=10m; then
        print_success "Rolling update completed successfully"
    else
        print_error "Rolling update failed"
        exit 1
    fi
    
    # Check rollout history
    kubectl rollout history deployment/$APP_NAME -n $NAMESPACE
}

# Function to perform a blue-green deployment
blue_green_deployment() {
    print_status "Performing Blue-Green Deployment..."
    
    # Define blue-green deployment names
    BLUE_DEPLOYMENT="$APP_NAME-blue"
    GREEN_DEPLOYMENT="$APP_NAME-green"
    MAIN_SERVICE="$APP_NAME"
    
    # Create green deployment with new version
    kubectl get deployment $BLUE_DEPLOYMENT -n $NAMESPACE -o yaml > temp-green-deployment.yaml
    sed -i 's/'"$BLUE_DEPLOYMENT"'/'"$GREEN_DEPLOYMENT"'/g' temp-green-deployment.yaml
    sed -i 's/'"$APP_NAME"':[^"]*/'"$APP_NAME"':'"$NEW_IMAGE_TAG"'/g' temp-green-deployment.yaml
    kubectl apply -f temp-green-deployment.yaml -n $NAMESPACE
    
    # Wait for green deployment to be ready
    if kubectl rollout status deployment/$GREEN_DEPLOYMENT -n $NAMESPACE --timeout=10m; then
        print_success "Green deployment is ready"
    else
        print_error "Green deployment failed to become ready"
        rm temp-green-deployment.yaml
        exit 1
    fi
    
    # Update service to point to green deployment
    kubectl patch service $MAIN_SERVICE -n $NAMESPACE -p '{"spec":{"selector":{"deployment":"'${GREEN_DEPLOYMENT}'"}}}'
    
    print_success "Traffic switched to green deployment"
    echo "Validate the new version, then clean up blue deployment if successful:"
    echo "kubectl delete deployment $BLUE_DEPLOYMENT -n $NAMESPACE"
    
    # Cleanup temporary file
    rm temp-green-deployment.yaml
}

# Function to perform a canary deployment
canary_deployment() {
    print_status "Performing Canary Deployment..."
    
    # Store original replica count
    ORIGINAL_REPLICAS=$(kubectl get deployment/$APP_NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    # Scale down production deployment to 2 replicas (assuming original was 3)
    kubectl scale deployment/$APP_NAME --replicas=$((ORIGINAL_REPLICAS - 1)) -n $NAMESPACE
    
    # Create canary deployment with new version (1 replica)
    kubectl get deployment/$APP_NAME -n $NAMESPACE -o yaml > temp-canary-deployment.yaml
    sed -i 's/'"$APP_NAME"'/'"$APP_NAME"'-canary/g' temp-canary-deployment.yaml
    sed -i 's/replicas:.*/replicas: 1/g' temp-canary-deployment.yaml
    sed -i 's/'"$APP_NAME"':[^"]*/'"$APP_NAME"':'"$NEW_IMAGE_TAG"'/g' temp-canary-deployment.yaml
    kubectl apply -f temp-canary-deployment.yaml -n $NAMESPACE
    
    # Wait for canary to be ready
    if kubectl rollout status deployment/$APP_NAME-canary -n $NAMESPACE --timeout=5m; then
        print_success "Canary deployment is ready"
    else
        print_error "Canary deployment failed to become ready"
        rm temp-canary-deployment.yaml
        exit 1
    fi
    
    # Monitor canary for issues
    print_status "Monitoring canary deployment for issues..."
    sleep 60  # Wait for monitoring period
    
    # Check if canary is healthy
    CANARY_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME-canary -o jsonpath='{.items[*].metadata.name}')
    CANARY_HEALTHY=true
    
    for pod in $CANARY_PODS; do
        if ! kubectl exec $pod -n $NAMESPACE -- timeout 5 sh -c 'curl -f http://localhost:8080/health' &> /dev/null; then
            CANARY_HEALTHY=false
            break
        fi
    done
    
    # If canary is successful, promote to full deployment
    if [ "$CANARY_HEALTHY" = true ]; then
        print_success "Canary successful, promoting to full deployment..."
        kubectl set image deployment/$APP_NAME $APP_NAME=$APP_NAME:$NEW_IMAGE_TAG -n $NAMESPACE
        kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=10m
        
        # Clean up canary deployment
        kubectl delete deployment/$APP_NAME-canary -n $NAMESPACE
        print_success "Canary deployment cleaned up"
    else
        print_error "Canary failed, rolling back..."
        kubectl set image deployment/$APP_NAME $APP_NAME=$APP_NAME:latest -n $NAMESPACE
        kubectl delete deployment/$APP_NAME-canary -n $NAMESPACE
        print_success "Canary deployment rolled back and cleaned up"
    fi
    
    # Cleanup temporary file
    rm temp-canary-deployment.yaml
}

# Function to verify deployment health
verify_deployment() {
    print_status "Verifying deployment health..."
    
    # Check pod status
    kubectl get pods -n $NAMESPACE
    
    # Check service endpoints
    kubectl get endpoints $APP_NAME -n $NAMESPACE
    
    # Run health checks
    PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME -o jsonpath='{.items[*].metadata.name}')
    for pod in $PODS; do
        if kubectl exec $pod -n $NAMESPACE -- timeout 5 sh -c 'curl -f http://localhost:8080/health' &> /dev/null; then
            print_success "Health check passed for pod: $pod"
        else
            print_error "Health check failed for pod: $pod"
        fi
    done
}

# Function to rollback deployment
rollback_deployment() {
    print_status "Rolling back deployment..."
    
    # Undo the last deployment
    if kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE; then
        print_success "Rollback initiated successfully"
    else
        print_error "Rollback failed"
        exit 1
    fi
    
    # Monitor rollback
    if kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=10m; then
        print_success "Rollback completed successfully"
    else
        print_error "Rollback failed to complete"
        exit 1
    fi
}

# Main menu
case $1 in
    "rolling")
        rolling_update
        ;;
    "blue-green")
        blue_green_deployment
        ;;
    "canary")
        canary_deployment
        ;;
    "verify")
        verify_deployment
        ;;
    "rollback")
        rollback_deployment
        ;;
    *)
        echo "Usage: $0 {rolling|blue-green|canary|verify|rollback}"
        echo "  rolling     - Perform a rolling update"
        echo "  blue-green  - Perform a blue-green deployment"
        echo "  canary      - Perform a canary deployment"
        echo "  verify      - Verify deployment health"
        echo "  rollback    - Rollback to previous version"
        ;;
esac