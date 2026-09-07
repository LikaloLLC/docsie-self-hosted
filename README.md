# Docsie Self-Hosted

Deploy the proprietary Docsie application on Kubernetes you control.

**v0.2.0-preview.2 — Kubernetes deployment preview.** A clean local installation,
automatic migrations, administrator login, worker health, MinIO storage and
upgrade preservation have been tested. See [validation](docs/LOCAL_VALIDATION.md).

This release contains charts and deployment tooling, **not application images**.
Request compatible image access from Docsie before installing. Default satellite
image tags are not yet a publicly downloadable image set. AI workflows have not
been certified end to end with Ollama in this release.

## Start here

1. [Request image access](https://www.docsie.io/demo/) for a personal installation
   or business evaluation.
2. Follow [Kubernetes installation](docs/INSTALL_KUBERNETES.md).
3. Configure [Ollama or another local model server](docs/LOCAL_MODELS.md).
4. Run the [acceptance checklist](docs/ACCEPTANCE.md) for your workflows.

```bash
git clone https://github.com/LikaloLLC/docsie-self-hosted.git
cd docsie-self-hosted
git checkout v0.2.0-preview.2
# Configure image access, hostname, TLS, storage and an administrator first.
bash scripts/install-kubernetes.sh /path/to/kubeconfig docsie /path/to/values.yaml
```

The baseline chart includes PostgreSQL, Redis, MinIO, Elasticsearch, web/worker
processes and document/image converters. Target production architecture is Linux
x86_64; the documented Mac rehearsal uses emulation and locally prepared images.

## Downloads

[Releases](https://github.com/LikaloLLC/docsie-self-hosted/releases) provide the
application chart, platform chart, Helm repository index and SHA-256 checksums.
The platform package bundles chart dependencies. Download and install its `.tgz`
with your values file, or use the source installer above.

```bash
sha256sum -c SHA256SUMS
helm upgrade --install docsie ./docsie-platform-0.2.0-preview.1.tgz \
  --kubeconfig /path/to/kubeconfig --namespace docsie --create-namespace \
  -f /path/to/values.yaml --wait --timeout 20m
```

## License and access

Docsie is **not open source**. Public deployment tooling does not change the
application license. Personal non-commercial use is free; business evaluation
is 30 days for up to 100 application users; continued commercial use requires a
paid license. Infrastructure and model inference are supplied by the operator.
See [licensing](docs/LICENSING.md) and [distribution notice](LICENSE).

## Roadmap

AWS provisioning is the next separate milestone. The inherited `installers/aws`
scaffolding is experimental and not a supported deployment path in this release.
Do not treat it as a verified one-click installer. Full offline bundles,
production backup/restore qualification and marketplace listings follow later.

## Development

```bash
python3 -m pip install -r requirements-dev.txt
bash scripts/package-release.sh
```

See [release status](docs/RELEASE_STATUS.md) for the exact verification boundary.
