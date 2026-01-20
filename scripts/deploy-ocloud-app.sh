#!/bin/bash

# Script to deploy O-Cloud application using Helm chart
# This script assumes you have already built your Docker image and loaded it into your Kubernetes cluster

set -e  # Exit immediately if a command exits with a non-zero status

echo "🚀 Starting O-Cloud application deployment..."

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed. Please install Helm first."
    exit 1
fi

# Check if kubectl is installed and connected to a cluster
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if we're connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ No Kubernetes cluster detected. Please connect to a cluster first."
    exit 1
fi

# Set default values
NAMESPACE="ocloud-apps"
RELEASE_NAME="ocloud-app-release"
IMAGE_REPO="ghcr.io/Deann7/cnf-simulator"
IMAGE_TAG="latest"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE_REPO="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Deploy O-Cloud application using Helm"
            echo ""
            echo "Options:"
            echo "  -n, --namespace STRING   Kubernetes namespace (default: ocloud-apps)"
            echo "  -r, --release STRING     Helm release name (default: ocloud-app-release)"
            echo "  -i, --image STRING       Docker image repository (default: ghcr.io/Deann7/cnf-simulator)"
            echo "  -t, --tag STRING         Docker image tag (default: latest)"
            echo "  -h, --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "🔧 Using namespace: $NAMESPACE"
echo "🔧 Using release name: $RELEASE_NAME"
echo "🔧 Using image: $IMAGE_REPO:$IMAGE_TAG"

# Create namespace if it doesn't exist
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "📦 Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE
else
    echo "✅ Namespace $NAMESPACE already exists"
fi

# Package and install the Helm chart
echo "🔨 Packaging and installing Helm chart..."
helm upgrade --install $RELEASE_NAME ./charts/ocloud-app \
    --namespace $NAMESPACE \
    --set image.repository=$IMAGE_REPO \
    --set image.tag=$IMAGE_TAG \
    --set service.targetPort=8080 \
    --create-namespace

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available deployment/ocloud-app-$RELEASE_NAME \
    --namespace $NAMESPACE \
    --timeout=300s

echo "✅ O-Cloud application deployed successfully!"
echo "📊 Release: $RELEASE_NAME"
echo "📊 Namespace: $NAMESPACE"
echo "📊 Image: $IMAGE_REPO:$IMAGE_TAG"

# Display service information
echo ""
echo "📋 Service Information:"
kubectl get service ocloud-app-$RELEASE_NAME --namespace $NAMESPACE

echo ""
echo "💡 To access the application, you can port-forward:"
echo "   kubectl port-forward -n $NAMESPACE svc/ocloud-app-$RELEASE_NAME 8080:80"

echo ""
echo "🔍 To check the status of your deployment:"
echo "   kubectl get pods -n $NAMESPACE"
echo "   helm status $RELEASE_NAME -n $NAMESPACE"