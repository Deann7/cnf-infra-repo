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
Verifies that deployments are successful and running as expected.

### deployment-strategies.sh
Implements different deployment strategies (rolling, blue-green, canary).

### helm-rollback-mechanism.sh
Handles rollback procedures for Helm releases.

## Dependencies

- kubectl must be installed and configured
- Appropriate permissions to access Kubernetes resources in the target namespace

## Notes

These scripts are designed to be used in CI/CD pipelines and for manual verification of deployments. Make sure to configure appropriate RBAC permissions for the service accounts running these scripts in your Kubernetes cluster.