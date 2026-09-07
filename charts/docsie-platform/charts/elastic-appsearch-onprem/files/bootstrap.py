"""Provision reusable App Search keys without exposing the administrator password."""
import base64
import json
import os
from pathlib import Path
import ssl
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def request(url, method='GET', payload=None, authorization='', context=None):
    headers = {'Content-Type': 'application/json', 'Authorization': authorization}
    body = None if payload is None else json.dumps(payload).encode()
    with urlopen(Request(url, data=body, headers=headers, method=method),
                 context=context, timeout=20) as response:
        data = response.read()
        return json.loads(data) if data else None


def ensure_key(api, name, write):
    """Keep stable key names and permissions across retries and chart upgrades."""
    expected = {'name': name, 'type': 'private', 'read': True,
                'write': write, 'access_all_engines': True}
    try:
        result = api('/credentials/' + name)
    except HTTPError as error:
        if error.code != 404:
            raise
        result = api('/credentials', 'POST', expected)
    if any(result.get(key) != value for key, value in expected.items()):
        raise RuntimeError('Existing search credential has unexpected permissions')
    return result['key']


def main():
    deadline = time.monotonic() + int(os.environ.get('TIMEOUT_SECONDS', '900'))
    context = ssl.create_default_context(cafile='/search-tls/tls.crt')
    password = Path('/search-auth/elastic').read_text().strip()
    authorization = 'Basic ' + base64.b64encode(('elastic:' + password).encode()).decode()
    endpoint = os.environ['APPSEARCH_URL'].rstrip('/')

    def api(path, method='GET', payload=None):
        return request(endpoint + path, method, payload, authorization, context)

    while True:
        try:
            api('/engines')
            break
        except (HTTPError, URLError, TimeoutError, OSError):
            if time.monotonic() >= deadline:
                raise RuntimeError('App Search did not become ready before the deadline') from None
            time.sleep(5)

    values = {
        'APPSEARCH_KEY': ensure_key(api, 'docsie-indexing', True),
        # A read-only PRIVATE key is required for signed, filtered portal searches.
        'APPSEARCH_SEARCH_KEY': ensure_key(api, 'docsie-search-signing', False),
    }
    token_path = Path('/var/run/secrets/kubernetes.io/serviceaccount')
    kube_context = ssl.create_default_context(cafile=str(token_path / 'ca.crt'))
    token = 'Bearer ' + (token_path / 'token').read_text().strip()
    namespace = (token_path / 'namespace').read_text().strip()
    kube_url = 'https://' + os.environ['KUBERNETES_SERVICE_HOST'] + ':' + os.environ['KUBERNETES_SERVICE_PORT_HTTPS']
    secret_url = kube_url + '/api/v1/namespaces/' + namespace + '/secrets'
    name = os.environ['RUNTIME_SECRET']
    data = {key: base64.b64encode(value.encode()).decode() for key, value in values.items()}
    secret = {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {'name': name},
              'type': 'Opaque', 'data': data}
    try:
        existing = request(secret_url + '/' + name, authorization=token, context=kube_context)
    except HTTPError as error:
        if error.code != 404:
            raise
        request(secret_url, 'POST', secret, token, kube_context)
    else:
        if existing.get('data') != data:
            raise RuntimeError('Stored search keys differ; explicit credential recovery is required')
    print('App Search credentials ready; existing keys preserved.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Provider responses can contain credentials; never print bodies or tracebacks.
        print('Search bootstrap failed: ' + type(error).__name__, flush=True)
        raise SystemExit(1)
