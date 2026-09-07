# Installing Docsie with an AI agent

This repository distributes Helm charts and installation tooling for the
proprietary Docsie application. Use these instructions when helping an operator
install or upgrade Docsie. Run commands from the repository root.

## Start with the use case

When an operator asks to install Docsie, begin with the outcome they describe.
Use [the use-case overview](docs/USE_CASES.md) and
[installation procedures](docs/INSTALL_BY_USE_CASE.md) to select dependencies.
Combine multiple requested use cases in one installation. Do not ask operators
to choose chart profiles before explaining which services their use case needs.
Follow the procedure through configuration, installation and outcome verification;
report unbundled components explicitly rather than inventing installation flags.

## Read first

- [Release status](docs/RELEASE_STATUS.md): released capabilities and image access.
- [Kubernetes installation](docs/INSTALL_KUBERNETES.md): prerequisites and installer.
- [Ollama walkthrough](docs/LOCAL_MODELS.md): model networking, organization routing,
  administrator login and storage access.
- [Full-stack validation](docs/FULL_STACK_VALIDATION.md): Dokuta development status.
- [Text-to-speech](docs/TEXT_TO_SPEECH.md): optional Chatterbox installation and speech verification.
- [Search](docs/SEARCH.md): mandatory App Search, operator, keys and browser endpoint.
- [Licensing](docs/LICENSING.md): application terms.

Check the selected checkout's release status. A newer development chart is not
necessarily included in the latest release. Public charts do not currently
provide a complete publicly pullable application image set or an offline bundle.

## Establish the target

Use the operator's existing context and choices; ask only for missing inputs:

- Explicit kubeconfig, intended context, namespace and existing/new installation.
- Node architecture, persistent StorageClass and available resources.
- Supplied image versions/digests and registry access.
- Hostname, TLS/ingress, browser-accessible object-storage URL and admin email.
- Required profile: baseline KB, KB AI, or full stack including Dokuta/video-to-docs.
- Model endpoints and installed model names; transcription choice for video audio.

Use an existing authorized cluster. AWS provisioning is a separate, experimental
path; it is not required for this installation. Do not infer a target from the
machine's default Kubernetes context. Do not delete namespaces, PVCs or data to
repair an installation. Back up databases and object storage before upgrades;
Helm rollback does not reverse database migrations.

## Prepare and install

1. Select a release tag for a released installation, or record the exact commit
   when the operator requests development features. Preserve local changes.
2. Check tools: Helm 3, kubectl, Python 3 and Docker with buildx for image checks.
3. Inspect the explicitly selected cluster:

   ```bash
   kubectl --kubeconfig /path/to/kubeconfig config current-context
   kubectl --kubeconfig /path/to/kubeconfig get nodes
   kubectl --kubeconfig /path/to/kubeconfig get storageclass
   ```

4. Prepare a private values file using `docs/LOCAL_MODELS.md` for a local-access
   installation or `examples/local.yaml` for a configured hostname. For full
   stack, merge the settings in `examples/full.yaml` into that file. It is a
   template with placeholders, not a ready-to-install configuration. Replace
   every placeholder and local-only image tag. Use supplied immutable digests
   where available; clear an inherited digest when intentionally selecting a tag.
5. Ensure the namespace exists and provision its registry pull Secret using the
   operator's registry tooling. Keep credentials out of Git, chat and logs.
   Enable `bootstrap.enabled` and set `bootstrap.adminEmail` for a new admin.
6. Build dependencies, lint and check every image for the target architecture:

   ```bash
   helm dependency build charts/docsie-platform --skip-refresh
   helm lint charts/docsie-platform -f /path/to/values.yaml
   python3 scripts/check-images.py charts/docsie-platform \
     --values /path/to/values.yaml --platform linux/amd64
   ```

   Change the platform only to match actual nodes and supplied images. These
   image checks use local registry credentials; success does not prove anonymous
   public access. Resolve missing images before installation. Rendered manifests
   can contain Secrets: inspect them privately, never paste them into reports.
7. Install using the explicit-target wrapper (the release name is `docsie`):

   ```bash
   bash scripts/install-kubernetes.sh /path/to/kubeconfig docsie /path/to/values.yaml
   ```

   Replace `docsie` with the intended namespace. The wrapper waits for Helm hooks
   and workloads; it does not provision a cluster or configure DNS.

## Models and transcription

Text/vision generation and audio transcription are separate services. Ollama
can supply generation models; configuring Ollama alone does not supply Whisper.
Use a model address reachable from pods, not the operator's localhost. Follow
`docs/LOCAL_MODELS.md` to configure organization AI routing as well as Helm.

For Dokuta, select an appropriate chat model and a vision-capable model using
`examples/full.yaml`. Confirm the model names exist on the chosen server.
Transcription routes in Dokuta include:

- Local Whisper through an OpenAI-compatible transcription server.
- OpenAI with an operator-supplied API key.
- Groq with an operator-supplied API key (Groq is distinct from Grok/xAI).

The current `whisper-openai-adapter` is a proxy, not a bundled Whisper inference
server or model. Until a release includes that backend and model weights, provide
an actual transcription endpoint; do not claim the chart installs Whisper itself.
The Dokuta configuration supports `LLM_TRANSCRIPTION_PROVIDER`,
`LLM_TRANSCRIPTION_BASE_URL`, `LLM_TRANSCRIPTION_MODEL` and
`LLM_TRANSCRIPTION_API_KEY`; its Groq route also supports `GROQ_API_KEY` and
`GROQ_WHISPER_MODEL`. Inspect the selected chart's Secret templates and image
version before applying provider overrides. Store real credentials in private
Secret configuration, not committed examples. For local-only deployments,
configure local-only routing and verify that cloud fallback is disabled.

After changing model settings supplied through Secrets, follow the restart
instructions in `docs/FULL_STACK_VALIDATION.md`: running processes may retain old
environment values. Drain active jobs before restarting workers.

## Verify the installation

Inspect pods, events and installation jobs using the same explicit kubeconfig
and namespace. Keep logs private and redact credentials before reporting errors.
Use the login and port-forward steps in `docs/LOCAL_MODELS.md` where applicable.
Retrieve generated administrator credentials only in the operator's private
terminal; do not include passwords or Secret contents in the handoff.

Verify the requested user workflows:

- Sign in, create a workspace and upload a document and image.
- Publish a page and open it, including its stored images, in a browser.
- For AI: run a grounded question with the selected model and inspect the answer.
- For video-to-docs: submit a short narrated sample, verify the transcript and
  inspect the saved generated document. A silent video does not test transcription.
- For an upgrade: verify existing content, login and persistent keys still work.

`installers/bundle/verify.sh` provides supplemental runtime checks. If used, pass
an explicit kubeconfig through its process environment (`KUBECONFIG=/path/...`).
Its model canary uses the literal model name `default` and runs from the operator's
machine; it is not sufficient for a pod-only endpoint or a different model name.
Use the actual configured model from the workload network for AI acceptance.

Report the source tag/commit, chart version, image references, target namespace,
completed checks and any remaining blockers. Separate ready pods, endpoint
connectivity and successful saved user output. Do not label untested workflows
as verified, or a connected installation as airgapped.
