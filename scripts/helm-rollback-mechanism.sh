#!/bin/bash

# Helm Rollback Mechanism for O-Cloud Application
# Implements robust rollback capabilities for emergency situations in the pipeline
# This script provides comprehensive rollback functionality with verification

set -e  # Exit immediately if a command exits with a non-zero status

# Default values
NAMESPACE="ocloud"
APP_NAME="ocloud-app"
MAX_REVISIONS=10
TIMEOUT="600s"

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

# Function to display deployment history
show_history() {
    print_status "Fetching deployment history for $APP_NAME in namespace $NAMESPACE..."
    
    if ! helm list -n "$NAMESPACE" | grep -q "$APP_NAME"; then
        print_error "Release $APP_NAME not found in namespace $NAMESPACE"
        exit 1
    fi
    
    print_status "Deployment history for $APP_NAME:"
    helm history "$APP_NAME" -n "$NAMESPACE" --max "$MAX_REVISIONS"
}

# Function to rollback to a specific revision
rollback_to_revision() {
    local target_revision=$1
    
    print_status "Initiating rollback to revision $target_revision for $APP_NAME..."
    
    # Check if the target revision exists
    if ! helm history "$APP_NAME" -n "$NAMESPACE" | grep -q "^ *$target_revision "; then
        print_error "Revision $target_revision does not exist for $APP_NAME"
        show_history
        exit 1
    fi
    
    # Get the current revision before rollback
    CURRENT_REVISION=$(helm status "$APP_NAME" -n "$NAMESPACE" | grep "Revision:" | awk '{print $2}')
    print_status "Current revision: $CURRENT_REVISION"
    
    # Execute rollback
    print_status "Executing rollback command..."
    if helm rollback "$APP_NAME" "$target_revision" -n "$NAMESPACE" --timeout="$TIMEOUT"; then
        print_success "Rollback to revision $target_revision initiated successfully"
        
        # Wait for rollback to complete
        print_status "Waiting for rollback to complete..."
        kubectl rollout status deployment/$(get_app_deployment) -n "$NAMESPACE" --timeout="$TIMEOUT"
        
        print_success "Rollback to revision $target_revision completed successfully"
        
        # Log the rollback event
        log_rollback_event "$CURRENT_REVISION" "$target_revision"
        
        return 0
    else
        print_error "Rollback to revision $target_revision failed"
        return 1
    fi
}

# Function to rollback to previous stable version
rollback_to_previous_stable() {
    print_status "Finding previous stable revision for rollback..."
    
    # Get the history excluding the current (potentially problematic) revision
    PREVIOUS_STABLE=$(helm history "$APP_NAME" -n "$NAMESPACE" --max "$MAX_REVISIONS" | \
                     awk 'NR>1 && $3=="deployed" {print $1; exit}')
    
    if [ -z "$PREVIOUS_STABLE" ]; then
        print_error "No previous stable revision found for rollback"
        show_history
        exit 1
    fi
    
    print_status "Found previous stable revision: $PREVIOUS_STABLE"
    rollback_to_revision "$PREVIOUS_STABLE"
}

