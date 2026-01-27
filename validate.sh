#!/bin/bash

# Validation script for CNF Infrastructure
# This script performs various validation checks on the infrastructure configurations

set -e  # Exit immediately if a command exits with a non-zero status

echo "Starting infrastructure validation..."

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

# Check if required tools are installed
print_status "Checking required tools..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    print_error "helm is not installed"
    exit 1
fi

if ! command -v yq &> /dev/null; then
    print_error "yq is not installed (install with 'pip install yq' or equivalent)"
    exit 1
fi

print_success "All required tools are installed"

# Validate Kubernetes manifests
print_status "Validating Kubernetes manifests..."
for file in manifests/*.yaml; do
    if [[ -f "$file" ]]; then
        print_status "Validating $file..."
        if ! yq eval 'true' "$file" &>/dev/null; then
            print_error "Invalid YAML in $file"
            exit 1
        fi
        
        # Check if resources have resource limits
        if yq eval '.spec.template.spec.containers[] | select(.resources.limits.cpu == null or .resources.limits.memory == null)' "$file" &>/dev/null; then
            print_error "Missing resource limits in $file"
            exit 1
        fi
        
        # Check if security context is defined
        if yq eval '.spec.template.spec.containers[] | select(.securityContext == null)' "$file" &>/dev/null; then
            print_error "Missing security context in $file"
            exit 1
        fi
        
        print_success "Validated $file"
    fi
done

# Validate Helm charts
print_status "Validating Helm charts..."
for chart in charts/*; do
    if [[ -d "$chart" ]]; then
        print_status "Validating chart: $chart"
        if ! helm lint "$chart"; then
            print_error "Helm lint failed for $chart"
            exit 1
        fi
        print_success "Helm lint passed for $chart"
    fi
done

# Check for privileged containers
print_status "Checking for privileged containers..."
PRIVILEGED_FOUND=false
for file in manifests/*.yaml; do
    if [[ -f "$file" ]]; then
        if yq eval '.spec.template.spec.containers[] | select(.securityContext.privileged == true)' "$file" &>/dev/null; then
            print_error "Privileged container found in $file"
            PRIVILEGED_FOUND=true
        fi
    fi
done

if [[ "$PRIVILEGED_FOUND" == "true" ]]; then
    print_error "Validation failed due to privileged containers"
    exit 1
else
    print_success "No privileged containers found"
fi

# Check for runAsRoot containers
print_status "Checking for root containers..."
ROOT_FOUND=false
for file in manifests/*.yaml; do
    if [[ -f "$file" ]]; then
        # Check container level runAsNonRoot
        if yq eval '.spec.template.spec.containers[] | select(.securityContext.runAsNonRoot == false)' "$file" &>/dev/null; then
            print_error "Root container found in $file"
            ROOT_FOUND=true
        fi
        # Check pod level runAsNonRoot
        if yq eval '.spec.template.spec.securityContext.runAsNonRoot == false' "$file" &>/dev/null; then
            print_error "Root container found in $file (pod level)"
            ROOT_FOUND=true
        fi
    fi
done

if [[ "$ROOT_FOUND" == "true" ]]; then
    print_error "Validation failed due to root containers"
    exit 1
else
    print_success "No root containers found"
fi

# Run conftest validation if available
if command -v conftest &> /dev/null; then
    print_status "Running Conftest validation..."
    if [[ -d "policy" ]]; then
        for file in manifests/*.yaml; do
            if [[ -f "$file" ]]; then
                if ! conftest test -p policy "$file"; then
                    print_error "Conftest validation failed for $file"
                    exit 1
                fi
            fi
        done
        print_success "Conftest validation passed"
    else
        print_status "Policy directory not found, skipping Conftest validation"
    fi
else
    print_status "Conftest not installed, skipping Conftest validation"
fi

# Check for network policies
print_status "Checking for network policies..."
NETWORK_POLICIES=0
for file in manifests/*.yaml; do
    if [[ -f "$file" ]]; then
        if yq eval '.kind == "NetworkPolicy"' "$file" &>/dev/null; then
            NETWORK_POLICIES=$((NETWORK_POLICIES + 1))
        fi
    fi
done

if [[ $NETWORK_POLICIES -eq 0 ]]; then
    print_error "No NetworkPolicies found in manifests"
    exit 1
else
    print_success "Found $NETWORK_POLICIES NetworkPolicy file(s)"
fi

print_success "All validations passed!"
echo "Infrastructure is compliant with security and quality standards."