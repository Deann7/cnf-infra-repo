#!/bin/bash

# Deployment Verification Script for O-Cloud Applications
# Implements comprehensive verification methods for Kubernetes deployments
# This script verifies pod status, health validation, service accessibility, and application functionality

set -e  # Exit immediately if a command exits with a non-zero status

# Default values
NAMESPACE="ocloud"
APP_NAME="ocloud-app"
TIMEOUT="300s"
HEALTH_PORT="8080"
HEALTH_PATH="/health"
READY_PATH="/ready"

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

# Function to verify pod status
verify_pod_status() {
    print_status "Verifying pod status for $APP_NAME in namespace $NAMESPACE..."
    
    # Get all pods for the application
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME" -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pods" ]; then
        print_error "No pods found for application $APP_NAME in namespace $NAMESPACE"
        return 1
    fi
    
    print_status "Found pods: $pods"
    
    # Check each pod's status
    local all_ready=true
    for pod in $pods; do
        local status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        local ready_condition=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        
        print_status "Pod: $pod, Status: $status, Ready: $ready_condition"
        
        if [ "$status" != "Running" ] || [ "$ready_condition" != "True" ]; then
            print_error "Pod $pod is not ready"
            all_ready=false
        else
            print_success "Pod $pod is running and ready"
        fi
        
        # Check restart count
        local restart_count=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}')
        if [ "$restart_count" -gt 5 ]; then
            print_warning "Pod $pod has restarted $restart_count times"
        fi
    done
    
    if [ "$all_ready" = true ]; then
        print_success "All pods are running and ready"
        return 0
    else
        print_error "Some pods are not ready"
        return 1
    fi
}

# Function to verify health validation
verify_health_validation() {
    print_status "Verifying health validation for $APP_NAME..."
    
    # Get all pods for the application
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME" -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pods" ]; then
        print_error "No pods found for health validation"
        return 1
    fi
    
    local all_healthy=true
    for pod in $pods; do
        print_status "Checking health for pod: $pod"
        
        # Try to check the health endpoint inside the pod
        if kubectl exec "$pod" -n "$NAMESPACE" -- timeout 10 sh -c "curl -f http://localhost:$HEALTH_PORT$HEALTH_PATH" &> /dev/null; then
            print_success "Health check passed for pod: $pod"
        elif kubectl exec "$pod" -n "$NAMESPACE" -- timeout 10 sh -c "wget -q -O - http://localhost:$HEALTH_PORT$HEALTH_PATH" &> /dev/null; then
            print_success "Health check passed for pod: $pod (using wget)"
        else
            print_error "Health check failed for pod: $pod"
            all_healthy=false
        fi
    done
    
    if [ "$all_healthy" = true ]; then
        print_success "All pods passed health validation"
        return 0
    else
        print_error "Some pods failed health validation"
        return 1
    fi
}

