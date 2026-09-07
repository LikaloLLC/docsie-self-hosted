# System sizing and total cost of ownership

Planning guide checked **2026-09-07**. Choose the application footprint first, then decide where each AI service runs. Public images and charts are release artifacts, not a throughput certification. See [release status](RELEASE_STATUS.md) and [public image availability](PUBLIC_IMAGES.md).

## Application resources and AI resources are separate

| Deployment choice | Infrastructure you operate | Inference you pay for | Main constraint |
| --- | --- | --- | --- |
| Self-managed Docsie + hosted AI | Application workers, databases, search, object storage and backups | LLM/vision, embeddings, transcription and TTS APIs | Provider throughput, network access and data-handling requirements |
| Hybrid | Application stack plus selected local model services | Only the capabilities you keep hosted | Local model memory/concurrency plus provider limits |
| Fully local AI | Application stack plus text/vision, embedding, OCR, transcription and TTS runtimes required by the selected use cases | Hardware, power and operating time rather than per-request inference fees | Model capacity, queue latency, maintenance and quality |

Hosted transcription does not eliminate video decoding, frame extraction or document-rendering work in Docsie. Conversely, a CPU worker is not an inference GPU. Silent-video documentation primarily drives vision/LLM and CPU processing cost; do not budget Whisper as if every uploaded minute contained speech.

## Starting envelopes and evidence limits

| Reference | Application footprint | Model footprint | How to use it |
| --- | --- | --- | --- |
| Hobby/basic KB with external inference | Prior slim basic installation ran in an **8-GiB VM**, excluding App Search/AI acceptance; **4 CPU cores and 16 GiB RAM** is an initial test target with bundled App Search | Ollama/model memory is additional if on this same host | Neither a benchmarked minimum nor an enterprise requirement; see [search packaging](SEARCH.md) |
| Controlled full-profile pilot: **planning estimate** | Start evaluation around **16 vCPU, 64 GiB RAM, 400 GB SSD working capacity**; add retained media, indexes and backups separately | Hosted inference or a separate model host | Validate at bounded concurrency; not a measured minimum or user-count guarantee |
| Recorded workstation evaluation | Linux ARM64 VM with **16 vCPU, about 92 GiB RAM visible and a 400 GB virtual disk** | Native inference on a **256-GB unified-memory workstation** | Historical configuration, not proof that every model must fit concurrently or that this hardware is required |
| Enterprise private-cloud design reference | **72–84 vCPU / 336 GiB** across separate system, application, processing and data pools; managed database/cache services additional | Managed text/vision/embeddings plus optional private GPU services | A deliberately provisioned enterprise design, not a baseline for a small installation |

The current full-profile chart has approximately **11.35 vCPU / 25.31 GiB of declared steady-state requests**, counting Deployment/StatefulSet containers and the ECK search workloads. This is a reservation subtotal, not peak usage: ChromaDB has no request declaration, and Kubernetes, operators, init/migration jobs, processing bursts and model services add overhead. The pilot envelope above adds planning headroom; it still requires workload testing. The small 8-GiB emulation rehearsal is not a production requirement.

For CPU-only application hosts with all inference external, an inference GPU is unnecessary. For local inference, size the selected model runtime separately: resident weights + KV/context cache + vision/audio working memory + concurrency + runtime/OS headroom. Unified system memory and discrete GPU VRAM are different budgets. Quantization, context length, image resolution and simultaneously loaded models change the result. Measure these before buying hardware; a successful model load is not sufficient throughput evidence.

Choose storage from retention and working sets, not only the installer:

- Application/database/search storage and a separate backup destination.
- Retained source media + extracted frames/audio + generated artifacts + index growth.
- Temporary capacity for concurrent processing jobs, container layers and upgrades.
- Model downloads and caches, often duplicated across runtimes or hosts.

A 400-GB working disk is a planning allowance, not a promise that a large retained video collection will fit. Keep operational free-space headroom and test cleanup/retention.

## Size by workload, not registered users

Record concurrent active users; concurrent imports and videos; pages and source-video hours per month; resolution and sampling cadence; generated speech characters; simultaneous voice calls; retention; and required completion latency. A 100-user trial license does not imply 100 concurrent video jobs.

For each candidate configuration, test typical and large inputs at intended concurrency. Measure peak resident memory, CPU saturation, disk high-water mark, queue wait, processing time per source hour, inference tokens, retries and cold/warm model latency. For interactive voice, measure time to first audio and interruption behavior as well as throughput. Reserve rolling-update/failure headroom; a single machine is not high availability. Record output quality and human editing time alongside infrastructure metrics.

## Hosted transcription and speech price examples

USD list-price snapshots; taxes, commitments, promotions, minimum billing, quotas and provider changes can affect the bill. The following compares metering; it does not claim equal quality or tested compatibility for every model.

| Provider/model | Billing rate | Example |
| --- | --- | --- |
| Groq Whisper Large V3 Turbo | **$0.04 / audio hour** | 100 hours = **$4**; 1,000 hours = **$40** |
| Groq Whisper Large V3 | **$0.111 / audio hour** | 100 hours = **$11.10**; 1,000 hours = **$111** |
| OpenAI GPT-4o mini transcribe | Estimated **$0.003 / minute** | 100 hours ≈ **$18**; validate model-specific timestamps/response format |
| ElevenLabs Flash/Turbo TTS | **$0.05 / 1,000 characters** | 1 million characters = **$50** |
| ElevenLabs v2/v3 TTS | **$0.10 / 1,000 characters** | 1 million characters = **$100** |
| Groq Orpheus V1 English TTS | **$22 / million characters**, listed as preview | Pricing comparison only; no dedicated Dokuta Groq-TTS integration verified |

