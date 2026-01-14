# CNF Infrastructure Repository

This repository contains Kubernetes manifests for deploying the Cloud-Native Network Function (CNF) simulator application.

## Manifests

The `manifests/` directory contains the following Kubernetes resources:

### 1. Deployment (`deployment.yaml`)
- Deploys the CNF simulator application with 3 replicas
- Includes liveness and readiness probes that check the `/health` endpoint
- Sets resource limits (100m CPU, 128Mi memory) and requests (50m CPU, 64Mi memory)
- Configures the container to expose port 8080

### 2. Service (`service.yaml`)
- Creates a NodePort service to allow external access to the CNF simulator
- Maps internal port 8080 to external port 30080
- Uses selectors to connect to pods with the label `app=cnf-simulator`

### 3. Network Policy (`network-policy.yaml`)
- Implements micro-segmentation security
- Allows inbound traffic only on port 8080
- Applies to pods with the label `app=cnf-simulator`

## Deployment Instructions

To deploy the CNF simulator to a Kubernetes cluster:

```bash
kubectl apply -f manifests/deployment.yaml
kubectl apply -f manifests/service.yaml
kubectl apply -f manifests/network-policy.yaml
```

## Accessing the Application

Once deployed, the CNF simulator will be accessible via:
- Internal cluster: `http://cnf-simulator-service:8080`
- External access: `http://<NODE_IP>:30080`

## Endpoints

After deployment, the following endpoints will be available:
- `/health` - Health check endpoint
- `/status` - Status information
- `/config` - Configuration details
- `/info` - Service information