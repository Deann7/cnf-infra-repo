# Scripts Directory

This directory contains various utility scripts for managing and operating the O-Cloud infrastructure.

## Available Scripts

### deployment-health-check.sh
A bash script to verify CNF deployment health and readiness. This script checks that pods are running and ready, and validates health endpoints.

**Usage:**
```bash
./deployment-health-check.sh [namespace] [deployment-name] [timeout]
```

**Parameters:**
- `namespace`: Kubernetes namespace (default: default)
- `deployment-name`: Name of the deployment to check (default: cnf-app-deployment)
- `timeout`: Timeout in seconds (default: 300)

### deployment-health-check.ps1
A PowerShell equivalent of the bash script for Windows environments.

**Usage:**
```powershell
.\deployment-health-check.ps1 -Namespace "default" -DeploymentName "cnf-app-deployment" -Timeout 300
```

### deployment-verification.sh
Comprehensive verification script that implements end-to-end validation for Kubernetes deployments. This script performs multiple types of checks including pod status, health validation, service accessibility, API endpoint verification, and application functionality validation.

**Usage:**
```bash
./deployment-verification.sh [options] [command]
```

**Commands:**
- `pod-status`: Verify pod status only
- `health-validation`: Verify health validation only
- `service-accessibility`: Verify service accessibility only
- `api-endpoints`: Verify comprehensive API endpoints only
- `app-functionality`: Verify application functionality only
- `comprehensive`: Run all verification checks (default)
- `helm-integration`: Run Helm verification integration

**Options:**
- `-n, --namespace`: Set namespace (default: ocloud)
- `-a, --app-name`: Set app name (default: ocloud-app)
- `-t, --timeout`: Set timeout (default: 300s)
- `-p, --health-port`: Set health port (default: 8080)
- `-h, --help`: Show help message

**Example:**
```bash
# Run all verification checks
./deployment-verification.sh comprehensive

# Check only API endpoints in production namespace
./deployment-verification.sh -n production api-endpoints

# Verify deployment with custom app name
./deployment-verification.sh -a my-app service-accessibility
```

### deployment-strategies.sh
Implements different deployment strategies (rolling, blue-green, canary).

### helm-rollback-mechanism.sh
Handles rollback procedures for Helm releases.

## Dependencies

- kubectl must be installed and configured
- Appropriate permissions to access Kubernetes resources in the target namespace

## Notes

These scripts are designed to be used in CI/CD pipelines and for manual verification of deployments. Make sure to configure appropriate RBAC permissions for the service accounts running these scripts in your Kubernetes cluster.