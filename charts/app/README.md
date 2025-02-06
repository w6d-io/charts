<!-- app-name: app -->
# W6D Kubernetes Helm Charts Library

This repository contains the Kubernetes Helm charts for deploying and managing various applications provided by **Wildcard**.

**Helm Repository:** [https://charts.w6d.io](https://charts.w6d.io)

---

## Overview

The **Wildcard** library enables Kubernetes deployments using Helm. It includes a variety of Helm charts for different services and applications, each designed to facilitate efficient and scalable deployments on Kubernetes.

---

## Features

- Predefined configurations for Kubernetes objects like Deployments, Services, ConfigMaps, and PersistentVolumeClaims.
- Support for TLS certificates via Cert-Manager.
- Network policies and ingress configurations for traffic control.
- Integration with monitoring tools such as Prometheus.
- PostgreSQL setup and role-based access control (RBAC).

---

## Directory Structure

```text
w6d-io-charts/
├── README.md                # Project overview (this file)
├── LICENSE                  # License information (Apache 2.0)
├── CNAME                    # Custom domain configuration for charts
├── cr.yaml                  # Chart releaser configuration
├── ct.yaml                  # Chart testing configuration
├── kind.yaml                # Kubernetes cluster configuration for development
├── charts/                  # Directory for Helm charts
│   ├── app/                 # Helm chart for the 'app' service
│   │   ├── Chart.yaml       # Chart metadata
│   │   ├── values.yaml      # Default values for the chart
│   │   └── templates/       # Kubernetes resource templates
│   └── ...                  # Other charts (ci-operator, ci-status, dlm, etc.)
└── .github/workflows/       # GitHub Actions workflows for CI/CD
```

---

## Usage

## Prerequisites

- Kubernetes 1.18+
- Helm 3

### Adding the Helm Repository

```bash
helm repo add w6dio https://charts.w6d.io
```

## Installing the Chart

For example, to install the `app` chart:

```bash
helm install my-release w6dio/app
```

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```bash
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

---

## Parameters

The following parameters can be configured in the `values.yaml` file to customize the deployment.

### Global parameters

| Name                      | Description                                     | Value |
|---------------------------|-------------------------------------------------|-------|
| `global.imageRegistry`    | Global Docker image registry                    | `""`  |
| `global.imagePullSecrets` | Global Docker registry secret names as an array | `[]`  |
| `global.storageClass`     | Global StorageClass for Persistent Volume(s)    | `""`  |
| `global.kubeVersion`      | Override Kubernetes version                     | `""`  |

---

### Common parameters

| Name                | Description                                        | Value |
|---------------------|----------------------------------------------------|-------|
| `kubeVersion`       | Override Kubernetes version                        | `""`  |
| `nameOverride`      | String to partially override app.names.fullname    | `""`  |
| `fullnameOverride`  | String to fully override app.names.fullname        | `""`  |

---

### Application Parameters

| Name                   | Description                                                                       | Default Value |
|------------------------|-----------------------------------------------------------------------------------|---------------|
| `replicaCount`         | Number of application replicas                                                   | `1`           |
| `name`                 | Application name                                                                 | `"-"`         |
| `id`                   | Application ID                                                                   | `""`          |
| `namespace`            | Kubernetes namespace for the deployment                                          | `""`          |
| `kind`                 | Type of Kubernetes resource (e.g., Deployment)                                   | `""`          |
| `image.repository`     | Docker image repository                                                          | `nginx`       |
| `image.tag`            | Docker image tag                                                                 | `alpine`      |
| `defaultContainer`     | Default container name for multi-container pods                                  | `""`          |
| `generateSecret.enabled` | Enable secret generation                                                        | `false`       |
| `service.name`         | Kubernetes service name                                                          | `"-"`         |
| `service.internalPort` | Internal port for the application                                                | `8080`        |
| `service.externalPort` | External port for the application                                                | `8080`        |
| `service.type`         | Kubernetes service type (e.g., ClusterIP, NodePort, LoadBalancer)                | `ClusterIP`   |
| `resources`            | Resource limits and requests for the application pods                            | `{}`          |
| `nodeSelector`         | Node selector for scheduling                                                     | `{}`          |
| `podAnnotations`       | Annotations for pods                                                             | `{}`          |
| `podLabels`            | Labels for pods                                                                  | `{}`          |
| `strategy`             | Deployment strategy                                                              | `{}`          |

---

### Database Parameters

| Name                    | Description                                          | Default Value |
|-------------------------|------------------------------------------------------|---------------|
| `database.host`         | Database host                                        | `""`          |
| `database.adminpassword`| Admin password for the database                      | `""`          |
| `database.password`     | Database user password                               | `""`          |
| `database.postgres_password` | PostgreSQL root password                        | `""`          |
| `database.component`    | Database component name                              | `""`          |
| `database.enabled`      | Enable database integration                          | `false`       |

---

### Persistence Parameters

| Name           | Description                                                            | Value             |
|----------------|------------------------------------------------------------------------|-------------------|
| `name`         | Name of the volume                                                     | `""`              |
| `mode`         | AccessMode of the volume                                               | `"ReadWriteOnce"` |
| `size`         | Size of the volume                                                     | `"1Gi"`           |
| `storageClass` | Storage Class to use for the volume                                    | `""`              |
| `path`         | Path where the volume will be mount                                    | `""`              |
| `kind`         | Kind of the volume. e.g. `persistentVolumeClaim`                       | `""`              |
| `volumeMode`   | VolumeMode for the volume. e.g. `ephemeral`                            | `""`              |
| `claimName`    | If defined wont create the PVC but add the volume in workflow resource | `""`              |

---

### Volumes Parameters

| Name      | Description                                         | Value |
|-----------|-----------------------------------------------------|-------|
| `name`    | Name of the volume                                  | `""`  |
| `kind`    | Kind of the volume. e.g. `emptyDir`                 | `""`  |
| `path`    | Path where to mount the volume.                     | `""`  |
| `options` | Options for the volume. only use in `emptyDir` kind | `{}`  |

---

### VolumeClaimTemplates Parameters

| Name   | Description                                        | Value |
|--------|----------------------------------------------------|-------|
| `name` | Name of the volume                                 | `""`  |
| `kind` | Kind of the volume. Must be `volumeClaimTemplates` | `""`  |
| `mode` | AccessMode of the volume.                          | `""`  |
| `size` | Size of the volume.                                | `""`  |
| `path` | Path where to mount the volume.                    | `""`  |

---

### Traffic Exposure Parameters

| Name                    | Description                                                                                                                       | Value                           |
|-------------------------|-----------------------------------------------------------------------------------------------------------------------------------|---------------------------------|
| `ingress.enabled`       | Enable ingress record generation App                                                                                              | `false`                         |
| `ingress.host`          | host for the ingress record                                                                                                       | `""`                            |
| `ingress.path`          | path for the ingress record                                                                                                       | `"/"`                           |
| `ingress.annotations`   | Additional annotations for the Ingress resource. To enable certificate auto-generation, place here your cert-manager annotations. | `"/"`                           |
| `ingress.clusterIssuer` | Cert-Manager Cluster issuer for the ingress record                                                                                | `""`                            |
| `ingress.class`         | Class that will be be used to implement the Ingress, `annotations` or `ingressClassName` (Kubernetes 1.18+)                       | `"nginx"`                       |
| `ingress.className`     | IngressClassName that will be be used to implement the Ingress (Kubernetes 1.18+)                                                 | `""`                            |
| `ingress.prefix`        | Ingress prefix to use in annotations                                                                                              | `"nginx.ingress.kubernetes.io"` |
| `ingress.extraPaths`    | Extra paths to implement into the Ingress                                                                                         | `[]`                            |
| `ingress.sslRedirect`   | Add sslRedirect annotation into the Ingress                                                                                       | `false`                         |
| `ingress.tlsAcme`       | Add tlsAcme annotation into the Ingress                                                                                           | `false`                         |
| `ingress.secretName`    | Add or not the secretName for tls into the Ingress                                                                                | `false`                         |

---

### Autoscaling Parameters

| Name                               | Description                               | Default Value |
|------------------------------------|-------------------------------------------|---------------|
| `autoscaling.enabled`              | Enable horizontal pod autoscaling         | `false`       |
| `autoscaling.minReplicas`          | Minimum number of replicas                | `1`           |
| `autoscaling.maxReplicas`          | Maximum number of replicas                | `100`         |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization                   | `80`          |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization               | `""`          |

---

### RBAC and Security Parameters

| Name                    | Description                                              | Default Value |
|-------------------------|----------------------------------------------------------|---------------|
| `serviceAccount.create` | Create a Kubernetes service account                       | `true`        |
| `serviceAccount.token`  | Include service account token                             | `true`        |
| `role.rules`            | Custom RBAC role rules                                    | `null`        |
| `podSecurityPolicy.enabled` | Enable PodSecurityPolicy                              | `false`       |
| `healthcheck.enabled`   | Enable health check policy                                | `false`       |

---

### Monitoring and Metrics Parameters

| Name                    | Description                                              | Default Value |
|-------------------------|----------------------------------------------------------|---------------|
| `metrics.enabled`       | Enable Prometheus metrics                                | `false`       |
| `metrics.path`          | Path to expose metrics                                   | `/metrics`    |
| `metrics.port`          | Port to expose metrics                                   | `8080`        |

---

### Other Parameters

| Name                    | Description                                              | Default Value |
|-------------------------|----------------------------------------------------------|---------------|
| `extraEnv`              | Additional environment variables                         | `""`          |
| `extraResources`        | Additional Kubernetes resources                          | `""`          |
| `env`                   | Environment variable definitions                         | `""`          |
| `initContainers`        | Definitions for init containers                          | `[]`          |

---

### Example: Full `values.yaml` Configuration

```yaml
replicaCount: 3

image:
  repository: "my-custom-app"
  tag: "v1.2.0"

service:
  internalPort: 8081
  externalPort: 8081
  type: LoadBalancer

ingress:
  enabled: true
  host: "myapp.example.com"
  path: /
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"

persistence:
  - name: app-data
    kind: persistentVolumeClaim
    mode: ReadWriteOnce
    size: 10Gi
    path: /data

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "250m"
    memory: "256Mi"
```

### Applying the Changes

Once your `values.yaml` file is ready, you can apply the changes using the Helm command:

```bash
helm install my-release w6dio/app -f values.yaml
```

---

## Contribution Guidelines

- Use `.helmignore` to exclude files from being packaged with Helm charts.
- Follow Kubernetes best practices for defining resources and configurations.

---

## License

This project is licensed under the [Apache 2.0 License](LICENSE).

---