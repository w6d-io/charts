<!-- app-name: app -->

# App

The App chart can deal with the standard application deployment

## TL;DR

Without custom values it will install nginx.

## Prerequisites

- Kubernetes 1.18+
- Helm 3

## Installing the Chart

```bash
$ helm repo add w6dio https://charts.w6d.io
$ helm update --install my-release w6dio/app
```

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```bash
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Parameters

### Global parameters

| Name                      | Description                                     | Value |
|---------------------------|-------------------------------------------------|-------|
| `global.imageRegistry`    | Global Docker image registry                    | `""`  |
| `global.imagePullSecrets` | Global Docker registry secret names as an array | `[]`  |
| `global.storageClass`     | Global StorageClass for Persistent Volume(s)    | `""`  |
| `global.kubeVersion`      | Override Kubernetes version                     | `""`  |

### Common parameters

| Name                | Description                                        | Value |
|---------------------|----------------------------------------------------|-------|
| `kubeVersion`       | Override Kubernetes version                        | `""`  |
| `nameOverride`      | String to partially override global.names.fullname | `""`  |
| `fullnameOverride`  | String to fully override global.names.fullname     | `""`  |

### App parameters

| Name                   | Description                                                                       | Value           |
|------------------------|-----------------------------------------------------------------------------------|-----------------|
| `kind`                 | kind of workflow resource to create. eg : Deployment, DaemonSet, StatefulSet, Job | `"Deployement"` |
| `persistence`          | persistence is for create PersistentVolumeClaim and bind it in workflow           | `[]`            |
| `volumes`              | volumes to bind it in workflow                                                    | `[]`            |
| `volumeClaimTemplates` | volume claims to add and bind it in StatefulSet workflow kind                     | `[]`            |

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

### Volumes Parameters

| Name      | Description                                         | Value |
|-----------|-----------------------------------------------------|-------|
| `name`    | Name of the volume                                  | `""`  |
| `kind`    | Kind of the volume. e.g. `emptyDir`                 | `""`  |
| `path`    | Path where to mount the volume.                     | `""`  |
| `options` | Options for the volume. only use in `emptyDir` kind | `{}`  |

### VolumeClaimTemplates Parameters

| Name   | Description                                        | Value |
|--------|----------------------------------------------------|-------|
| `name` | Name of the volume                                 | `""`  |
| `kind` | Kind of the volume. Must be `volumeClaimTemplates` | `""`  |
| `mode` | AccessMode of the volume.                          | `""`  |
| `size` | Size of the volume.                                | `""`  |
| `path` | Path where to mount the volume.                    | `""`  |

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

## TODO 

to be continued