# Function to verify service accessibility
verify_service_accessibility() {
    print_status "Verifying service accessibility for $APP_NAME..."
    
    # Check if service exists
    if ! kubectl get service "$APP_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_error "Service $APP_NAME not found in namespace $NAMESPACE"
        return 1
    fi
    
    # Get service information
    local service_info=$(kubectl get service "$APP_NAME" -n "$NAMESPACE" -o wide)
    print_status "Service information:\n$service_info"
    
    # Check service type
    local service_type=$(kubectl get service "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.type}')
    print_status "Service type: $service_type"
    
    # Check if service has endpoints
    local endpoints=$(kubectl get endpoints "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}')
    if [ -z "$endpoints" ]; then
        print_error "Service $APP_NAME has no active endpoints"
        return 1
    else
        print_success "Service $APP_NAME has active endpoints: $endpoints"
    fi
    
    # Check service ports
    local service_ports=$(kubectl get service "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[*].port}')
    print_status "Service ports: $service_ports"
    
    # If it's a LoadBalancer service, check the external IP
    if [ "$service_type" = "LoadBalancer" ]; then
        local external_ip=$(kubectl get service "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [ -n "$external_ip" ]; then
            print_success "External IP: $external_ip"
        else
            print_warning "External IP not yet allocated for LoadBalancer service"
        fi
    fi
    
    print_success "Service accessibility verification completed"
    return 0
}

# Function to verify comprehensive API endpoints
verify_api_endpoints() {
    print_status "Verifying comprehensive API endpoints for $APP_NAME..."
    
    # Get a pod name for testing
    local test_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$test_pod" ]; then
        print_error "No pods found for API endpoint testing"
        return 1
    fi
    
    print_status "Testing API endpoints on pod: $test_pod"
    
    # Test all major endpoints
    local endpoints=("/health" "/ready" "/status" "/info" "/security" "/config")
    local all_endpoints_ok=true
    
    for endpoint in "${endpoints[@]}"; do
        print_status "Testing endpoint: $endpoint"
        if kubectl exec "$test_pod" -n "$NAMESPACE" -- timeout 10 sh -c "curl -sf http://localhost:$HEALTH_PORT$endpoint" &> /dev/null; then
            print_success "Endpoint $endpoint responded successfully"
        else
            print_error "Endpoint $endpoint failed to respond"
            all_endpoints_ok=false
        fi
    done
    
    # Specific validation for status endpoint response
    print_status "Validating status endpoint response format..."
    local status_response=$(kubectl exec "$test_pod" -n "$NAMESPACE" -- timeout 10 sh -c "curl -s http://localhost:$HEALTH_PORT/status" 2>/dev/null)
    if echo "$status_response" | grep -q '"validation_passed"'; then
        print_success "Status endpoint contains validation_passed field"
    else
        print_warning "Status endpoint may not contain expected validation fields"
    fi
    
    if [ "$all_endpoints_ok" = true ]; then
        print_success "All API endpoints verification passed"
        return 0
    else
        print_error "Some API endpoints failed verification"
        return 1
    fi
}

# Function to verify application functionality
verify_application_functionality() {
    print_status "Verifying application functionality for $APP_NAME..."
    
    # Get service information
    local service_exists=$(kubectl get service "$APP_NAME" -n "$NAMESPACE" &> /dev/null && echo "exists" || echo "missing")
    if [ "$service_exists" = "missing" ]; then
        print_error "Service $APP_NAME does not exist"
        return 1
    fi
    
    # Try to access the service from within the cluster
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME" -o jsonpath='{.items[*].metadata.name}')
    if [ -n "$pods" ]; then
        local test_pod=$(echo "$pods" | awk '{print $1}')  # Take first pod for testing
        
        # Test basic connectivity
        if kubectl exec "$test_pod" -n "$NAMESPACE" -- timeout 10 sh -c "curl -f http://$APP_NAME.$NAMESPACE.svc.cluster.local/ || wget -q -O - http://$APP_NAME.$NAMESPACE.svc.cluster.local/" &> /dev/null; then
            print_success "Internal service connectivity test passed"
        else
            print_warning "Internal service connectivity test may have failed"
        fi
    fi
    
    # Check service from outside the pod if possible
    local service_port=$(kubectl get service "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
    local service_cluster_ip=$(kubectl get service "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
    
    if [ -n "$service_cluster_ip" ] && [ -n "$service_port" ]; then
        # Use kubectl port-forward to test if needed
        print_status "Service accessible at: $service_cluster_ip:$service_port"
    fi
    
    # Check application-specific endpoints if they exist
    local app_ready_check=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$app_ready_check" ]; then
        if kubectl exec "$app_ready_check" -n "$NAMESPACE" -- timeout 10 sh -c "curl -f http://localhost:$HEALTH_PORT$READY_PATH" &> /dev/null; then
            print_success "Application readiness check passed"
        else
            print_status "Application readiness endpoint not available or not ready"
        fi
        
        # Check status endpoint for comprehensive validation
        if kubectl exec "$app_ready_check" -n "$NAMESPACE" -- timeout 10 sh -c "curl -f http://localhost:$HEALTH_PORT/status" &> /dev/null; then
            print_success "Application status endpoint check passed"
        else
            print_status "Application status endpoint not available"
        fi
        
        # Check info endpoint for service information
        if kubectl exec "$app_ready_check" -n "$NAMESPACE" -- timeout 10 sh -c "curl -f http://localhost:$HEALTH_PORT/info" &> /dev/null; then
            print_success "Application info endpoint check passed"
        else
            print_status "Application info endpoint not available"
        fi
    fi
    
    # Check if the deployment is scaled properly
    local desired_replicas=$(kubectl get deployment "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
    local current_replicas=$(kubectl get deployment "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.status.replicas}')
    local ready_replicas=$(kubectl get deployment "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
    
    print_status "Desired: $desired_replicas, Current: $current_replicas, Ready: $ready_replicas"
    
    if [ "$desired_replicas" = "$ready_replicas" ] && [ "$desired_replicas" = "$current_replicas" ]; then
        print_success "Deployment has correct replica count ($desired_replicas/$desired_replicas ready)"
    else
        print_error "Deployment replica mismatch - Desired: $desired_replicas, Ready: $ready_replicas"
        return 1
    fi
    
    print_success "Application functionality verification completed"
    return 0
}

# Function to run comprehensive verification
run_comprehensive_verification() {
    print_status "Starting comprehensive deployment verification..."
    
    local total_tests=0
    local passed_tests=0
    
    # Run pod status verification
    ((total_tests++))
    if verify_pod_status; then
        ((passed_tests++))
    fi
    
    # Run health validation
    ((total_tests++))
    if verify_health_validation; then
        ((passed_tests++))
    fi
    
    # Run service accessibility verification
    ((total_tests++))
    if verify_service_accessibility; then
        ((passed_tests++))
    fi
    
    # Run API endpoints verification
    ((total_tests++))
    if verify_api_endpoints; then
        ((passed_tests++))
    fi
    
    # Run application functionality verification
    ((total_tests++))
    if verify_application_functionality; then
        ((passed_tests++))
    fi
    
    print_status "Verification Summary: $passed_tests/$total_tests tests passed"
    
    if [ $passed_tests -eq $total_tests ]; then
        print_success "All verification tests passed! Deployment is healthy."
        return 0
    else
        local failed_count=$((total_tests - passed_tests))
        print_error "$failed_count verification test(s) failed!"
        return 1
    fi
}

# Function to integrate with Helm verification
helm_verification_integration() {
    print_status "Running Helm verification for $APP_NAME..."
    
    # Use Helm to verify the release
    if helm status "$APP_NAME" -n "$NAMESPACE" | grep -q "Status: deployed"; then
        print_success "Helm release status: deployed"
    else
        print_error "Helm release is not in deployed status"
        return 1
    fi
    
    # Check Helm test hook if available
    if helm test "$APP_NAME" -n "$NAMESPACE" --timeout="$TIMEOUT"; then
        print_success "Helm tests passed"
    else
        print_warning "Helm tests may have failed or not exist"
    fi
}

# Print usage information
usage() {
    echo "Usage: $0 [options] [command]"
    echo ""
    echo "Commands:"
    echo "  pod-status              Verify pod status only"
    echo "  health-validation       Verify health validation only"
    echo "  service-accessibility   Verify service accessibility only"
    echo "  api-endpoints           Verify comprehensive API endpoints only"
    echo "  app-functionality       Verify application functionality only"
    echo "  comprehensive           Run all verification checks (default)"
    echo "  helm-integration        Run Helm verification integration"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NS      Set namespace [default: $NAMESPACE]"
    echo "  -a, --app-name NAME     Set app name [default: $APP_NAME]"
    echo "  -t, --timeout TIMEOUT   Set timeout [default: $TIMEOUT]"
    echo "  -p, --health-port PORT  Set health port [default: $HEALTH_PORT]"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 comprehensive                         # Run all verification checks"
    echo "  $0 pod-status                           # Check only pod status"
    echo "  $0 -n production comprehensive          # Verify in production namespace"
    echo "  $0 -a my-app service-accessibility      # Check service for my-app"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -a|--app-name)
            APP_NAME="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -p|--health-port)
            HEALTH_PORT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        pod-status)
            verify_pod_status
            exit $?
            ;;
        health-validation)
            verify_health_validation
            exit $?
            ;;
        service-accessibility)
            verify_service_accessibility
            exit $?
            ;;
        api-endpoints)
            verify_api_endpoints
            exit $?
            ;;
        app-functionality)
            verify_application_functionality
            exit $?
            ;;
        comprehensive)
            run_comprehensive_verification
            exit $?
            ;;
        helm-integration)
            helm_verification_integration
            exit $?
            ;;
        *)
            print_error "Unknown option or command: $1"
            usage
            ;;
    esac
done

# If no command specified, run comprehensive verification by default
run_comprehensive_verification
exit $?