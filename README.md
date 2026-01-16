# O-Cloud Infrastructure Repository

This repository contains Kubernetes manifests and Helm charts for deploying the O-Cloud application.

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

### 3. Scripts (`scripts/`)
Utility scripts for common operations:

#### Deploy Script (`scripts/deploy-ocloud-app.sh`)
- Automated deployment script using Helm
- Handles namespace creation and chart installation
- Includes validation and status checking

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