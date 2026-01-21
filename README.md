# O-Cloud Infrastructure Repository

This repository contains Kubernetes manifests and Helm charts for deploying the O-Cloud application with integrated security scanning and quality gates.

## Contents

The repository is organized into the following directories:

### 1. Manifests (`manifests/`)
Contains individual Kubernetes resource files for direct deployment:

#### Deployment (`manifests/deployment.yaml`)
- Deploys the O-Cloud application with 3 replicas
- Includes liveness and readiness probes that check the `/health` endpoint
- Sets resource limits (100m CPU, 128Mi memory) and requests (50m CPU, 64Mi memory)
- Configures the container to expose port 8080

#### Service (`manifests/service.yaml`)
- Creates a NodePort service to allow external access to the O-Cloud application
- Maps internal port 8080 to external port 30080
- Uses selectors to connect to pods with the label `app=cnf-simulator`

#### Network Policy (`manifests/network-policy.yaml`)
- Implements micro-segmentation security
- Allows inbound traffic only on port 8080
- Applies to pods with the label `app=cnf-simulator`

### 2. Helm Charts (`charts/`)
Contains packaged Helm charts for simplified deployment:

#### O-Cloud Application Chart (`charts/ocloud-app/`)
- Packaged Helm chart for the O-Cloud application
- Configurable parameters for easy customization
- Includes all necessary Kubernetes resources (Deployment, Service, NetworkPolicy)
- Built with security best practices in mind
- Integrated security scanning and quality gates configurations

### 3. Scripts (`scripts/`)
Utility scripts for common operations:

#### Deploy Script (`scripts/deploy-ocloud-app.sh`)
- Automated deployment script using Helm
- Handles namespace creation and chart installation
- Includes validation and status checking

## Security Scanning and Quality Gates

This infrastructure implements comprehensive security scanning and quality gates:

### Security Scanning Configuration
- Container vulnerability scanning using Trivy
- Minimum security rating requirements (configurable per environment)
- Maximum vulnerability count limits
- Runtime security monitoring

### Quality Gates Configuration
- Code coverage thresholds (minimum 70% dev, 90% prod)
- Performance testing with response time and throughput requirements
- Health checks for liveness and readiness
- Environment-specific quality requirements

### Environment-Specific Security Settings

#### Development Environment (`values-dev.yaml`)
- Minimum security rating: "C"
- Max vulnerabilities: 10
- Quality gates: Enabled with lower thresholds
- Performance requirements: Relaxed (1000ms response time, 50 RPS)

#### Production Environment (`values-prod.yaml`)
- Minimum security rating: "A"
- Max vulnerabilities: 0 (zero tolerance)
- Quality gates: Enabled with strictest thresholds
- Performance requirements: Strict (200ms response time, 200 RPS)

## Deployment Options

### Option 1: Direct Manifests Deployment

To deploy using individual Kubernetes manifests:

```bash
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/service.yaml
kubectl apply -f manifests/network-policy.yaml
```

### Option 2: Helm Chart Deployment

To deploy using the Helm chart:

```bash
# Install the chart directly
helm install ocloud-app-release charts/ocloud-app --namespace ocloud-apps --create-namespace

# Or use the deployment script
./scripts/deploy-ocloud-app.sh
```

## Accessing the Application

Once deployed, the O-Cloud application will be accessible via:
- Internal cluster: `http://ocloud-app-service:80`
- External access: `http://<NODE_IP>:30080` (when using NodePort service)

## Endpoints

After deployment, the following endpoints will be available:
- `/health` - Health check endpoint
- `/status` - Status information
- `/config` - Configuration details
- `/info` - Service information
- `/security` - Security scan information
- `/quality` - Quality metrics information

## Environment-Specific Deployments

This infrastructure supports multiple environments using different value files:

- Development: `values-dev.yaml` - Single replica, NodePort service, less restrictive security
- Production: `values-prod.yaml` - Multiple replicas, LoadBalancer service, enhanced security and autoscaling

To deploy to different environments:

```bash
# Deploy to development
helm install ocloud-app-dev charts/ocloud-app -f charts/ocloud-app/values-dev.yaml --namespace ocloud-dev --create-namespace

# Deploy to production
helm install ocloud-app-prod charts/ocloud-app -f charts/ocloud-app/values-prod.yaml --namespace ocloud-prod --create-namespace
```