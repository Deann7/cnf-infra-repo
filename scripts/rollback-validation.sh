#!/bin/bash
# rollback-validation.sh - Validate rollback procedures

set -e

echo "Starting rollback procedure validation..."

# Get current deployment revision
CURRENT_REVISION=$(kubectl get deployment cnf-app-deployment -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')

echo "Current deployment revision: $CURRENT_REVISION"

# Deploy a faulty version to test rollback
kubectl set image deployment/cnf-app-deployment cnf-container=my-cnf-app:broken-tag || true

# Wait for deployment to fail
sleep 30

# Check deployment status
FAILED_STATUS=$(kubectl get deployment cnf-app-deployment -o jsonpath='{.status.conditions[?(@.type=="Progressing")].reason}')

if [[ "$FAILED_STATUS" == "ProgressDeadlineExceeded" ]]; then
    echo "Deployment correctly failed as expected"
    
    # Rollback to previous version
    echo "Initiating rollback..."
    kubectl rollout undo deployment/cnf-app-deployment
    
    # Wait for rollback to complete
    kubectl rollout status deployment/cnf-app-deployment --timeout=300s
    
    # Verify rollback was successful
    NEW_REVISION=$(kubectl get deployment cnf-app-deployment -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
    
    if [[ "$NEW_REVISION" -lt "$CURRENT_REVISION" ]]; then
        echo "Rollback validation successful - reverted to revision $NEW_REVISION"
    else
        echo "Rollback validation failed"
        exit 1
    fi
else
    echo "Deployment did not fail as expected - skipping rollback test"
    # Restore the correct image if the test didn't fail as expected
    kubectl set image deployment/cnf-app-deployment cnf-container=ghcr.io/Deann7/cnf-simulator:latest
fi

echo "Rollback procedure validation completed!"