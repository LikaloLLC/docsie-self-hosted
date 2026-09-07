# Installation troubleshooting

[Documentation index](README.md) · [Installation](INSTALL_KUBERNETES.md)

Use the same explicit kubeconfig and namespace throughout. The examples below
use placeholders; substitute the target chosen for this installation.

## Collect the current state

```bash
helm --kubeconfig /path/to/kubeconfig -n docsie status docsie
kubectl --kubeconfig /path/to/kubeconfig -n docsie get pods,jobs,pvc
kubectl --kubeconfig /path/to/kubeconfig -n docsie get events --sort-by=.metadata.creationTimestamp
```

Inspect relevant pod descriptions and logs privately. Redact credentials,
customer content and internal addresses before attaching output to an issue.
Do not share rendered Secrets or a full kubeconfig.

| Symptom | What to check |
| --- | --- |
| `ImagePullBackOff` | Exact image/tag/digest exists, registry credentials are valid, pull Secret is in the target namespace and the image supports the node architecture |
| PVC or pod remains Pending | StorageClass, available storage, node capacity and scheduling events |
| Migration hook fails | Job logs, database readiness and the selected image's migrations; do not delete the database to retry |
| Login page works but images do not | Browser-reachable object-storage URL, ingress/TLS and the public storage settings in the local-model guide |
| Model works on laptop but not in Docsie | Endpoint reachable from pods; pod localhost is not the host; confirm actual model name and credentials |
| New model settings have no effect | Processes may retain Secret-derived environment variables; follow the full-stack restart procedure and drain active jobs first |
| Video processing works but audio transcription fails | A real transcription backend is configured; the Whisper proxy does not supply inference/model weights |
| Voice endpoint is unavailable | Selected image supports the API, feature flags and authentication are configured, and voice backend/worker services actually exist |

## Diagnose before changing configuration

For an affected pod, replace `POD_NAME` with its name from the state listing:

```bash
kubectl --kubeconfig /path/to/kubeconfig -n docsie describe pod POD_NAME
kubectl --kubeconfig /path/to/kubeconfig -n docsie logs POD_NAME --all-containers --tail=100
```

A Helm timeout is a reason to inspect hooks, scheduling and service logs. It does
not by itself identify the failing component. Preserve data and existing generated
keys while repairing the configuration.

## Ask for help

Include the requested use case, source tag/commit, chart version, image references,
node architecture, Kubernetes version, failing step and redacted error text in a
[repository issue](https://github.com/LikaloLLC/docsie-self-hosted/issues).
For private deployment assistance or image credentials, [contact Docsie](https://www.docsie.io/demo/).
