# Local Helm rehearsal — 2026-09-07

This validates the chart/configuration layer independently of AWS, using one
unchanged Docsie application image.

## Environment

Isolated Docker container `docsie-helm-local`, k3s `v1.33.5-k3s1`, dedicated
kubeconfig. No default Kubernetes context changes. Apple Silicon Docker VM with
8 GiB RAM: application and PDF images use x86 emulation; remaining components
are native ARM. This is not production sizing or ARM release qualification.

`examples/local-rehearsal.yaml` runs one web worker and one Celery process
serving all four configured queues. Beat and AI are not evaluated.

The imported application manifest is
`sha256:b628b5824bf5364adefa6f25a9f993d4e9f5571472e7953c7d8b0709beafc518`,
tagged `docsie/docsie-server:helm-local-single`. Its single amd64 manifest was
selected from an existing OCI index for ARM CRI/emulation, without code changes.
The PDF converter was imported locally; image processor built from existing
source. These tags are not publicly downloadable release images.

## Verified

Final charts installed successfully at revision 1 in a new `docsie-clean`
namespace with empty persistent volumes. No intervening chart edits or manual
migration commands were needed. Fresh-schema migration, administrator login,
Celery ping and S3 write/read all passed. The earlier `docsie` namespace is
scaled to zero to preserve its upgrade-test data without consuming memory.

- Generated Postgres, Redis and application credentials work together.
- Hooks apply migrations and bootstrap an administrator.
- Login page returns HTTP 200 and renders in the browser.
- Administrator authenticates through `/rest-auth/login/` with HTTP 200.
- Celery connects to Redis and reaches ready state.
- Docsie's `S3Boto3Storage` writes and reads a synthetic MinIO object.
- Helm upgrade preserves all three generated Secret data maps, the database
  administrator, and object content (SHA-256 checked).
- No pending Django migrations after upgrade.
- Six real Helm-render integration tests pass.
- Explicit-kubeconfig installer wrapper completed a subsequent upgrade with
  `--wait`; all eight service pods remained ready with zero restarts.

## Fixes

Automatic migration and optional administrator hooks; service-link environment
variables disabled to prevent Redis port collisions; Postgres/Redis startup
wait; explicit local bucket settings and packaged static URLs; corrected local
SSR queue name `server_side_render_queue`.

## Repeat

Prepare local Kubernetes and import the three development images, or substitute
accessible compatible registry images. This profile uses `pullPolicy: Never`.

```bash
bash scripts/install-kubernetes.sh /absolute/path/to/local-kubeconfig docsie examples/local-rehearsal.yaml
kubectl --kubeconfig /absolute/path/to/local-kubeconfig -n docsie port-forward svc/docsie-web 58081:80
# Separate terminal for public object URLs:
kubectl --kubeconfig /absolute/path/to/local-kubeconfig -n docsie port-forward svc/minio 59000:9000
```

Open `http://127.0.0.1:58081/onboarding/v3/login/`. Retrieve the initial password
privately from `docsie-bootstrap-admin`; never paste it into issues/logs. The
sample administrator is `helm-admin@example.test`.

## Boundaries

Basic installation, configuration, authentication and storage were exercised.
Full document/portal/AI/video acceptance, backup/restore, ingress/TLS, email and
model setup remain. External login assets remain, so this is not offline proof.
AWS provisioning and marketplace distribution are separate work. No cloud
infrastructure was provisioned.
