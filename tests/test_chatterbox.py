"""Optional TTS installs must stay private and configure the actual Dokuta clients."""
import unittest
import test_distribution as distribution


class ChatterboxTests(unittest.TestCase):
    render = distribution.DistributionTests.render

    @classmethod
    def setUpClass(cls):
        distribution.DistributionTests.setUpClass()

    def test_tts_is_opt_in(self):
        docs = self.render({})
        self.assertFalse(any(d['metadata']['name'] == 'chatterbox-tts' for d in docs))

    def test_tts_installs_model_cache_and_dokuta_configuration(self):
        docs = self.render({'global': {'chatterbox': {'enabled': True}}, 'profiles': {'full': True}})
        resources = {(d['kind'], d['metadata']['name']): d for d in docs}
        service = resources[('Service', 'chatterbox-tts')]
        self.assertEqual(service['spec']['type'], 'ClusterIP')
        pod = resources[('Deployment', 'chatterbox-tts')]['spec']['template']['spec']
        self.assertEqual(pod['nodeSelector']['kubernetes.io/arch'], 'amd64')
        self.assertFalse(pod['automountServiceAccountToken'])
        container = pod['containers'][0]
        self.assertIn('@sha256:', container['image'])
        self.assertIn("['loaded']", container['readinessProbe']['exec']['command'][-1])
        claim = next(v for v in pod['volumes'] if v['name'] == 'models')['persistentVolumeClaim']['claimName']
        self.assertIn(('PersistentVolumeClaim', claim), resources)
        self.assertIn(('NetworkPolicy', 'chatterbox-private'), resources)
        for name in ('dokuta', 'dokuta-fastapi', 'dokuta-celery'):
            env = resources[('Deployment', name)]['spec']['template']['spec']['containers'][0]['env']
            entries = {item['name']: item for item in env}
            self.assertEqual(len(entries), len(env), name + ' has duplicate environment variables')
            self.assertEqual(entries['CHATTERBOX_TTS_BASE_URL']['value'], 'http://chatterbox-tts:8004')
            self.assertEqual(entries['CHATTERBOX_TTS_VOICE']['value'], 'Emily.wav')
            ref = entries['DOKUTA_ENABLE_VOICE_API']['valueFrom']['secretKeyRef']
            self.assertEqual(resources[('Secret', ref['name'])]['stringData'][ref['key']], 'true')

    def test_external_server_does_not_install_local_model_or_gpu(self):
        docs = self.render({'profiles': {'full': True}, 'global': {'chatterbox': {
            'externalUrl': 'https://speech.example.test', 'apiKeySecretName': 'speech-key'}}})
        self.assertFalse(any(d['metadata']['name'] == 'chatterbox-tts' for d in docs))
        api = next(d for d in docs if d['kind'] == 'Deployment' and d['metadata']['name'] == 'dokuta-fastapi')
        env = {e['name']: e for e in api['spec']['template']['spec']['containers'][0]['env']}
        self.assertEqual(env['CHATTERBOX_TTS_BASE_URL']['value'], 'https://speech.example.test')
        self.assertEqual(env['CHATTERBOX_TTS_API_KEY']['valueFrom']['secretKeyRef']['name'], 'speech-key')
