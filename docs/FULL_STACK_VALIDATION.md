# Full-stack rehearsal — work in progress, 2026-09-07

The full profile is now running in the isolated local k3s cluster. The public
release remains a KB installation preview; this is not a public-image release.

## Locally confirmed

- Sixteen service pods ready, including Dokuta UI, API, worker, ChromaDB,
  collaboration relay, PPTX renderer, OCR runtime and Whisper adapter.
- Dokuta database schema and a service-account API key bootstrapped by Helm.
- Docsie authenticated to the internal Dokuta API using that generated key.
- Missing and invalid API keys return HTTP 401; the service key returns 200.
- The cluster can reach the host's Ollama text and vision models.
- A synthetic video was uploaded, persisted, queued, processed and returned
  an HTTP-200 Markdown artifact. The test-pattern artifact had no workflow
  steps, so it is transport/job/storage proof, not documentation-quality proof.
- Seven chart tests pass, including required secret-key references for all
  three Dokuta workloads and the shared service-account credential.

## Fixes from the rehearsal

The FastAPI pod now disables Kubernetes service-link variables. The worker's
three optional tuning settings no longer prevent startup when absent. A local
OCR runtime image includes the Python dependencies missing from the bare image.
The full-profile platform secret supplies the internal Dokuta endpoint/key;
`examples/full.yaml` explicitly changes the endpoint to roll existing Docsie
pods when upgrading from the KB-only profile. A hook applies the API image's
local migrations and creates the service account without rotating its key.

## Outstanding release gates

- Publish a consistent, audited image set for Linux x86_64. Current Dokuta
  on-prem tags are ARM-only and require registry access. The local renderer
  and OCR image overrides are not a public release set.
- Rebuild current Dokuta code: the inherited API image lacks the quick-video
  endpoint and includes only the earlier local database migration.
- Add/configure an actual transcription backend. The healthy Whisper adapter
  is a proxy, not a speech model; Ollama's installed vision/text models do not
  provide this backend. Audio processing has not been disabled or validated.
- Configure and test embeddings and meaningful document generation. The
  15-second synthetic workflow probe reached the local vision model, but an
  approximately 10k-token multi-frame request was cancelled at the 120-second
  default timeout. The full template now sets a configurable 600-second timeout;
  that longer-timeout workflow has not yet been validated.
- Complete image dependency/license review and include notices/source materials
  as required before public redistribution.
- Re-run the full clean installation with final images; verify upgrades,
  authentication, public object URLs and externally exposed UI/API security.

The local test is mixed architecture on an 8 GiB Docker VM and does not establish
production sizing. No AWS or customer cluster was modified.

## Changing model configuration

The Dokuta workloads read model settings from Kubernetes Secrets at process
startup. After changing those settings with Helm, restart `dokuta`,
`dokuta-fastapi` and `dokuta-celery` in the explicitly selected kubeconfig and
namespace. Drain active jobs before restarting workers in a real installation.
The local retry uses a 600-second timeout and a three-frame cap solely for the
synthetic fixture; that frame cap is not a production quality recommendation.
