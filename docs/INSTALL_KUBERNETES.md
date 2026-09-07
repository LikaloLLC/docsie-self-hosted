# Existing Kubernetes / local Linux preview

This path requires a reachable Kubernetes cluster, persistent storage, Helm,
and registry credentials issued by Docsie. The initial application image is
x86_64. See RELEASE_STATUS.md before attempting installation.

```bash
helm dependency build charts/docsie-platform --skip-refresh
python3 scripts/check-images.py charts/docsie-platform --values examples/local.yaml
kubectl create namespace docsie
# Create a docsie-registry pull secret in this namespace using your registry tooling.
# Edit examples/local.yaml: hostname, TLS and storage configuration.
helm upgrade --install docsie charts/docsie-platform -n docsie -f examples/local.yaml --wait --timeout 20m
bash installers/bundle/verify.sh --namespace docsie --release docsie --profile kb
```

The local profile includes PostgreSQL, Redis and MinIO. Their credentials are
generated on first install and retained across upgrades. Migrations run automatically as an install/upgrade hook. Set `bootstrap.enabled: true`
and `bootstrap.adminEmail` to provision an initial administrator. Its generated
password is stored in the `docsie-bootstrap-admin` Secret and is not reset on
upgrade. Public storage/CDN endpoints and model wiring require your configuration.
The full profile additionally requires the compatible image set and ECK operator.

## Offline packaging

`installers/bundle/install.sh` expects a prepared release directory containing
`charts/`, `images/oci-layout/`, optional `k3s/` bootstrap artifacts and
`config/docsie-onprem.values.yaml`. It accepts `--values`, `--hostname`,
`--model-endpoint` and `--profile`; there is no `--env` option.

No such complete offline bundle is released yet. Do not treat the source archive
or chart package as an airgapped installation kit.

## Updates and recovery

Back up databases and object storage before upgrading. Use explicit chart/image
versions and verify migrations. Helm rollback does not undo database migrations.
Do not rotate generated encryption keys during upgrades. Data removal requires
an explicit, separately reviewed teardown.

## Explicit cluster installer

`bash scripts/install-kubernetes.sh /path/to/kubeconfig docsie /path/to/values.yaml`
requires an explicit kubeconfig and provisions no cloud infrastructure. Configure
image access and persistent storage first. See [LOCAL_VALIDATION.md](LOCAL_VALIDATION.md)
for the isolated development rehearsal and its limitations.
