# Docsie Self-Hosted v0.2.0-preview.5

This preview adds optional Chatterbox text-to-speech, with pinned AMD64 CPU and
NVIDIA image options, persistent model caching, Dokuta routing and a speech test.
See [the speech installation guide](https://github.com/LikaloLLC/docsie-self-hosted/blob/main/docs/TEXT_TO_SPEECH.md).

It also packages App Search as part of the basic Docsie installation.
The installer provisions its Elastic operator, creates search credentials and
runs a real indexing/search check. See [search setup and validation](SEARCH.md).

## Included

- Application chart `0.3.0-preview.2`, platform chart `0.2.0-preview.5`, and
  Elastic's operator chart/CRDs `2.16.1` with its upstream license.
- Elasticsearch and Enterprise Search/App Search `8.12.0`, TLS verification,
  automatic indexing and read-only signing keys, and a focused Helm search test.
- PostgreSQL, Redis, MinIO, migration hooks and optional administrator bootstrap.
- A corrected Chroma persistent-volume mount for the optional full profile.
- Explicit-kubeconfig installer, configuration guides, chart archives, Helm index
  and SHA-256 checksums.

## Validation

A fresh isolated search installation, two credential-preserving upgrades,
indexing, retrieval, signed-filter enforcement and read-only key enforcement
passed against running services. Docsie's actual application search client
connected using certificate verification. The existing local Docsie installation
upgraded successfully through the installer with 18 service pods ready and the
focused search test passing.

Sixteen distribution/bootstrap tests, Helm lint, the distribution audit and
chart packaging passed. Search/operator/bootstrap images support AMD64 and ARM64;
live search validation used ARM64. The local application image was emulated.
This is not a fresh full-platform or browser-facing portal acceptance result.
The earlier basic installation proof is retained in [LOCAL_VALIDATION.md](LOCAL_VALIDATION.md).

Native CPU speech generation passed with the pinned Chatterbox source: a
non-silent 1.68-second, 24-kHz WAV. Linux container execution, NVIDIA inference,
Dokuta HTTP speech integration and live calls remain separate validation targets.
Native Mac MPS failed upstream; the native installer defaults to CPU.

## Before installing or upgrading

Compatible application and converter image access is still required. Dokuta's
public AMD64/ARM64 images are available; see [image references](PUBLIC_IMAGES.md).
The complete publicly pullable platform image set remains a separate milestone.
This is a chart preview, not a turnkey public image distribution or offline bundle.

Configure browser-reachable search DNS/TLS using [SEARCH.md](SEARCH.md). Existing
full-profile installations must preserve old Chroma container data before mounting
its PVC; the guide explains this migration. Back up data and Secrets before upgrades.
The installer preserves search keys; it does not migrate an external search index.

Ollama/local model instructions describe configuration, not certified AI workflows.
The preview application does not contain new offline-license enforcement.
AWS provisioning, full-platform acceptance, backup/restore qualification and
marketplace listing remain separate work. AWS scaffolding is experimental.
