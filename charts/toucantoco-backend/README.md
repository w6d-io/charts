# Toucantoco Backend

[Toucantoco](https://toucantoco.com) Unlock your insight culture at scale with Data Stories

## TL;DR

```console
$ helm repo add w6dio https://charts.w6d.io
$ helm install my-release w6dio/toucantoco-backend
```

## Introduction

This chart is to help to install toucantoco architecture in kubernetes environment
## Prerequisites

- Kubernetes 1.12+
- Helm 3.1.0
- PV provisioner support in the underlying infrastructure

## Installing the Chart
To install the chart with the release name `my-release`:

```console
$ helm install my-release w6dio/toucantoco-backend
```

> **Tip**: List all releases using `helm list`

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```console
$ helm delete my-release
```

The command removes all the Kubernetes components but PVC's associated with the chart and deletes the release.

To delete the PVC's associated with `my-release`:

```console
$ kubectl delete pvc -l release=my-release
```

> **Note**: Deleting the PVC's will delete postgresql data as well. Please be cautious before doing it.

## Parameters

The following tables lists the configurable parameters of the Toucan Toco backend chart and their default values.
| Parameter                                     | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Default                                                       |
|-----------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------|
| `replicaCount`                                | Number of replicas of the Toucan Toco backend deployment                                                                                                                                                                                                                                                                                                                                                                                                                   | `1`                                                           |
| `image.repository`                            | Toucan Toco Backend image name                                                                                                                                                                                                                                                                                                                                                                                                                                             | `quay.io/toucantoco/backend`                                  |
| `image.tag`                                   | Toucan Toco Backend image tag                                                                                                                                                                                                                                                                                                                                                                                                                                              | `chart appVersion`                                            |
| `image.pullPolicy`                            | Toucan Toco Backend image pull policy                                                                                                                                                                                                                                                                                                                                                                                                                                      | `IfNotPresent`                                                |
| `imagePullSecrets`                            | List of secret name that contains docker credential                                                                                                                                                                                                                                                                                                                                                                                                                        | `[]`                                                          |
| `nameOverride`                                | String to partially override common names fullname                                                                                                                                                                                                                                                                                                                                                                                                                         | `nil`                                                           |
| `fullnameOverride`                            | String to fully override common names fullname                                                                                                                                                                                                                                                                                                                                                                                                                             | `nil`                                                           |
| `serviceAccount.create`                       | Specify whether or not to create the service account for run the deployment                                                                                                                                                                                                                                                                                                                                                                                                | `true`                                                           |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```bash
$ helm install my-release \
  --set imagePullPolicy=Always \
    w6dio/toucantoco-backend
```

