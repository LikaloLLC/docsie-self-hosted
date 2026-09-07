# Existing Kubernetes / local Linux preview

Plan application and inference capacity separately using the [system sizing and TCO guide](SIZING_AND_COST.md). Its pilot envelope is an estimate, not a validated minimum.

This path requires a reachable Kubernetes cluster, persistent storage, Helm,
and registry credentials issued by Docsie. The initial application image is
x86_64. See RELEASE_STATUS.md before attempting installation.

```bash
helm dependency build charts/docsie-platform --skip-refresh
python3 scripts/check-images.py charts/docsie-platform --values examples/local.yaml
# Create your registry pull Secret in the explicitly selected namespace.
# Edit examples/local.yaml: hostname, TLS, storage and browser search endpoint.
bash scripts/install-kubernetes.sh /absolute/path/to/kubeconfig docsie /absolute/path/to/values.yaml
```

The local profile includes PostgreSQL, Redis and MinIO. Their credentials are
generated on first install and retained across upgrades. Migrations run automatically as an install/upgrade hook. Set `bootstrap.enabled: true`
and `bootstrap.adminEmail` to provision an initial administrator. Its generated
password is stored in the `docsie-bootstrap-admin` Secret and is not reset on
upgrade. Public storage/CDN endpoints and model wiring require your configuration.
App Search is included in the basic profile. The wrapper installs the vendored
ECK operator/CRDs if absent, bootstraps credentials, and tests indexing/search.
Configure the browser search endpoint using [the search guide](SEARCH.md).
The full profile additionally requires the compatible Dokuta/satellite image set.

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
