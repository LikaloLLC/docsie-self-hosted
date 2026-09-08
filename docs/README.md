# Docsie self-hosted documentation

- [System sizing and total cost of ownership](SIZING_AND_COST.md): application/model capacity, hosted inference prices and monthly cost worksheet.

[Main README](../README.md) · [Installation](INSTALL_KUBERNETES.md) · [Agent instructions](../AGENTS.md)

## Choose your path

| I want to… | Start here |
| --- | --- |
| Understand what Docsie does | [Product use cases](../README.md#what-you-can-use-docsie-for) |
| Tell an agent what to install | [Use-case procedures](INSTALL_BY_USE_CASE.md), then [AGENTS.md](../AGENTS.md) |
| Install into existing Kubernetes | [Kubernetes installation](INSTALL_KUBERNETES.md) |
| Connect Ollama or local models | [Local-model walkthrough](LOCAL_MODELS.md) |
| Include Dokuta/video processing | [Full-stack configuration and validation](FULL_STACK_VALIDATION.md) |
| Check which release to use | [Release status](RELEASE_STATUS.md) |
| Diagnose an installation | [Troubleshooting](TROUBLESHOOTING.md) |
| Understand personal/business terms | [Licensing](LICENSING.md) |

## Installation sequence

1. Select your use cases and check release availability.
2. Obtain compatible images and choose the target cluster and persistent storage.
3. Prepare private values, credentials, hostname and model routes.
4. Run image preflight and install with the explicit-kubeconfig installer.
5. Verify login, publishing and each requested workflow.
6. Keep the configuration and versions for future backup and upgrade work.

## Validation and operations

- [Baseline local validation](LOCAL_VALIDATION.md) records the tested KB install.
- [Full-stack validation](FULL_STACK_VALIDATION.md) records development results and gaps.
- [Acceptance checklist](ACCEPTANCE.md) covers broader qualification; AWS-specific
  items apply only when AWS provisioning is in scope.
- [Updates and recovery](INSTALL_KUBERNETES.md#updates-and-recovery) explains backup,
  migration and rollback boundaries. A complete production restore procedure is
  not yet qualified by this preview.

## Common questions

**Is commercial use free?** Yes, for up to 10 active application users per
installation, with no time limit. More than 10 users requires a paid commercial
license. Infrastructure and inference costs are supplied by the operator.

**Is Docsie open source?** No. This is a public deployment repository for a
proprietary application. See [the distribution notice](../LICENSE) and [terms](LICENSING.md).

**Can I install entirely from public downloads?** Not yet. Released charts are
public, but compatible application image access must currently be obtained from Docsie.

**Can AI run locally?** The configuration supports local model endpoints.
Generation, vision, embeddings, transcription and speech are separate routes;
validate the required capabilities and cloud-fallback settings.

**Are Whisper, Chatterbox and live voice included?** The Whisper proxy is present
in the development full stack. Actual local Whisper and Chatterbox models/servers,
and LiveKit voice-worker integration, are still packaging work.

**Does the source ZIP contain an offline installer?** No. Charts alone are not
an offline bundle of images, dependencies and models.

**Is AWS one-click ready?** No. AWS provisioning is a separate roadmap item.

- [Search installation and verification](SEARCH.md) — bundled App Search, credentials and browser endpoint.

- [Local text-to-speech](TEXT_TO_SPEECH.md) — optional Chatterbox CPU/GPU installation and native Apple Silicon setup.
