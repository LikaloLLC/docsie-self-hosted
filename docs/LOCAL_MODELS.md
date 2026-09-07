# Ollama and local model servers

This guide documents configuration; full Docsie AI workflows have not been
validated with Ollama in this release. Endpoint connectivity alone does not
prove chat, tools, search, OCR or video-to-docs acceptance.

## Model server and network

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

## Deployment values

Create an override file `models.yaml`:

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

## Organization routing

After creating your organization, merge these keys into its `config` JSON using
your administrative workflow. Preserve existing unrelated configuration. Use
the exact model name returned by the server. This example configures basic chat.

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

The context/output sizes are placeholders: match the loaded model's actual
server configuration. Without model overrides, Docsie can request a catalog
model your server does not have. Existing provider-specific `ai_endpoints`
entries take precedence over `default`; review them before assuming all traffic
routes locally. Do not declare tools, thinking or vision capabilities unless
they work with that model/server. Configure additional actions after testing.

Embeddings, transcription and OCR may need separate models/services. A chat
endpoint does not automatically provide them. Use network egress controls when
local-only inference is required; these settings are not an egress policy.

## Connectivity check from Docsie

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

## Other servers and troubleshooting

Other OpenAI-compatible servers use the same `/v1` routing with their exact
served model names. Authentication, tools, streaming and structured output vary;
no particular server/model combination is certified by this guide.

- Connection refused/timeouts: check bind address, DNS, routing and firewall.
- Model not found: check model tag and organization action overrides.
- HTTP 401: check Secret environment references and proxy credentials.
- Capability errors: verify the model supports the requested action.
- Chat works but indexing fails: check embeddings and search configuration.
- External traffic: review provider-specific routes and workflow integrations.
