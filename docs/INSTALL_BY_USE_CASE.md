# Install by use case

An operator should be able to say what they want to accomplish. The installation
agent should identify the required services, prepare configuration, install the
available components and verify the requested outcome. Use [AGENTS.md](../AGENTS.md)
for commands, cluster targeting and credential handling.

## 1. Select the outcome

Accept one or several use cases; combine their dependencies rather than creating
separate Docsie installations. Reuse information the operator has already supplied.

| Operator's request | Installation starting point | Additional requirements | Current distribution status |
| --- | --- | --- | --- |
| “Host our internal docs or customer help center” | Baseline KB | Hostname, storage, admin account | Released chart preview; image access required |
| “Use AI with our documentation” | KB plus model configuration | Chat, appropriate embeddings/retrieval, organization routing | Configuration guide available; validate chosen workflow |
| “Turn recordings into guides” | Development full profile | Dokuta, text/vision models, transcription for narration | Development rehearsal; complete image set and local Whisper bundle pending |
| “Compare versions of our documents” | Compatible application image plus required processors | Source-format support and AI configuration | No qualified comparison preset; verify the requested workflow |
| “Generate narration” | Compatible application with TTS provider | Hosted TTS or local Chatterbox backend/model | App integration exists; local TTS bundle pending |
| “Run interactive voice agents” | Voice services plus Docsie/Dokuta | LiveKit, agent worker, STT, LLM, TTS and session storage | Public packaging and local provider wiring pending |

### Additional application workflows

