# What can you use Docsie for?

Docsie helps teams create, organize, publish and use their documentation. A
self-hosted installation runs the application and its data services on your own
infrastructure. You can connect local AI services or choose hosted providers.
Self-hosting the application does not automatically make every AI call local.

Start with the outcome you want. Your installation agent can translate that
outcome into services and configuration using the
[installation procedures](INSTALL_BY_USE_CASE.md).

## A knowledge base for your team or customers

Maintain product documentation, internal policies, standard operating procedures
and onboarding guides. Organize information in a shared workspace and publish
pages that readers can access. For example, turn scattered support instructions
into a maintained customer help center.

**Installation:** start with the baseline KB profile. It includes the application,
workers, databases, object storage and document/image converters. AI inference
is not required for the basic knowledge-base installation.

## AI assistance over your documentation

Use AI to help write and rewrite documentation and answer questions grounded in
your knowledge base. For example, let a support team find an answer with its
supporting documentation, then improve the source article.

**Installation:** add model access and organization AI routing. Retrieval and
embeddings need compatible configuration as well as a chat model. See the
[Ollama guide](LOCAL_MODELS.md). The chart's `kbAi` switch enables a particular
App Search dependency; it is not a universal switch for every AI feature.

## Documentation from videos and existing material

Use Dokuta's processing pipeline to turn a recorded walkthrough into a draft
step-by-step guide. Narrated recordings require transcription; visual analysis
requires a vision-capable model. Review the resulting text and screenshots before
publishing. This can help document software workflows and repeatable procedures.

**Installation:** the development full-stack profile adds Dokuta and supporting
services. Supply text/vision models and a real transcription backend. A local
Whisper server/model is not bundled yet. See
[full-stack validation](FULL_STACK_VALIDATION.md) for the current image and workflow
boundaries.

## Review changes between source materials

Use document comparison to investigate changes between versions and review the
result with its source references. For example, compare an updated procedure
with the earlier version before updating your knowledge base.

**Installation:** verify that the supplied application image supports the required
comparison workflow and source formats. Configure its model and processing
dependencies. The public chart does not currently provide a separately qualified
comparison preset; choose and test the actual inputs you intend to use.

## Spoken content and interactive voice agents

Generate spoken narration from text, or use an interactive voice agent to conduct
a conversation. These are separate capabilities: producing an audio file does
not establish a working live call.

Docsie/Dokuta source supports Chatterbox, OpenAI and ElevenLabs for speech
synthesis. A live voice agent also needs audio transport, an agent worker,
transcription, a language model and session configuration.

**Installation status:** local Chatterbox and LiveKit are not currently packaged
in this public distribution. Dokuta's voice APIs are disabled by default. The
[voice procedure](INSTALL_BY_USE_CASE.md#voice-and-narration) describes the missing
pieces; do not present voice as an available one-command installation yet.

## Choose where AI runs

- **Local:** use inference services on your own infrastructure; verify all model
  routes, fallback behavior and model downloads before calling the setup offline.
- **Hosted:** supply credentials for the selected providers. Requests to those
  providers leave your infrastructure.
- **Mixed:** choose independently for text, vision, embeddings, transcription and
  speech. For example, local generation with hosted transcription.

The current release is a Kubernetes chart preview with supplied image access,
not a complete public image bundle. Product capabilities above describe intended
uses and available application integrations; the selected release, models and
configuration determine what is installable and verified. Read
[release status](RELEASE_STATUS.md) before choosing a deployment.
