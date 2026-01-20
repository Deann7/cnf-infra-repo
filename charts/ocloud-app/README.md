# O-Cloud Application Helm Chart

This Helm chart deploys the O-Cloud application on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

## Installing the Chart

To install the chart with the release name `my-ocloud-app`:

```bash
helm install my-ocloud-app ../cnf-infra-repo/charts/ocloud-app
```

## Uninstalling the Chart

To uninstall the `my-ocloud-app` deployment:

```bash
helm delete my-ocloud-app
```

## Configuration

The following table lists the configurable parameters of the ocloud-app chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of application pods | `2` |
| `image.repository` | Image repository | `ghcr.io/Deann7/cnf-simulator` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.tag` | Image tag | `latest` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Target port in the container | `8080` |
| `ingress.enabled` | Enable ingress | `false` |
| `resources` | CPU/Memory resource requests/limits | `{}` |
| `nodeSelector` | Node labels for pod assignment | `{}` |
| `tolerations` | List of node taints to tolerate | `[]` |
| `affinity` | Map of node/pod affinities | `{}` |

## Values File Example

```yaml
replicaCount: 3
image:
  repository: myregistry/ocloud-app
  tag: v1.0.0
  pullPolicy: Always
service:
  type: LoadBalancer
  port: 80
  targetPort: 8080
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

To use a custom values file:

```bash
helm install my-ocloud-app ../cnf-infra-repo/charts/ocloud-app -f my-values.yaml
```

## Registry Integration

This chart is designed to work with container registries like GitHub Container Registry (GHCR).
The default image is pulled from `ghcr.io/Deann7/cnf-simulator`, which is built and pushed by the CI pipeline.

For private registries, you may need to create image pull secrets:

```bash
kubectl create secret docker-registry registry-secret \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>
```

Then reference the secret in your values file:

```yaml
imagePullSecrets:
  - name: registry-secret
image:
  repository: <your-private-registry>/cnf-simulator
  tag: <specific-tag>