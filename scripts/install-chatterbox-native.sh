#!/usr/bin/env bash
# Native model host (Apple MPS or CPU). Keeps the Python environment isolated.
set -euo pipefail
[[ $# -ge 1 && $# -le 3 ]] || { echo 'Usage: install-chatterbox-native.sh DIRECTORY [mps|cpu] [PORT]' >&2; exit 2; }
install_dir=$1
device=${2:-cpu}
port=${3:-8004}
python_bin=${PYTHON_BIN:-python3.10}
[[ "$device" == mps || "$device" == cpu ]] || { echo 'Select mps or cpu.' >&2; exit 2; }
[[ "$port" =~ ^[0-9]+$ && "$port" -ge 1024 && "$port" -le 65535 ]] || { echo 'Port must be 1024-65535.' >&2; exit 2; }
[[ ! -e "$install_dir" ]] || { echo 'Choose a new directory; existing installations are not overwritten.' >&2; exit 2; }
for tool in git ffmpeg "$python_bin"; do command -v "$tool" >/dev/null; done
"$python_bin" -c 'import sys; assert sys.version_info[:2] == (3,10), "Python 3.10 is required"'
git clone https://github.com/devnen/Chatterbox-TTS-Server.git "$install_dir"
cd "$install_dir"
git checkout --detach 915ae289340e10c6047f27f47e22eae9bf350c32
"$python_bin" -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/pip install --no-deps \
  'git+https://github.com/devnen/chatterbox-v2.git@cc0357396d9c73fc1e6c544ee40bb596020edd09' \
  s3tokenizer==0.3.0 onnx==1.16.0 protobuf==4.25.8
.venv/bin/python - "$device" "$port" <<'PY'
from pathlib import Path
import sys,yaml
path=Path('config.yaml');config=yaml.safe_load(path.read_text())
config['server'].update(host='127.0.0.1', port=int(sys.argv[2]), use_ngrok=False)
config['tts_engine']['device']=sys.argv[1]
config['model']['repo_id']='chatterbox-turbo'
config['ui_state']['last_text']='Docsie local speech test.'
path.write_text(yaml.safe_dump(config))
PY
# Model weights download on first start and remain under this installation.
export HF_HOME="$PWD/hf_cache"
# Experimental MPS mode may still fail on unsupported torchaudio operations.
export PYTORCH_ENABLE_MPS_FALLBACK=1
echo "Starting local Chatterbox on 127.0.0.1:$port; Ctrl-C stops it."
exec .venv/bin/python -m uvicorn server:app --host 127.0.0.1 --port "$port"
