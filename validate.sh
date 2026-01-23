#!/bin/bash

# Quality gate validation script for cnf-infra-repo
set -e

echo "Starting infrastructure quality gates validation..."

# Validate Kubernetes manifests with conftest
echo "Validating Kubernetes manifests..."
for manifest in $(find . -name "*.yaml" -o -name "*.yml"); do
  echo "Checking $manifest..."
  if ! conftest test -p policy "$manifest"; then
    echo "Validation failed for $manifest"
    exit 1
  fi
done

# Validate Helm charts
echo "Validating Helm charts..."
helm lint charts/*

# Check for common security misconfigurations
echo "Checking for privileged containers..."
if grep -r "privileged: true" . --include="*.yaml" --include="*.yml"; then
  echo "ERROR: Found privileged containers which violate security policy"
  exit 1
else
  echo "No privileged containers found - OK"
fi

# Check for resource limits
echo "Checking for resource limits in deployments..."
if ! grep -r "resources:" . --include="*.yaml" --include="*.yml" | grep -q "limits"; then
  echo "WARNING: No resource limits found in deployments"
  exit 1
else
  echo "Resource limits found - OK"
fi

echo "All infrastructure quality gates passed!"