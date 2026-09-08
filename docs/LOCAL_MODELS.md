# Install Docsie with Ollama

This guide documents configuration; full Docsie AI workflows have not been
validated with Ollama in this release. Endpoint connectivity alone does not
prove chat, tools, search, OCR or video-to-docs acceptance.

Docsie runs on Kubernetes; Ollama runs the language model that Docsie calls.
This walkthrough uses an existing Linux Kubernetes cluster and an Ollama server
on the same private network. Ollama may run on a different machine.

## 1. Before you start

You need:

- Kubernetes with a working default persistent StorageClass, Helm 3, kubectl,
  and an explicit kubeconfig. Cluster creation is outside this walkthrough.
- Compatible Docsie application, image-processor and PDF-converter image
  references plus registry access from [Docsie](https://www.docsie.io/demo/).
  Public chart downloads do not include these images; default converter tags
  are not a complete publicly pullable distribution.
- An Ollama machine with enough RAM/VRAM and disk for your chosen model.
  Docsie and model resources are separate; no universal minimum is qualified
  by this preview. Production Docsie images target Linux x86_64.
- A private address reachable from the Kubernetes pods on port 11434.

The instructions use `/path/to/kubeconfig`, namespace `docsie`, model
`YOUR_MODEL`, and `MODEL_HOST`. Replace these placeholders consistently.
Self-hosted use is free for up to 10 workspace users and 25 individual named portal
users, with unlimited public knowledge-base views. Commercial use is included,
with no time limit. Exceeding either user allowance requires a paid commercial license. See [licensing](LICENSING.md).

## 2. Install Ollama and load a model

Install Ollama using the [official quickstart](https://docs.ollama.com/quickstart)
for your operating system, then confirm `ollama --version` works. Select a
locally downloaded model; a cloud model does not keep inference on your server.

### Model server and network

Pull your chosen model on the model host. Choose its size and context to fit
your hardware. For a dedicated server where Ollama is not already running:

```bash
ollama pull YOUR_MODEL
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

For an existing service, set its service environment and restart it instead.
Binding beyond localhost exposes the server to its network. Restrict access to
Docsie's private network; use an authenticated TLS proxy on untrusted networks.
Ollama provides an OpenAI-compatible API under `/v1`.
See [API compatibility](https://docs.ollama.com/api/openai-compatibility) and
[Ollama networking](https://docs.ollama.com/faq).

Inside a pod, `localhost` means that pod. Use reachable private DNS/IP or a
Kubernetes service, such as `ollama.models.svc.cluster.local`. Host access via
`host.docker.internal` depends on your cluster's DNS/network; do not assume it
works through a nested k3s container.

## 3. Prepare the Docsie installation

Fetch the released chart source:

```bash
git clone https://github.com/LikaloLLC/docsie-self-hosted.git
cd docsie-self-hosted
git checkout v0.2.0-preview.2
helm dependency build charts/docsie-platform --skip-refresh
kubectl --kubeconfig /path/to/kubeconfig get storageclass
kubectl --kubeconfig /path/to/kubeconfig create namespace docsie
```

If the namespace exists, reuse it. Create a `docsie-registry` image-pull Secret
there using the registry credentials provided by Docsie. Keep those credentials
out of this repository and shared command transcripts.

Save `values.yaml` with the image references supplied to you. Clear the inherited
application digest when selecting a supplied tag, or replace it with the supplied
matching digest. This example exposes the UI only through a local port-forward.

```yaml
global:
  hostname: localhost
  scheme: http
  imagePullSecret: docsie-registry
  imagePullSecrets:
    - name: docsie-registry
bootstrap:
  enabled: true
  adminEmail: admin@example.com
docsie:
  image:
    repository: YOUR_DOCSIE_IMAGE_REPOSITORY
    tag: YOUR_DOCSIE_IMAGE_TAG
    digest: ""
  ingress:
    enabled: false
  plainEnv:
    APP_BASE_URL: http://127.0.0.1:58081
    BASE_URL: http://127.0.0.1:58081
    DOCSIE_BASE_URL: http://127.0.0.1:58081
    CSRF_TRUSTED_ORIGINS: http://127.0.0.1:58081
    DJANGO_AWS_S3_PUBLIC_ENDPOINT_URL: http://127.0.0.1:59000
    MINIO_PUBLIC_ENDPOINT_URL: http://127.0.0.1:59000
image-processor:
  image:
    repository: YOUR_IMAGE_PROCESSOR_REPOSITORY
    tag: YOUR_IMAGE_PROCESSOR_TAG
pdf-converter:
  image:
    repository: YOUR_PDF_CONVERTER_REPOSITORY
    tag: YOUR_PDF_CONVERTER_TAG
```

Replace the administrator email as well. These localhost URLs are for access
from the operator's machine. For shared access, configure your real hostname,
TLS/ingress and externally reachable object-storage URLs instead. See
[Kubernetes installation](INSTALL_KUBERNETES.md).

## 4. Connect Docsie to Ollama

Create an override file `models.yaml`. Replace the example service DNS with
`MODEL_HOST` if Ollama runs outside Kubernetes:

```yaml
global:
  modelEndpoint: http://ollama.models.svc.cluster.local:11434/v1
docsie:
  plainEnv:
    V31_REWRITE_MODEL: YOUR_MODEL
    # Ollama ignores this placeholder; it is not a real credential.
    DOCSIE_LOCAL_MODEL_API_KEY: ollama
```

The chart exports `OPENAI_API_BASE` and `OLLAMA_API_BASE`; the rewrite path
prioritizes `OPENAI_API_BASE`, which includes `/v1`. This alone does not configure
organization AI routing. Apply the override with your installation values:

```bash
helm upgrade --install docsie ./charts/docsie-platform \
  --kubeconfig /path/to/kubeconfig -n docsie \
  -f /path/to/values.yaml -f models.yaml --wait --timeout 20m
```

For authenticated servers, put credentials in an operator-managed Kubernetes
Secret through `docsie.workload.extraEnvFrom`, not Git or `plainEnv`. Set
`OPENAI_API_KEY` for the rewrite path; reference the appropriate Secret-provided
environment variable in organization configuration below.

## 5. Open Docsie and select your organization

After Helm completes, keep these commands running in separate terminals:

```bash
kubectl --kubeconfig /path/to/kubeconfig -n docsie port-forward svc/docsie-web 58081:80
```

```bash
kubectl --kubeconfig /path/to/kubeconfig -n docsie port-forward svc/minio 59000:9000
```

Open `http://127.0.0.1:58081/onboarding/v3/login/`. Sign in with your bootstrap
email and the generated password. Retrieve it in a private terminal:

```bash
kubectl --kubeconfig /path/to/kubeconfig -n docsie get secret docsie-bootstrap-admin \
  -o jsonpath='{.data.password}' | base64 --decode
```

This command displays the password; do not include its output in support logs.
Helm upgrades preserve it and do not reset an existing administrator password.

Complete organization setup in Docsie. If your supplied image needs assisted
organization setup, finish that with Docsie before continuing. List organization
IDs from the running application to select the exact organization you will edit:

```bash
kubectl --kubeconfig /path/to/kubeconfig -n docsie exec deployment/docsie-web -- \
  python manage.py shell -c 'from docsie.api.models import Organization; print(list(Organization.objects.values_list("pk", "name")))'
```

## 6. Configure organization routing

After creating your organization, merge these keys into its `config` JSON using
the command below. Preserve existing unrelated configuration. Use
the exact model name returned by the server. This example configures basic chat. Save it as `routing.json`:

```json
{
  "ai_endpoints": {
    "default": {
      "api_base": "http://ollama.models.svc.cluster.local:11434/v1",
      "api_key_env": "DOCSIE_LOCAL_MODEL_API_KEY"
    }
  },
  "ai_custom_models": {
    "YOUR_MODEL": {
      "provider": "openai",
      "capabilities": ["chat", "streaming"],
      "context_window": 8192,
      "max_output": 2048
    }
  },
  "ai_action_models": {
    "chat": "YOUR_MODEL",
    "chat_fast": "YOUR_MODEL",
    "portal_chat": "YOUR_MODEL"
  }
}
```

Apply the JSON to the exact organization ID you selected. This merges the three
AI configuration maps and preserves unrelated organization settings. Back up your
existing organization configuration before replacing an existing AI route.

```bash
kubectl --kubeconfig /path/to/kubeconfig -n docsie exec -i deployment/docsie-web -- \
  env DOCSIE_ORG_ID=YOUR_ORGANIZATION_ID python manage.py shell -c '
import json, os, sys
from django.db import transaction
from docsie.api.models import Organization
patch = json.load(sys.stdin)
allowed = {"ai_endpoints", "ai_custom_models", "ai_action_models"}
assert set(patch) == allowed and all(isinstance(v, dict) for v in patch.values())
with transaction.atomic():
    org = Organization.objects.select_for_update().get(pk=os.environ["DOCSIE_ORG_ID"])
    config = dict(org.config or {})
    for key, entries in patch.items():
        config[key] = {**config.get(key, {}), **entries}
    org.config = config
    org.save(update_fields=["config"])
print("Organization AI configuration updated")
' < routing.json
```

The context/output sizes are placeholders: match the loaded model's actual
server configuration. Without model overrides, Docsie can request a catalog
model your server does not have. Existing provider-specific `ai_endpoints`
entries take precedence over `default`; review them before assuming all traffic
routes locally. Do not declare tools, thinking or vision capabilities unless
they work with that model/server. Configure additional actions after testing.

Embeddings, transcription and OCR may need separate models/services. A chat
endpoint does not automatically provide them. Use network egress controls when
local-only inference is required; these settings are not an egress policy.

## 7. Verify connectivity and a real workflow

This command sends a synthetic prompt from the web pod and does not print keys:

```bash
kubectl --kubeconfig /path/to/kubeconfig -n docsie exec -i deployment/docsie-web -- python - <<'PY'
import json, os, urllib.request
base = os.environ['OPENAI_API_BASE'].rstrip('/')
model = os.environ['V31_REWRITE_MODEL']
key = os.environ.get('OPENAI_API_KEY') or os.environ.get('DOCSIE_LOCAL_MODEL_API_KEY', 'ollama')
request = urllib.request.Request(
    base + '/chat/completions',
    data=json.dumps({'model': model, 'messages': [{'role': 'user', 'content': 'Reply with OK'}], 'max_tokens': 32}).encode(),
    headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + key},
)
with urllib.request.urlopen(request, timeout=120) as response:
    assert json.load(response).get('choices'), 'No completion choices returned'
    print('Model endpoint returned a completion successfully')
PY
```

Then run an actual Docsie chat in the configured organization, confirm the
request reaches your server logs, and test worker-driven rewrites separately.
Validate every workflow you intend to use and record model/version/context.

## 8. Troubleshooting and other servers

Other OpenAI-compatible servers use the same `/v1` routing with their exact
served model names. Authentication, tools, streaming and structured output vary;
no particular server/model combination is certified by this guide.

- Connection refused/timeouts: check bind address, DNS, routing and firewall.
- Model not found: check model tag and organization action overrides.
- HTTP 401: check Secret environment references and proxy credentials.
- Capability errors: verify the model supports the requested action.
- Chat works but indexing fails: check embeddings and search configuration.
- External traffic: review provider-specific routes and workflow integrations.
