"""Generate a real WAV and verify nonempty, non-silent PCM speech output."""
import io
import json
import os
import struct
import urllib.request
import wave

endpoint = os.environ.get('CHATTERBOX_URL', 'http://chatterbox-tts:8004').rstrip('/')
payload = {'model': os.environ.get('CHATTERBOX_MODEL', 'chatterbox-turbo'),
           'voice': os.environ.get('CHATTERBOX_VOICE', 'Emily.wav'),
           'input': 'Docsie can speak locally.', 'response_format': 'wav', 'speed': 1.0}
request = urllib.request.Request(endpoint + '/v1/audio/speech', json.dumps(payload).encode(),
                                 {'Content-Type': 'application/json'})
with urllib.request.urlopen(request, timeout=600) as response:
    audio = response.read(20 * 1024 * 1024)
assert audio[:4] == b'RIFF' and audio[8:12] == b'WAVE', 'Expected WAV audio'
with wave.open(io.BytesIO(audio)) as wav:
    assert wav.getnframes() > wav.getframerate() // 4, 'Speech output is too short'
    assert wav.getsampwidth() == 2, 'Expected 16-bit PCM audio'
    samples = wav.readframes(wav.getnframes())
    assert any(abs(value[0]) > 100 for value in struct.iter_unpack('<h', samples)), 'Speech output is silent'
    print('PASS: generated non-silent WAV, %.2f seconds at %s Hz.' %
          (wav.getnframes() / wav.getframerate(), wav.getframerate()))
if os.environ.get('CHATTERBOX_OUTPUT'):
    with open(os.environ['CHATTERBOX_OUTPUT'], 'wb') as output:
        output.write(audio)
