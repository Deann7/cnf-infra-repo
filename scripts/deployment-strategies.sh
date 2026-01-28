#!/bin/bash

# Script to demonstrate different Kubernetes deployment strategies
# This script shows examples of Rolling Updates, Blue-Green, and Canary deployments

NAMESPACE="ocloud"
APP_NAME="ocloud-app"
NEW_IMAGE_TAG="v2.0.0"

echo "=== Kubernetes Deployment Strategies Demo ==="

# Function to perform a rolling update
rolling_update() {
    echo "Performing Rolling Update..."
    
    # Update the deployment with a new image
    kubectl set image deployment/$APP_NAME $APP_NAME=image:$NEW_IMAGE_TAG -n $NAMESPACE
    
    # Monitor the rollout
    kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=10m
    
    # Check rollout history
    kubectl rollout history deployment/$APP_NAME -n $NAMESPACE
}

# Function to perform a blue-green deployment
blue_green_deployment() {
    echo "Performing Blue-Green Deployment..."
    
    # Create new deployment with new version
    kubectl set image deployment/$APP_NAME $APP_NAME=image:$NEW_IMAGE_TAG -n $NAMESPACE --dry-run=client -o yaml > temp-new-deployment.yaml
    sed -i 's/'"$APP_NAME"'/'"$APP_NAME"'-green/g' temp-new-deployment.yaml
    kubectl apply -f temp-new-deployment.yaml -n $NAMESPACE
    
    # Wait for new deployment to be ready
    kubectl rollout status deployment/$APP_NAME-green -n $NAMESPACE --timeout=5m
    
    # Update service to point to new deployment
    kubectl patch service $APP_NAME -n $NAMESPACE -p '{"spec":{"selector":{"version":"'"$NEW_IMAGE_TAG"'"}}}'
    
    # Clean up old deployment after validation
    echo "Validate the new version, then delete old deployment if successful:"
    echo "kubectl delete deployment $APP_NAME-blue -n $NAMESPACE"
    
    # Cleanup temporary file
    rm temp-new-deployment.yaml
}

# Function to perform a canary deployment
canary_deployment() {
    echo "Performing Canary Deployment..."
    
    # Scale down production deployment to 2 replicas (from 3)
    kubectl scale deployment/$APP_NAME --replicas=2 -n $NAMESPACE
    
    # Deploy canary version with 1 replica
    kubectl set image deployment/$APP_NAME $APP_NAME=image:$NEW_IMAGE_TAG -n $NAMESPACE --dry-run=client -o yaml > temp-canary-deployment.yaml
    sed -i 's/'"$APP_NAME"'/'"$APP_NAME"'-canary/g' temp-canary-deployment.yaml
    sed -i '/replicas:/c\  replicas: 1' temp-canary-deployment.yaml
    kubectl apply -f temp-canary-deployment.yaml -n $NAMESPACE
    
    # Wait for canary to be ready
    kubectl rollout status deployment/$APP_NAME-canary -n $NAMESPACE --timeout=5m
    
    # Monitor canary for issues
    echo "Monitor canary deployment for issues..."
    sleep 60  # Wait for monitoring period
    
    # If canary is successful, promote to full deployment
    if [ $? -eq 0 ]; then
        echo "Canary successful, promoting to full deployment..."
        kubectl set image deployment/$APP_NAME $APP_NAME=image:$NEW_IMAGE_TAG -n $NAMESPACE
        kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=10m
        
        # Clean up canary deployment
        kubectl delete deployment/$APP_NAME-canary -n $NAMESPACE
    else
        echo "Canary failed, rolling back..."
        kubectl set image deployment/$APP_NAME $APP_NAME=image:previous-version -n $NAMESPACE
        kubectl delete deployment/$APP_NAME-canary -n $NAMESPACE
    fi
    
    # Cleanup temporary file
    rm temp-canary-deployment.yaml
}

# Function to verify deployment health
verify_deployment() {
    echo "Verifying deployment health..."
    
    # Check pod status
    kubectl get pods -n $NAMESPACE
    
    # Check service endpoints
    kubectl get endpoints $APP_NAME -n $NAMESPACE
    
    # Run health checks
    PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$APP_NAME -o jsonpath='{.items[*].metadata.name}')
    for pod in $PODS; do
        kubectl exec $pod -n $NAMESPACE -- curl -f localhost:8080/health
    done
}

# Function to rollback deployment
rollback_deployment() {
    echo "Rolling back deployment..."
    
    # Undo the last deployment
    kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE
    
    # Monitor rollback
    kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=10m
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