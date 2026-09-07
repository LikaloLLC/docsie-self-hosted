# Docsie Self-Hosted

[Public Dokuta images (AMD64 + ARM64)](docs/PUBLIC_IMAGES.md) — UI, API, Celery and LiveKit preview images, with pull commands and Helm overrides.

**Documentation · AI knowledge workflows · Training — on your infrastructure**

[Website](https://www.docsie.io/) · [Install](#start-here) · [Documentation](docs/README.md) · [Agent setup](AGENTS.md) · [Releases](https://github.com/LikaloLLC/docsie-self-hosted/releases) · [Support](#support)

[![Chart validation](https://github.com/LikaloLLC/docsie-self-hosted/actions/workflows/validate.yml/badge.svg)](https://github.com/LikaloLLC/docsie-self-hosted/actions/workflows/validate.yml)

Docsie is a platform for creating, managing, translating and publishing knowledge,
turning source material into documentation, comparing content, delivering training,
and automating documentation workflows. Reuse the same knowledge across support,
localization, courses, assessments and presentations, including paid learning
content through connected commerce services. Deploy the proprietary application on
Kubernetes you control, with your choice of local or hosted AI services.

![Docsie documentation assistant with source conversion, video comparison and research workflows](docs/assets/screenshots/documentation-assistant.png)

> **Kubernetes preview:** charts and deployment tooling are public; compatible
> application images currently require [access from Docsie](https://www.docsie.io/demo/).
> See [release status](docs/RELEASE_STATUS.md) for what is included and tested.

**Explore:** [Use cases](#what-you-can-use-docsie-for) · [Screenshots](#screenshots) ·
[Availability](#which-parts-can-i-install-today) · [Install](#start-here) ·
[License](#license-and-access) · [Roadmap](#roadmap)

## Who it is for

- Technical writers, product and engineering teams maintaining manuals and specifications.
- Support, knowledge-management and enablement teams serving employees and customers.
- Course creators, educators, consultants and training businesses building learning products.
- Developers, DevOps teams and enterprise IT running knowledge workflows on their own infrastructure.
- Individual self-hosters and homelab users; personal non-commercial use is free for one active application user.

## What you can use Docsie for

Docsie connects documentation, source analysis, training and the workflows that
keep organizational knowledge useful. Teams can work from existing documents,
recordings and websites, develop that material into maintained content, publish
it to the right audience, and use it for answers, learning and review.

### Product documentation, help centers and internal knowledge bases

Create product manuals, implementation guides, support articles, employee
handbooks, runbooks and standard operating procedures. Organize them into
workspaces, shelves, books and articles, then publish public documentation or
controlled-access portals for employees, customers and partners. Custom domains
and branded portals let each audience access the documentation in its own context.

**Example:** maintain a customer help center and a private engineering runbook
from the same documentation platform, with different access rules.

### Multilingual documentation and product versions

Maintain documentation for different product releases and languages. Translate
content, refresh translations when the source changes, and maintain glossaries
and style guides so teams use consistent terminology.

**Example:** publish installation instructions for two supported product versions
in several languages without treating every copy as an unrelated document.

### Import, consolidate and maintain existing knowledge

Bring existing PDFs, Word documents, Markdown, presentations, images, websites
and Confluence content into an editable knowledge base. Select the appropriate
importers, converters and OCR or vision services for each source format. Use AI-assisted writing and rewriting to organize raw
material into articles, manuals and procedures. Preserve the source material for
review and update the resulting documentation as requirements change.

**Example:** consolidate a folder of legacy manuals into structured product
documentation that your team can maintain and publish.

### Improve documentation using your existing knowledge

Use related manuals, articles and source material to expand an incomplete guide,
clarify a procedure or improve an answer. Review the proposed additions against
their sources before updating maintained documentation.

**Example:** enrich an installation guide with troubleshooting information from
support articles, then reuse the approved guide in onboarding and training.

### Video-to-docs and operational knowledge capture

Turn recorded demonstrations, software walkthroughs and training videos into
step-by-step guides with screenshots. Dokuta supplies the video-processing
pipeline, with vision analysis and transcription for narrated material.
Meeting-recording integrations can also capture material for follow-up processing.

**Example:** record an experienced operator demonstrating a procedure, generate a
draft guide, review its steps and screenshots, and publish it for the next shift.

### AI search, questions and documentation agents

Ask questions over documentation, retrieve supporting sources and use agents to
create, edit, organize and publish content. Scope the work to the relevant
workspace or documentation rather than treating all company information as one
undifferentiated collection.

**Example:** help a support engineer answer a configuration question using the
product documentation, then improve the article that was missing an explanation.

### Content comparison, technical research and change analysis

Compare technical documentation sets, product manuals, specifications, datasheets,
images, videos and website-derived material. Investigate differences between
versions, products and procedures, including gaps, missing information and
conflicting content. Use structured findings and source references to review the
evidence and save comparison results as documentation. For large collections,
validate source coverage, processing capacity and the selected models with
representative inputs; this preview does not establish a document-size limit or
throughput guarantee.

**Example:** compare two vendors' technical manuals against the requirements your
engineering team cares about, or inspect how a recorded workflow changed between
software releases. The useful outcome is an explained difference with evidence,
not simply a list of changed words.

### Docsie Learn: onboarding, training and certification

Build learning courses from documentation, arrange modules and learning paths,
assign them to an audience and track learner progress. Combine reading material
with quizzes, assessments and certification workflows. Course export tooling also
includes SCORM; compatibility with the intended LMS must be checked for the
selected application build.

**Example:** turn your operating procedures into employee onboarding with ordered
lessons and knowledge checks, or deliver product training to customers and partners.

### Paid courses and learning products

Creators, educators, consultants and training businesses can turn videos and
documents into structured courses and sell learner access through connected
commerce/payment workflows. Docsie connects purchase entitlements to course or
portal access; the chosen payment service and its integration need configuration.
Commercial use requires the appropriate Docsie license.

**Example:** turn a workshop recording and its reference manual into a paid course,
then grant buyers access to the lessons and assessments. Verify purchase, learner
access and access revocation with the selected integration before launch.

### Presentations and training decks

Generate PowerPoint presentations and training decks from existing knowledge.
Reuse approved documentation to prepare product briefings, onboarding slides and
training material, then review the exported deck before sharing it.

**Example:** turn a maintained product guide into a customer training deck, keeping
its explanations aligned with the documentation used by the support team.

### Forms, quizzes, surveys and assessments

Create and publish forms alongside your knowledge content, collect submissions,
and use quizzes or assessments to check understanding. Forms can support training
as well as operational information collection.

**Example:** attach a knowledge check to a procedure or collect structured feedback
from readers about an onboarding guide.

### Policy and compliance review

Analyze text, audio or video against supplied policies and review the resulting
findings. Combine policy documentation, operational evidence and training so the
people reviewing a procedure can trace the material behind a finding.

**Example:** review a recorded procedure against your organization's documented
requirements and use the findings to guide a human review and documentation update.
This is a review workflow; generated findings do not confer regulatory certification.

### Documentation workflows and automation

Coordinate work with workflow boards, steps and statuses. Run reusable workflow
recipes for repeated documentation operations and use agents to perform scoped
actions. API and MCP integrations let other applications and AI clients search
knowledge and participate in content-generation and publishing workflows.

**Example:** repeat an import, review and publishing process for a series of
manuals, or connect an AI client to your documentation through an authenticated
self-hosted endpoint.

### Offline and air-gapped reader delivery

Build self-contained documentation-reader packages for environments where readers
cannot reach the hosted portal. Ship product documentation with a software release
or make a knowledge portal available on a disconnected network. Verify the built
package, assets and offline search in the intended environment.

**Example:** deliver a manual alongside an application installed at a restricted
site. Reader delivery has its own build/runtime requirements; a complete offline
installer for the Docsie authoring platform is not released in this repository.

### Narration and voice agents

Generate speech from text with Chatterbox or hosted TTS providers. Voice-agent
and presentation integrations extend this into interactive spoken experiences;
these require the corresponding media services and agent workers in addition to
the knowledge base and models.

**Example:** produce spoken training material or configure a conversational agent
for a guided session. Audio-file generation and a live voice conversation have
different deployment requirements.

## Screenshots

Explore the authoring workspace, published knowledge base and training dashboard.
These product screenshots illustrate the application; consult the availability
table below for the components included in the self-hosted preview.

<details>
<summary><strong>Docsie Learn — programs, learners, quizzes and certificates</strong></summary>

![Docsie Learn training dashboard](docs/assets/screenshots/training-programs.png)

</details>

<details>
<summary><strong>Workspace — organize content, assignments and publishing</strong></summary>

![Docsie authoring workspace and task activity](docs/assets/screenshots/workspace.png)

</details>

<details>
<summary><strong>Knowledge base — branded documentation and AI assistance</strong></summary>

![Published Docsie knowledge base](docs/assets/screenshots/knowledge-base.png)

</details>

## Which parts can I install today?

The use cases above describe Docsie's application capabilities. This repository
packages them for self-hosting in stages; a feature present in application source
is not automatically included or verified in the published image/chart release.

| Area | Self-hosted distribution status |
| --- | --- |
| Core knowledge base and baseline services | Published Kubernetes preview; compatible registry image access required |
| Local or hosted AI | Configuration procedures available; verify the selected models and organization routing |
| Dokuta/video processing | Public AMD64/ARM64 UI, API and Celery images available; full workflow qualification and remaining platform dependencies still apply |
| Local transcription | External Whisper-compatible endpoint supported; server/model bundle pending |
| Local TTS | Optional Chatterbox chart, native CPU installer and Dokuta wiring available; native CPU speech verified. Linux container and GPU inference remain unverified. See [speech setup](docs/TEXT_TO_SPEECH.md) |
| Interactive voice | Public LiveKit worker image available; complete media-service/provider wiring and browser-call qualification still required |
| Learn, Forms, multilingual workflows, comparison, policy review and automation | Application capabilities; verify image version, feature configuration and dependencies for the chosen workflow; no separately qualified public presets yet |
| Paid learning content | Commerce/entitlement application integration; configure payment services and verify purchase, access and revocation. No qualified public commerce preset yet |
| PowerPoint generation and knowledge enrichment | Application workflows; verify image support, processors, models and saved output. No separately qualified public presets yet |
| Offline reader delivery | Application build workflow; verify the exported reader in a disconnected environment. Separate from the unreleased full-platform offline bundle |
| Meeting capture and external integrations | Require their own services, credentials and network access; not bundled by the baseline chart |
| AWS one-click and complete offline bundle | Not released |

Choose local, hosted or mixed providers independently for text, vision,
embeddings, transcription and speech. For a local-only deployment, verify the
entire route, including fallbacks, downloaded models and browser assets.

## Tell your installation agent the outcome you want

You do not need to choose a Helm profile first. For example:

> Install Docsie for internal SOPs, employee training and quizzes. Use our existing
> Kubernetes cluster and local models. Read AGENTS.md, identify the required image
> versions and components, prepare the configuration, and verify publishing plus
> a learner completing a lesson and quiz. Report anything not packaged yet.

Or:

> We want to turn recorded walkthroughs into guides and compare new versions.
> Use our Ollama server and local transcription endpoint. Check the required
> images and install the available services into our chosen namespace.

[AGENTS.md](AGENTS.md) tells agents how to select a target, prepare configuration,
install and verify the result. [Use-case procedures](docs/INSTALL_BY_USE_CASE.md)
map outcomes to dependencies and acceptance checks. Multiple use cases should
share one Docsie installation where appropriate.

## Search is included

Chart `0.2.0-preview.5` includes App Search in the basic KB install, with a vendored
Elastic operator, automatic credentials and an indexing/search installation test.
[Search setup and browser access](docs/SEARCH.md).

## Optional local speech

Add [Chatterbox text-to-speech](docs/TEXT_TO_SPEECH.md) for narration: optional
CPU/NVIDIA model-server charts, a native Apple Silicon installer, persistent
model storage and Dokuta configuration. It is disabled by default.

## System requirements and costs

Size the application separately from the model runtimes. Read the
[sizing and TCO guide](docs/SIZING_AND_COST.md) for deployment reference footprints,
hosted versus local AI, Groq transcription, TTS pricing and a monthly cost worksheet.

| Evaluation setup | Starting point |
| --- | --- |
| Hobby/basic KB | Prior slim installation ran in an 8-GiB VM **without App Search validation**; target 16 GiB initially with bundled App Search, pending minimum-footprint testing. Ollama model memory is additional. |
| Full application profile with external inference | **Planning estimate:** 16 vCPU, 64 GiB RAM and 400 GB SSD working capacity; add retained data and backups |
| Local AI | Add a separately sized model host; model memory, context and concurrency determine capacity |
| Kubernetes | Reachable cluster, persistent storage, Helm 3, kubectl, configured hostname/storage and access to every required image |

These are evaluation planning numbers, **not benchmarked minimums or a user-count
capacity guarantee**. The full chart declares about 11.35 vCPU / 25.31 GiB before
unreserved services, Kubernetes overhead, bursts and model runtimes. The complete
stack still has image-access requirements described below.

## Start here

Installing with an AI coding agent? Point it at [AGENTS.md](AGENTS.md) for the
installation workflow, configuration choices and verification steps.

1. [Request image access](https://www.docsie.io/demo/) for a personal installation
   or business evaluation.
2. Follow [Kubernetes installation](docs/INSTALL_KUBERNETES.md).
3. Follow [Install Docsie with Ollama](docs/LOCAL_MODELS.md) for the complete walkthrough, or adapt it to another local model server.
4. Run the [acceptance checklist](docs/ACCEPTANCE.md) for your workflows.

```bash
git clone https://github.com/LikaloLLC/docsie-self-hosted.git
cd docsie-self-hosted
git checkout v0.2.0-preview.5
# Configure image access, hostname, TLS, storage and an administrator first.
bash scripts/install-kubernetes.sh /path/to/kubeconfig docsie /path/to/values.yaml
```

The baseline chart includes PostgreSQL, Redis, MinIO, Elasticsearch, App Search,
web/worker processes and document/image converters. The source installer also
provisions the packaged Elastic operator and runs an indexing/search check. Target production architecture is Linux
x86_64; the documented Mac rehearsal uses emulation and locally prepared images.

## Downloads

[Releases](https://github.com/LikaloLLC/docsie-self-hosted/releases) provide the
application chart, platform chart, Helm repository index and SHA-256 checksums.
The platform package bundles its application dependencies; the Elastic operator
and CRDs are supplied as a separate `eck-operator-2.16.1.tgz` prerequisite. The
source installer above handles that prerequisite automatically. For direct `.tgz`
installation, follow [the search installation guide](docs/SEARCH.md) before
installing `docsie-platform-0.2.0-preview.5.tgz`.

```bash
sha256sum -c SHA256SUMS
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

## Unreleased full-stack work

The development chart includes Dokuta bootstrap and configuration repairs from
a local full-stack rehearsal. See [full-stack validation](docs/FULL_STACK_VALIDATION.md)
for what passed and the remaining image, audio and licensing gates. This work
does not change the verification scope of the published release above.

## Documentation

Start at the [documentation index](docs/README.md) for installation, model
configuration, use-case procedures, troubleshooting and validation reports.

## Support

- **Image access, licensing and deployment assistance:** [contact Docsie](https://www.docsie.io/demo/).
- **Chart bugs or documentation fixes:** [open an issue](https://github.com/LikaloLLC/docsie-self-hosted/issues).
  Include chart/image versions, Kubernetes version, architecture and redacted error output.
- **Installation problems:** follow [troubleshooting](docs/TROUBLESHOOTING.md).

For changes to this distribution, see [CONTRIBUTING.md](CONTRIBUTING.md).
