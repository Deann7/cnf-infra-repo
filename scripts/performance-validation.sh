#!/bin/bash
# performance-validation.sh - Final performance validation script

set -e

echo "Starting comprehensive performance validation..."

# Define test parameters
SERVICE_NAME="cnf-app-service"
NAMESPACE="default"
TEST_DURATION=60
CONCURRENT_CONNECTIONS=100

# Get service endpoint
SERVICE_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
SERVICE_PORT=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')

echo "Testing service at $SERVICE_IP:$SERVICE_PORT"

# Run performance tests
echo "Running load test with $CONCURRENT_CONNECTIONS concurrent connections for $TEST_DURATION seconds..."

# Use Apache Bench for load testing (assuming it's available in the environment)
if command -v ab &> /dev/null; then
    echo "Using Apache Bench for load testing..."
    # Create a temporary pod to run the load test from inside the cluster
    kubectl run load-test --image=httpd --restart=Never --rm -it --overrides='
    {
      "spec": {
        "containers": [
          {
            "name": "load-test",
            "image": "jordi/ab",
            "args": ["-n", "1000", "-c", "'"$CONCURRENT_CONNECTIONS"'", "http://'"$SERVICE_IP:$SERVICE_PORT"'/status"]
          }
        ]
      }
    }' --image-pull-policy=IfNotPresent
else
    echo "Apache Bench not available, using curl for basic load test..."
    # Basic load test with curl
    for i in $(seq 1 100); do
        curl -s -o /dev/null -w "Status: %{http_code}, Time: %{time_total}s\n" \
          "http://$SERVICE_IP:$SERVICE_PORT/status" &
        
        # Limit concurrent requests
        if [ $((i % $CONCURRENT_CONNECTIONS)) -eq 0 ]; then
            sleep 1
        fi
    done
    wait
fi

echo "Load test completed successfully"

# Resource utilization check
echo "Checking resource utilization..."
kubectl top pods -n $NAMESPACE

# Verify all pods are healthy
echo "Verifying pod health..."
kubectl get pods -n $NAMESPACE -l app=cnf-app -o wide

# Check for any restarts or issues
RESTART_COUNT=$(kubectl get pods -n $NAMESPACE -l app=cnf-app -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | paste -sd+ - | bc)
if [ "$RESTART_COUNT" -gt 0 ]; then
    echo "Warning: Found $RESTART_COUNT total pod restarts during testing"
else
    echo "No pod restarts detected during testing - OK"
fi

# Performance metrics collection
echo "Collecting performance metrics..."
kubectl top nodes

echo "Performance validation completed successfully!"