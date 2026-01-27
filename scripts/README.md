# Scripts Directory

This directory contains utility scripts for managing and deploying the CNF infrastructure on the O-Cloud platform.

## Available Scripts

### deploy-ocloud-app.sh

This script deploys the O-Cloud application using Helm charts with environment-specific configurations.

#### Usage
```bash
./deploy-ocloud-app.sh [environment]
```

Where `[environment]` can be `dev`, `staging`, or `prod`. If not specified, defaults to `dev`.

#### Features
- Validates configuration files before deployment
- Applies appropriate Helm values based on environment
- Monitors deployment status
- Provides rollback capability in case of failure

#### Prerequisites
- Helm 3.x
- kubectl configured with appropriate cluster access
- Environment-specific values files in the charts directory

### validate.sh

This script validates the infrastructure configurations against security and quality standards.

#### Usage
```bash
./validate.sh
```

#### Features
- Validates Kubernetes manifest files
- Checks for security misconfigurations
- Ensures resource limits are set
- Verifies security contexts
- Runs Conftest policy validation
- Reports compliance status

#### Prerequisites
- yq for YAML processing
- conftest for policy validation
- kubectl for Kubernetes access
- helm for chart validation

## Security Considerations

All scripts follow security best practices:
- Input validation where applicable
- Secure temporary file handling
- Proper error handling
- Minimal permissions required

## Maintenance

Scripts should be reviewed regularly for:
- Security vulnerabilities
- Compatibility with new versions of dependencies
- Performance improvements
- Feature enhancements based on operational needs