Use the [full product overview](../README.md#what-you-can-use-docsie-for) when the
operator requests a use case beyond the initial profiles. Do not restrict the
conversation to the first six rows above.

| Requested outcome | Configuration to inspect | Verify with the operator's sample |
| --- | --- | --- |
| Multilingual and versioned documentation | Application build, translation provider, languages, glossary and publishing | Publish two versions; translate an article and inspect the selected language |
| Migrate existing knowledge | Supported parser/import path, converters and any required OCR provider | Import representative source files; inspect structure, text and images |
| Employee/customer training with Docsie Learn | Learn-capable image and Reader assets, learner authentication, course assignments, Forms and email delivery | Publish a course; sign in as a learner; complete a lesson and quiz and inspect persisted progress |
| SCORM delivery | Course export implementation in selected build and target LMS | Export, import into the intended LMS and verify launch/progress behavior |
| Forms and surveys | Forms-capable image, publishing/access settings and submission storage | Publish a form, submit it and inspect the saved response |
| Policy review | Required analysis service, policy inputs, models and media dependencies | Analyze a known example and inspect findings against the supplied policy |
| Workflow automation | Recipes/tools present in image, worker queues, permissions and integration credentials | Run a small requested workflow and inspect its saved output and status |
| API/MCP access | Self-hosted route availability, authentication, scoped credentials and client configuration | Authenticate to this installation and retrieve an authorized source; do not substitute the SaaS endpoint |
| Meeting capture | Recording integration service, credentials and provider/network requirements | Capture an authorized test meeting and verify its recording is available for processing |

These capabilities do not have separately qualified public installation presets.
Resolve their image/dependency requirements explicitly; do not treat baseline
Helm success as proof of training, translation or integration readiness.

Ask for missing infrastructure details only after selecting the use case: cluster,
namespace, image access, storage, URL, hardware and local/hosted model preference.
Do not require the operator to understand Helm profiles to express their needs.

## 2. Produce the installation record

Before installing, summarize:

- Requested outcomes and the selected source tag or commit.
- Target cluster/context and namespace.
- Required services, image versions and provider/model choices.
- Which AI requests stay local and which use hosted services.
- Missing artifacts or configuration that prevent a requested feature from running.

Prepare the private values file, then follow the preflight and installation
commands in [AGENTS.md](../AGENTS.md). If a requested component is not packaged,
state that specific gap. Do not invent chart keys, substitute another provider
silently or claim that enabling a feature flag installs its backend.

## 3. Follow the applicable procedure

### Knowledge base

1. Configure the baseline install, registry access, persistent storage and admin.
2. Install using the explicit-kubeconfig wrapper.
3. Configure browser access and reachable object-storage URLs.
4. Sign in, upload content and publish a page; open it as a reader.

### AI assistance

1. Complete the KB procedure.
2. Follow [LOCAL_MODELS.md](LOCAL_MODELS.md) for endpoint networking and
   organization routing; use the selected hosted provider instead if requested.
3. Verify generation and retrieval separately, with the actual model names.
4. Ask a question answered by a known source document and inspect the answer and
   references. Also exercise writing assistance if that is a requested outcome.

The basic install already includes App Search and its operator prerequisite.
Complete [search verification and browser routing](SEARCH.md) before claiming
retrieval is ready; model connectivity alone does not prove search works.

### Video-to-docs

1. Read [FULL_STACK_VALIDATION.md](FULL_STACK_VALIDATION.md) and select a compatible
   development image set. Merge [examples/full.yaml](../examples/full.yaml) into
   the installation values, replacing all placeholders.
2. Configure text and vision models plus a real transcription endpoint for audio.
   Local Whisper, OpenAI and Groq are transcription choices in Dokuta; the existing
   Whisper adapter is a proxy and does not install a model.
3. Install and verify Dokuta bootstrap, API access and worker readiness.
4. Submit a short narrated walkthrough. Inspect the transcript and the saved
   guide, including screenshots. Record the selected models and result.

### Comparison

1. Confirm the selected application image supports the requested source formats
   and comparison workflow. Identify processors needed for those inputs.
2. Install/configure the dependencies and AI routing.
3. Compare two small representative inputs with known differences.
4. Inspect the saved comparison and source references against those differences.

### Voice and narration

For narration using an existing provider:

1. Confirm voice support in the selected application image.
2. Configure the provider endpoint, model, voice and credentials. Chatterbox uses
   `CHATTERBOX_TTS_BASE_URL`, `CHATTERBOX_TTS_MODEL`, `CHATTERBOX_TTS_VOICE`,
   `CHATTERBOX_TTS_ENDPOINT_PATH` and, when required, `CHATTERBOX_TTS_API_KEY`.
3. Enable the required API only after checking its authentication configuration.
4. Generate a short audio sample and listen to the saved result.

For local narration, use the optional [Chatterbox installation](TEXT_TO_SPEECH.md):
CPU/NVIDIA charts or a native Apple Silicon server, persistent model cache,
Dokuta wiring and a speech-generation check.

For live voice agents, the distribution additionally needs:

- LiveKit media server and Dokuta agent-worker image/chart integration.
- Signaling/TLS and browser-reachable media networking.
- Shared API credentials, authenticated session setup and persistence.
- Independently configured transcription, language generation and speech output.
- Local Whisper/Ollama/Chatterbox wiring in the worker; the existing worker does
  not currently select Chatterbox as a TTS provider.

These are packaging requirements, not available public installation commands.
Once implemented, acceptance must include a browser call that hears the user,
answers audibly, handles interruption and ends cleanly. A TTS audio-file check
alone does not qualify the voice-agent installation.

## 4. Hand off the result

Give the operator the application URL, private credential-retrieval instructions,
installed versions, selected use cases and actual verification results. Keep the
private values file available for upgrades. Identify incomplete requested features
explicitly. Link the backup/upgrade instructions in
[INSTALL_KUBERNETES.md](INSTALL_KUBERNETES.md).

Example request to give an agent:

> Read AGENTS.md and docs/INSTALL_BY_USE_CASE.md. Install Docsie for our internal
> knowledge base and video-to-docs on our existing Kubernetes cluster. Use our
> local Ollama server for generation and our transcription endpoint for audio.
> Check image access and report any missing components before installing.
