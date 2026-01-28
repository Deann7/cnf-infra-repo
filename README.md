# CNF Infrastructure Repository

This repository contains the infrastructure-as-code for deploying Cloud Native Network Functions (CNFs) to Kubernetes clusters. It includes deployment manifests, Helm charts, and CI/CD pipeline configurations.

## Project Structure

```
cnf-infra-repo/
├── .github/
│   └── workflows/
│       ├── ci.yaml         # Continuous Integration pipeline
│       └── cd.yaml         # Continuous Deployment pipeline
├── charts/
│   ├── Chart.yaml        # Helm chart definition
│   ├── values.yaml       # Default values for the Helm chart
│   └── templates/        # Kubernetes manifest templates
│       ├── _helpers.tpl
│       ├── deployment.yaml
│       └── service.yaml
├── scripts/
│   ├── deploy-ocloud-app.sh      # Deployment script
│   └── deployment-strategies.sh  # Deployment strategy examples
└── README.md
```

## CD Pipeline Implementation

The continuous deployment pipeline automates the deployment of applications to Kubernetes clusters. Key components include:

### 1. Image Pulling from Registry
- The pipeline pulls the latest container image from GitHub Container Registry (GHCR)
- Authentication is handled securely using GitHub Actions secrets
- Images are tagged with commit SHA for traceability

### 2. Helm Install/Upgrade Strategy
- Uses Helm for package management and deployment
- Implements upgrade strategy to update existing releases
- Creates namespace if it doesn't exist
- Includes timeout and wait conditions for reliable deployments

### 3. Verification Mechanisms
- Pod readiness and liveness probes
- Health check endpoints
- Rollout status verification
- Service connectivity tests

### 4. Deployment Strategies
The repository includes examples of different deployment strategies:

- **Rolling Updates**: Gradually replaces old pods with new ones (zero downtime)
- **Blue-Green Deployments**: Maintains two identical production environments
- **Canary Deployments**: Gradually shifts traffic to new versions

## Kubernetes Deployment Strategies

### Rolling Updates
Default Kubernetes deployment strategy that gradually replaces instances with new ones, ensuring zero downtime.

### Blue-Green Deployment
Maintains two identical production environments (blue and green). Traffic is switched from one environment to another during deployment.

### Canary Deployment
Deploys new version to a subset of users first, then gradually expands to all users after validation.

## Security Considerations
- Secrets are managed securely using Kubernetes secrets
- RBAC is configured for minimal required permissions
- Images are scanned for vulnerabilities before deployment
- Network policies restrict unnecessary traffic

## Getting Started

### Prerequisites
- Kubernetes cluster access
- Helm 3.x installed
- kubectl configured

### Deployment Commands
```bash
# Deploy using Helm
helm install ocloud-app ./charts \
  --set image.repository=ghcr.io/username/cnf-app \
  --set image.tag=v1.0.0 \
  --namespace ocloud \
  --create-namespace

# Upgrade existing deployment
helm upgrade ocloud-app ./charts \
  --set image.repository=ghcr.io/username/cnf-app \
  --set image.tag=v2.0.0 \
  --namespace ocloud

# Verify deployment
kubectl rollout status deployment/ocloud-app -n ocloud
```

### Deployment Verification
After deployment, verify the application status:
```bash
# Check pods
kubectl get pods -n ocloud

# Check services
kubectl get svc -n ocloud

# Check deployment status
kubectl rollout status deployment/ocloud-app -n ocloud

# View logs
kubectl logs -l app.kubernetes.io/name=ocloud-app -n ocloud
```

## Pipeline Configuration

The CD pipeline is configured in `.github/workflows/cd.yaml` and includes:

1. **Authentication**: AWS credentials for EKS access and GHCR for image pulling
2. **Image Pulling**: Pulls latest image from container registry
3. **Helm Deployment**: Installs/updates application using Helm
4. **Verification**: Checks deployment status and runs health checks
5. **Notifications**: Sends success/failure notifications to Slack
6. **Rollback**: Automatic rollback on deployment failure

## Troubleshooting

### Common Issues
- **Image Pull Errors**: Verify registry authentication and image availability
- **RBAC Errors**: Check service account permissions
- **Health Check Failures**: Validate application readiness/liveness probes
- **Timeout Errors**: Increase deployment timeouts if needed

### Debugging Commands
```bash
# Check deployment events
kubectl describe deployment ocloud-app -n ocloud

# Check pod logs
kubectl logs -l app.kubernetes.io/name=ocloud-app -n ocloud

# Check Helm release status
helm status ocloud-app -n ocloud