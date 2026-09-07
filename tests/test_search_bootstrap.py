"""Search bootstrap must reuse keys and reject silently broadened permissions."""
import importlib.util
from pathlib import Path
import unittest
from urllib.error import HTTPError

path = Path(__file__).resolve().parents[1] / 'charts/docsie-platform/charts/elastic-appsearch-onprem/files/bootstrap.py'
spec = importlib.util.spec_from_file_location('search_bootstrap', path)
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)


class SearchBootstrapTests(unittest.TestCase):
    def test_create_then_upgrade_keeps_read_only_private_key(self):
        stored = {}
        writes = []

        def api(path, method='GET', body=None):
            if method == 'POST':
                writes.append(body)
                stored.update(body, key='synthetic-test-value')
            if not stored:
                raise HTTPError(path, 404, '', {}, None)
            return dict(stored)

        first = bootstrap.ensure_key(api, 'docsie-search-signing', False)
        self.assertEqual(first, bootstrap.ensure_key(api, 'docsie-search-signing', False))
        self.assertEqual(len(writes), 1)
        self.assertFalse(stored['write'])
        self.assertEqual(stored['type'], 'private')

    def test_existing_write_access_is_rejected_for_signing_key(self):
        def api(*args):
            return {'name': 'docsie-search-signing', 'type': 'private', 'read': True,
                    'write': True, 'access_all_engines': True, 'key': 'synthetic-test-value'}
        with self.assertRaises(RuntimeError):
            bootstrap.ensure_key(api, 'docsie-search-signing', False)

    def test_authentication_failure_does_not_try_to_create_key(self):
        calls = []
        def api(*args):
            calls.append(args)
            raise HTTPError('/credentials', 401, '', {}, None)
        with self.assertRaises(HTTPError):
            bootstrap.ensure_key(api, 'docsie-indexing', True)
        self.assertEqual(len(calls), 1)
