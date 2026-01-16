# O-Cloud Infrastructure Scripts

This directory contains utility scripts for managing O-Cloud infrastructure deployments.

## Available Scripts

### deploy-ocloud-app.sh

A script to deploy the O-Cloud application using the Helm chart.

#### Usage

On Linux/macOS:
```bash
./deploy-ocloud-app.sh [OPTIONS]
```

On Windows (using Git Bash or WSL):
```bash
bash deploy-ocloud-app.sh [OPTIONS]
```

#### Options

- `-n, --namespace STRING`: Kubernetes namespace (default: ocloud-apps)
- `-r, --release STRING`: Helm release name (default: ocloud-app-release)
- `-i, --image STRING`: Docker image repository (default: localhost/ocloud-app)
- `-t, --tag STRING`: Docker image tag (default: latest)
- `-h, --help`: Show help message

#### Examples

Deploy with default settings:
```bash
./deploy-ocloud-app.sh
```

Deploy to a specific namespace with a custom image:
```bash
./deploy-ocloud-app.sh -n production -i myregistry/myapp -t v1.2.3
```

## Requirements

- Helm 3.0+
- kubectl
- Access to a Kubernetes cluster

For Windows users, it's recommended to run these scripts in Git Bash, WSL, or PowerShell with appropriate Unix command-line tools installed.