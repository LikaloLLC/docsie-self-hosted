"""Exercise indexing and read-only search on a uniquely named disposable engine."""
import base64
import hashlib
import hmac
import json
import os
import ssl
import time
import uuid
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def main():
    context = ssl.create_default_context(cafile='/search-tls/tls.crt')
    endpoint = os.environ['APPSEARCH_URL'].rstrip('/')
    engine = 'docsie-install-check-' + uuid.uuid4().hex[:16]

    def api(path, method='GET', payload=None, read_only=False, token=None):
        key = token or os.environ['APPSEARCH_SEARCH_KEY' if read_only else 'APPSEARCH_KEY']
        body = None if payload is None else json.dumps(payload).encode()
        req = Request(endpoint + path, data=body, method=method,
                      headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'})
        with urlopen(req, context=context, timeout=20) as response:
            return json.load(response)

    api('/engines', 'POST', {'name': engine})
    try:
        result = api('/engines/' + engine + '/documents', 'POST',
                     [{'id': 'installation-check', 'title': 'Docsie search installation canary', 'visibility': 'public'},
                      {'id': 'private-check', 'title': 'Docsie search installation canary', 'visibility': 'private'}])
        assert result and not result[0]['errors'], 'Indexing rejected the canary'
        deadline = time.monotonic() + 90
        while True:
            found = api('/engines/' + engine + '/search', 'POST', {'query': 'canary'}, True)
            if any(item['id']['raw'] == 'installation-check' for item in found.get('results', [])):
                break
            if time.monotonic() >= deadline:
                raise RuntimeError('Indexed document did not become searchable')
            time.sleep(2)
        # Same HS256 signing contract used by Docsie's elastic_app_search client.
        def encode(value):
            return base64.urlsafe_b64encode(value).rstrip(b'=')
        header = encode(json.dumps({'alg': 'HS256', 'typ': 'JWT'}).encode())
        payload = encode(json.dumps({'api_key_name': 'docsie-search-signing',
                                     'filters': {'visibility': 'public'}}).encode())
        unsigned = header + b'.' + payload
        signature = encode(hmac.new(os.environ['APPSEARCH_SEARCH_KEY'].encode(),
                                    unsigned, hashlib.sha256).digest())
        token = (unsigned + b'.' + signature).decode()
        result = api('/engines/' + engine + '/search', 'POST', {'query': 'canary'}, token=token)
        assert [item['id']['raw'] for item in result['results']] == ['installation-check']
        result = api('/engines/' + engine + '/search', 'POST',
                     {'query': 'canary', 'filters': {'visibility': 'private'}}, token=token)
        assert not result['results'], 'Caller bypassed signed search filters'
        try:
            api('/engines/' + engine + '/documents', 'POST', [{'id': 'forbidden-write'}], True)
        except HTTPError as error:
            assert error.code in (401, 403), 'Unexpected write rejection status'
        else:
            raise RuntimeError('Read-only search key unexpectedly permitted indexing')
        print('PASS: indexing, search retrieval, signed filter enforcement and read-only keys.')
    finally:
        api('/engines/' + engine, 'DELETE')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('Search verification failed: ' + type(error).__name__, flush=True)
        raise SystemExit(1)
