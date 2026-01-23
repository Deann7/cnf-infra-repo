# Quality Gates for Infrastructure as Code

This document outlines the quality gates implemented for the cnf-infra-repo to ensure high-quality, secure, and compliant Kubernetes infrastructure.

## Quality Gate Components

### 1. Policy Validation with Conftest
We use Conftest with Rego policies to validate Kubernetes manifests against security and best practice policies.

#### Policies Implemented
- Deployments must have securityContext defined at pod level
- Deployments must have securityContext defined at container level
- Deployments must have resource limits defined
- Containers must have resource limits defined by name

### 2. Helm Chart Validation
Helm lint is used to validate Helm charts for common issues and best practices.

### 3. Security Checks
- Verification that no privileged containers are deployed
- Verification that resource limits are defined for all deployments

## Implementation

### Running Quality Gates Locally
```bash
./validate.sh
```

### GitHub Actions Integration
Quality gates are integrated into the CI/CD pipeline to prevent deployment of non-compliant infrastructure.

## Quality Gate Criteria

- All Kubernetes manifests must pass Conftest policy validation
- All Helm charts must pass helm lint validation
- No privileged containers allowed
- All deployments must have resource limits defined