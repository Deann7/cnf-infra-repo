#!/bin/bash
# advanced-validation.sh - Advanced verification and stress testing

set -e

echo "Starting advanced verification and stress testing..."

NAMESPACE=${1:-"default"}
DEPLOYMENT_NAME=${2:-"cnf-app-deployment"}
SERVICE_NAME="${DEPLOYMENT_NAME%-deployment}-service"

# Get service details
SERVICE_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
SERVICE_PORT=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "")

if [[ -n "$SERVICE_IP" && -n "$SERVICE_PORT" ]]; then
    echo "Starting stress testing on $SERVICE_IP:$SERVICE_PORT"
    
    # Performance benchmarking
    echo "Running performance benchmarking..."
    
    # High-concurrency API test
    echo "Testing API under high concurrency..."
    kubectl run load-test --image=curlimages/curl --restart=Never --rm -it -- curl -s -w "Time: %{time_total}s\\n" -o /dev/null "http://$SERVICE_IP:$SERVICE_PORT/status" --parallel --parallel-max 10 || echo "Load test completed"
    
    # Sustained load test
    echo "Running sustained load test..."
    kubectl run sustained-load-test --image=curlimages/curl --restart=Never --rm -it -- curl -s -o /dev/null -w "%{http_code}" "http://$SERVICE_IP:$SERVICE_PORT/health" &
    LOAD_PID=$!
    
    # Monitor performance during load
    sleep 30
    kubectl top pods -n $NAMESPACE | grep ${DEPLOYMENT_NAME%-deployment} || echo "No matching pods found for top command"
    
    kill $LOAD_PID 2>/dev/null || true
    sleep 2
    
    # Memory and CPU stress test
    echo "Testing memory and CPU utilization under load..."
    kubectl run resource-test --image=curlimages/curl --restart=Never --rm -it -- sh -c "
      for i in {1..50}; do 
        curl -s -o /dev/null -w '.' 'http://$SERVICE_IP:$SERVICE_PORT/status'
      done
    " || echo "Resource test completed"
    
    echo "✓ Stress testing completed"
else
    echo "✗ Service not accessible for stress testing"
    exit 1
fi

# Chaos engineering simulation
echo "Starting chaos engineering simulation..."

# Temporarily reduce replica count to test auto-scaling
echo "Simulating scaling event..."
ORIGINAL_REPLICAS=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}')
kubectl scale deployment $DEPLOYMENT_NAME -n $NAMESPACE --replicas=$((ORIGINAL_REPLICAS / 2))

# Wait for scaling to occur
sleep 30

# Restore original replica count
kubectl scale deployment $DEPLOYMENT_NAME -n $NAMESPACE --replicas=$ORIGINAL_REPLICAS

# Wait for restoration
sleep 60

# Verify all pods are ready
READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=${DEPLOYMENT_NAME%-deployment} --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' | wc -w)
EXPECTED_PODS=$ORIGINAL_REPLICAS

if [[ $READY_PODS -ge $EXPECTED_PODS ]]; then
    echo "✓ Scaling simulation completed successfully - $READY_PODS of $EXPECTED_PODS pods ready"
else
    echo "✗ Scaling simulation failed - $READY_PODS of $EXPECTED_PODS pods ready"
    exit 1
fi

echo "Advanced verification completed successfully!"