Sources: [Groq model prices](https://console.groq.com/docs/models), [OpenAI pricing](https://developers.openai.com/api/docs/pricing), [ElevenLabs API prices](https://elevenlabs.io/pricing/api). ElevenLabs displayed a promotional banner when checked; confirm the applicable account rate and its duration before purchasing.

Groq bills at least **10 seconds per request**: total billed hours = `sum(max(chunk_seconds, 10)) / 3600`. Include overlapping chunks, retries and any rerun/fallback calls. This can differ materially from the original source duration. See [Groq transcription documentation](https://console.groq.com/docs/speech-to-text).

TTS character counts do not map to a universal number of output minutes. For live voice, add LLM tokens, incoming transcription, session infrastructure and TURN/egress or meeting-provider charges as applicable. Do not add both an all-in voice-agent fee and the same component costs twice.

## Configuration and compatibility

The released Dokuta source includes Groq transcription and OpenAI-compatible/local transcription routes. For an explicitly Groq-only transcription route, inject these settings through your deployment's Secret/environment mechanism:

```dotenv
LLM_TRANSCRIPTION_PROVIDER=groq
GROQ_WHISPER_MODEL=whisper-large-v3-turbo
DOKUTA_TRANSCRIPTION_PROVIDER_ORDER=groq
DOKUTA_TRANSCRIPTION_LOCAL_ONLY=false
# Supply GROQ_API_KEY securely; never commit the credential.
```

Set an explicit provider order: the default Groq route can fall back to the injected OpenAI-compatible client, which changes both cost and where data is sent. For local-only transcription use `DOKUTA_TRANSCRIPTION_LOCAL_ONLY=true`, configure the local endpoint and model, and verify the selected server's API. Native whisper.cpp `/inference` and OpenAI-compatible `/v1/audio/transcriptions` are different contracts; an adapter may be needed. Ollama is not a substitute for a transcription server.

Dokuta has OpenAI, ElevenLabs and Chatterbox speech-generation routes in source. Runtime availability and voice API enablement depend on your deployment. Chatterbox and standalone Whisper model/server packaging remain separate from the four public Dokuta images. A provider-compatible endpoint or price listing is not an end-to-end integration test. Private-network deployments need explicitly approved egress or private service endpoints for hosted AI.

## Monthly TCO worksheet

```text
monthly TCO = Docsie license/support
            + application compute or amortized application hardware
            + database/search/storage/backups
            + networking, observability and security services
            + hosted text/vision/embedding inference
            + billed transcription and generated speech
            + local model hardware or GPU rental and its operating costs
            + administration, upgrades, incident response and output review
```

Use either a rental bill or hardware amortization for the same equipment, not both. For owned equipment, include acquisition/setup divided by the chosen useful life, maintenance, power/cooling and replacement planning. Example power calculation: `average watts / 1000 × operating hours × price per kWh`; use measured duty-cycle power. Existing equipment has an incremental cash cost and an allocated ownership cost—report both.

For cloud estimates include node runtime, control plane, managed DB/cache replicas, disks/IOPS, snapshots, object storage, load balancers, NAT **or** private endpoints as actually designed, cross-zone traffic, egress, logs, KMS/secrets, backup retention and support. Use region-specific quotes; this guide does not price a customer's AWS bill.

### Worked example: application self-hosted, inference hosted

These are **illustrative budget inputs**, not a server quote, customer bill, or Docsie license price. Workload: 100 billed audio hours and 1 million Flash/Turbo TTS characters per month.

| Cost item | Assumed monthly USD |
| --- | ---: |
| Application compute | 300 |
| Storage, backups and networking | 80 |
| Text/vision/embedding inference allowance | 100 |
| Groq Turbo transcription | 4 |
| ElevenLabs Flash/Turbo TTS | 50 |
| Operations: 2 hours × $75 | 150 |
| **Known subtotal** | **684** |
| Docsie license/support and any unlisted services | **Add quoted amounts** |

The $100 generative-inference allowance is a placeholder, not a measured workload. Replace it with actual input/output/image/embedding usage and the chosen providers' rates. At 1,000 billed audio hours with other inputs unchanged, the known subtotal is **$720**. If the same provider bills a minimum subscription, compute subscription plus overage rather than adding the full list-price usage to already included units.

### Local inference comparison

Evaluate local AI using the **same accepted outputs, monthly volume and latency target**. Add amortization or rental, power if not included, runtime operations and redundancy; subtract only the API charges actually eliminated. Hosting only Whisper locally does not remove text, vision or TTS API charges.

For example, allocating **$300/month** to a dedicated local transcription service would require **7,500 billed audio hours/month** merely to equal Groq Turbo's $0.04/hour API line item, before local operating costs. That would also require over **10× realtime sustained throughput** over a 730-hour month; this is break-even arithmetic, not a demonstrated machine capability. Shared idle hardware, data restrictions, quality and latency may change the choice.

## Recommended evaluation path

If external inference is permitted, first validate the application with hosted text/vision and transcription, then choose local services based on measured workload or privacy needs. If inference must remain local, qualify one model set and a bounded job concurrency on the intended hardware. Measure a representative workflow before promising capacity or publishing a user-count sizing tier.
