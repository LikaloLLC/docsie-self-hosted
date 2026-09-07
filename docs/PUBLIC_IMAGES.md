# Public Dokuta images — 0.3.0-preview.1

The Dokuta UI, API, Celery worker and LiveKit voice worker are available from Docker Hub without registry credentials. Each image supports `linux/amd64` and `linux/arm64`. These are proprietary application images; see [licensing](LICENSING.md).

This release covers Dokuta components. It does not make the entire Docsie platform image set public or establish a clean full-stack installation. See [release status](RELEASE_STATUS.md) for the remaining installer dependencies. LiveKit still requires its own server and runtime configuration.

| Component | Public image |
| --- | --- |
| Authoring UI | `docsie/selfhosted-dokuta:0.3.0-preview.1` |
| API | `docsie/selfhosted-dokuta-api:0.3.0-preview.1` |
| Celery worker | `docsie/selfhosted-dokuta-celery:0.3.0-preview.1` |
| LiveKit voice worker | `docsie/selfhosted-dokuta-livekit-agent:0.3.0-preview.1` |

```bash
docker pull docsie/selfhosted-dokuta:0.3.0-preview.1
docker pull docsie/selfhosted-dokuta-api:0.3.0-preview.1
docker pull docsie/selfhosted-dokuta-celery:0.3.0-preview.1
docker pull docsie/selfhosted-dokuta-livekit-agent:0.3.0-preview.1
```

## Helm overrides

Merge [public-dokuta-images.yaml](../examples/public-dokuta-images.yaml) after your configured full-profile values. It pins the UI/API/Celery images by digest; it does not configure databases, model endpoints, transcription, ingress or the separate LiveKit worker. No pull secret is needed for these public images. Other components may still require registry access.

```bash
helm template docsie ./charts/docsie-platform \
  -f /path/to/your-full-profile.yaml \
  -f examples/public-dokuta-images.yaml
```

## Verification and limits

All four CI builds passed. Anonymous image-index access confirms AMD64 and ARM64 manifests. This verifies distribution, not end-to-end workflow health. The isolated container suite recorded 827 passed, 2 skipped and 10 failed; five video failures also reproduced with the prior revision, while the remaining failures involved test-service configuration.

Meeting-launch, Recall.ai relay and direct-voice functionality are preserved. The embedded Meeting BaaS credential was removed; supply `MEETINGBAAS_API_KEY` through secret configuration only when using that integration.

## Immutable digests

- `docsie/selfhosted-dokuta@sha256:3ac9b74b29344ea0d90a2ca90b805c3edd35bf8f4779f7e2d9b0f0541ba88d8b`
- `docsie/selfhosted-dokuta-api@sha256:dc3a6550118b8c27ac5722fa7ed4bbe30f7fcd5fcd35b0206a931d20b9f88d7f`
- `docsie/selfhosted-dokuta-celery@sha256:6a7979275fe90300304398e5b0e3edaa450822976af9d443cb85157ca69b2256`
- `docsie/selfhosted-dokuta-livekit-agent@sha256:d4b35caefdad6b530ce35bfb5fc23add8415e38845ff9bd9b787145ecf078767`
