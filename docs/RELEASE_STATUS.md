# Docsie Self-Hosted v0.2.0-preview.1

First public Kubernetes chart preview for the proprietary Docsie application.

## Included

- Application chart `0.3.0-preview.1` and platform chart `0.2.0-preview.1`.
- PostgreSQL, Redis, MinIO and baseline application services.
- Automatic migration hook and optional initial administrator bootstrap.
- Explicit-kubeconfig installer, configuration examples and local-model guide.
- Versioned chart packages, Helm index and SHA-256 checksums.

## Validation

Clean local namespace installation completed without manual migrations or chart
repairs. Administrator API authentication, rendered login, Celery ping, S3
write/read and upgrade preservation passed. Six chart integration tests passed.
See [local validation](LOCAL_VALIDATION.md) for environment and image details.

## Before installing

Obtain compatible application and converter image access from Docsie and set
those image references in your values file. The locally tested image set is not
included in these downloads; default satellite tags are not all published.
This is a chart preview, not a turnkey public image distribution.

Ollama/local model instructions document configuration, not certified full AI
workflows. Validate your model's context, tools, vision and embeddings as needed.
The preview application does not contain new offline license enforcement.

AWS provisioning, offline bundles, full-platform acceptance, backup/restore and
marketplace listing are not part of this release. Existing AWS scaffolding is
experimental. Production ingress, TLS, email and model access need configuration.
