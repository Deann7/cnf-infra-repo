# CNF Infrastructure Repository

This repository contains infrastructure-as-code definitions for Cloud-Native Network Functions (CNFs) deployed on the O-Cloud platform. It includes Kubernetes manifests, Helm charts, security policies, and quality gates.

## Overview

The CNF Infrastructure repository provides a comprehensive infrastructure setup for deploying and managing CNFs with security, scalability, and reliability in mind. It implements security best practices, quality gates, and monitoring configurations for production-ready deployments.

## Features

- **Kubernetes Manifests**: Production-ready Kubernetes deployment configurations
- **Helm Charts**: Parameterized deployment templates for easy customization
- **Security Policies**: Conftest policies for validating security configurations
- **Quality Gates**: Automated validation of infrastructure configurations
- **CI/CD Integration**: GitHub Actions workflows for automated testing and validation
- **Monitoring Configuration**: Prometheus and Grafana configurations
- **O-Cloud Integration**: Specific configurations for the O-Cloud platform

## Directory Structure

```
cnf-infra-repo/
├── manifests/                 # Kubernetes manifests
│   ├── deployment.yaml       # Main application deployment
│   ├── service.yaml          # Service definition
│   ├── network-policy.yaml   # Network policies
│   └── app-deployment.yaml   # Additional application manifests
├── charts/                   # Helm charts
│   └── ocloud-app/          # O-Cloud specific application chart
│       ├── templates/       # Helm templates
│       ├── Chart.yaml       # Chart metadata
│       ├── values.yaml      # Default values
│       ├── values-dev.yaml  # Development environment values
│       └── values-prod.yaml # Production environment values
├── policy/                   # Conftest security policies
│   └── deployment.rego      # Rego policy for deployment validation
├── scripts/                  # Utility scripts
│   ├── deploy-ocloud-app.sh # Deployment script
│   └── README.md            # Script documentation
├── .github/workflows/        # CI/CD workflows
│   └── ci.yaml              # Infrastructure validation workflow
├── .conftestignore           # Files to ignore during Conftest validation
├── .gitignore               # Git ignore patterns
├── kind-cluster-config.yaml # Kind cluster configuration
├── quality-gates.md         # Documentation for quality gates
├── validate.sh              # Validation script
├── container-security.yaml  # Container security configuration
├── ocloud-config.yaml       # O-Cloud platform configuration
└── README.md                # This file
```

## Security Implementation

### Policy Validation
- Pod security standards compliance
- Network policy enforcement
- Resource limit validation
- Security context requirements

### Quality Gates
- Automated validation of security configurations
- Compliance checking against security standards
- Vulnerability assessment integration

## Usage

### Local Development
1. Clone the repository
2. Review and customize values in `charts/ocloud-app/values.yaml`
3. Use the validation script to check configurations:
   ```bash
   ./validate.sh
   ```

### Deployment
1. Set up your Kubernetes cluster with appropriate security configurations
2. Customize the Helm chart values for your environment
3. Deploy using Helm:
   ```bash
   helm install ocloud-app charts/ocloud-app -f values-prod.yaml
   ```

## Quality Assurance

This repository implements comprehensive quality gates through:
- Static code analysis of Kubernetes manifests
- Security policy validation with Conftest
- Infrastructure scanning with Trivy
- Custom validation scripts

## O-Cloud Platform Integration

The infrastructure is specifically configured for the O-Cloud platform with:
- Region-specific configurations
- Platform-specific security settings
- Resource quota management
- Compliance with O-Cloud policies

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with appropriate tests
4. Submit a pull request with detailed descriptions
5. Ensure all quality gates pass

## License

This project is licensed under the terms specified in the LICENSE file.