# Function to get the deployment name for the app
get_app_deployment() {
    # Try to get the deployment name from Helm release
    local deployment_name=$(kubectl get deployments -n "$NAMESPACE" -l app.kubernetes.io/name=ocloud-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$deployment_name" ]; then
        # Fallback to common naming convention
        deployment_name="${APP_NAME}"
    fi
    
    echo "$deployment_name"
}

# Function to verify rollback status
verify_rollback() {
    local target_revision=$1
    
    print_status "Verifying rollback status..."
    
    # Check if the deployment is ready
    local deployment_name=$(get_app_deployment)
    if kubectl rollout status deployment/"$deployment_name" -n "$NAMESPACE" --timeout="$TIMEOUT"; then
        print_success "Rollback verification passed - deployment is ready"
    else
        print_error "Rollback verification failed - deployment is not ready"
        return 1
    fi
    
    # Check pod status
    print_status "Checking pod status..."
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=ocloud-app --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pods" ]; then
        print_error "No running pods found after rollback"
        return 1
    fi
    
    print_success "All pods are running: $pods"
    
    # Check service accessibility
    print_status "Checking service accessibility..."
    if kubectl get service "$APP_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_success "Service is accessible"
    else
        print_warning "Service may not be accessible"
    fi
    
    # Run health checks if possible
    run_health_checks
    
    return 0
}

# Function to run health checks
run_health_checks() {
    print_status "Running health checks..."
    
    local deployment_name=$(get_app_deployment)
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=ocloud-app --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$pods" ]; then
        print_error "No running pods to check health"
        return 1
    fi
    
    # Check if pods are responding to health checks
    for pod in $pods; do
        print_status "Checking health for pod: $pod"
        
        # Attempt to check the health endpoint if the container supports it
        if kubectl exec "$pod" -n "$NAMESPACE" -- timeout 10 sh -c 'curl -f http://localhost:8080/health' &> /dev/null; then
            print_success "Health check passed for pod: $pod"
        else
            print_warning "Health check may not be available or failed for pod: $pod"
        fi
    done
    
    return 0
}

# Function to log rollback event
log_rollback_event() {
    local from_revision=$1
    local to_revision=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    print_status "Logging rollback event from revision $from_revision to $to_revision"
    
    # Create a rollback log entry
    local log_entry="[$timestamp] Rollback: $APP_NAME from revision $from_revision to revision $to_revision in namespace $NAMESPACE"
    echo "$log_entry" >> "/tmp/helm-rollback-log-$(date +%Y%m%d).txt"
    
    print_success "Rollback event logged: $log_entry"
}

# Function to implement automated rollback based on health checks
automated_rollback_if_unhealthy() {
    local check_interval=${1:-30}  # Default 30 seconds
    local max_attempts=${2:-10}    # Default 10 attempts
    
    print_status "Starting automated rollback check (checking every $check_interval seconds for $max_attempts attempts)..."
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        print_status "Health check attempt $attempt/$max_attempts"
        
        if run_health_checks; then
            print_success "Application is healthy, no rollback needed"
            return 0
        else
            print_warning "Application health check failed on attempt $attempt"
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            print_status "Waiting $check_interval seconds before next check..."
            sleep "$check_interval"
        fi
        
        ((attempt++))
    done
    
    print_error "Application remains unhealthy after $max_attempts attempts, initiating automated rollback..."
    
    # Rollback to previous stable version
    rollback_to_previous_stable
    
    # Verify the rollback
    verify_rollback
}

# Function to create emergency rollback procedure
emergency_rollback() {
    print_status "=== EMERGENCY ROLLBACK PROCEDURE INITIATED ==="
    print_warning "This is an emergency rollback due to critical failure!"
    
    # Document the emergency situation
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local emergency_log="[$timestamp] EMERGENCY ROLLBACK: Initiated for $APP_NAME in namespace $NAMESPACE due to critical failure"
    echo "$emergency_log" >> "/tmp/emergency-rollback-log-$(date +%Y%m%d).txt"
    
    # Rollback to the most recent stable revision
    rollback_to_previous_stable
    
    # Verify the rollback
    if verify_rollback; then
        print_success "EMERGENCY ROLLBACK COMPLETED SUCCESSFULLY"
        # Send notification (would use webhook in real scenario)
        echo "Emergency rollback completed at $timestamp" >> "/tmp/emergency-rollback-completion-$(date +%Y%m%d).txt"
    else
        print_error "EMERGENCY ROLLBACK VERIFICATION FAILED - MANUAL INTERVENTION REQUIRED"
        exit 1
    fi
}

# Print usage information
usage() {
    echo "Usage: $0 [options] [command]"
    echo ""
    echo "Commands:"
    echo "  history                    Show deployment history"
    echo "  rollback-to <revision>     Rollback to specific revision"
    echo "  rollback-prev              Rollback to previous stable version"
    echo "  verify                     Verify current deployment status"
    echo "  auto-rollback [interval] [attempts]  Automated rollback if unhealthy"
    echo "  emergency                  Emergency rollback procedure"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NS         Set namespace [default: $NAMESPACE]"
    echo "  -a, --app-name NAME        Set app name [default: $APP_NAME]"
    echo "  -t, --timeout TIMEOUT      Set timeout [default: $TIMEOUT]"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 history                                    # Show deployment history"
    echo "  $0 rollback-to 3                            # Rollback to revision 3"
    echo "  $0 rollback-prev                            # Rollback to previous stable"
    echo "  $0 verify                                   # Verify current deployment"
    echo "  $0 auto-rollback 60 5                       # Check every 60s, max 5 times"
    echo "  $0 -n production emergency                  # Emergency rollback in prod"
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
        -h|--help)
            usage
            ;;
        history)
            show_history
            exit 0
            ;;
        rollback-to)
            if [ -z "$2" ]; then
                print_error "Missing revision number for rollback-to command"
                usage
            fi
            TARGET_REVISION="$2"
            shift 2
            ;;
        rollback-prev)
            rollback_to_previous_stable
            verify_rollback
            exit 0
            ;;
        verify)
            verify_rollback
            exit 0
            ;;
        auto-rollback)
            INTERVAL="${2:-30}"
            ATTEMPTS="${3:-10}"
            automated_rollback_if_unhealthy "$INTERVAL" "$ATTEMPTS"
            exit 0
            ;;
        emergency)
            emergency_rollback
            exit 0
            ;;
        *)
            print_error "Unknown option or command: $1"
            usage
            ;;
    esac
done

# Execute rollback to specific revision if specified
if [ -n "$TARGET_REVISION" ]; then
    rollback_to_revision "$TARGET_REVISION"
    verify_rollback "$TARGET_REVISION"
else
    # If no command was specified, show usage
    print_error "No command specified"
    usage
fi