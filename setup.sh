#!/bin/bash

# --- 1. System Setup ---
echo '🚀 Setting up Container...'
apt-get update >/dev/null && apt-get install -y fish git curl aria2 >/dev/null

if [ ! -f /usr/local/bin/filebrowser ]; then
    echo '📥 Installing Filebrowser...'
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash >/dev/null
fi

# --- 2. ComfyUI Installation ---
cd /workspace
if [ ! -d 'ComfyUI' ]; then
    echo '📥 Cloning ComfyUI...'
    git clone https://github.com/comfyanonymous/ComfyUI.git
else
    echo '🔄 Updating ComfyUI...'
    cd /workspace/ComfyUI && git pull
fi

mkdir -p /workspace/ComfyUI/custom_nodes
if [ ! -d '/workspace/ComfyUI/custom_nodes/ComfyUI-Manager' ]; then
    echo '📥 Installing ComfyUI Manager...'
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git /workspace/ComfyUI/custom_nodes/ComfyUI-Manager
fi

# --- 3. Dependencies (CRITICAL: MUST RUN BEFORE DOWNLOADS) ---
echo '📦 Installing Python Dependencies...'
cd /workspace/ComfyUI

# 1. Install core requirements
pip install -r requirements.txt >/dev/null

# 2. Upgrade PyTorch to 2.4.1 (Fixes "is_compiling" error in ComfyUI 0.7+)
echo '   - Upgrading PyTorch to 2.4.1...'
pip install torch==2.4.1 torchvision==0.19.1 torchaudio==2.4.1 --index-url https://download.pytorch.org/whl/cu121

# 3. Install Flash Attention (Essential for SeedVR)
echo '   - Installing Xformers & Flash Attention (Wait for build)...'
pip install ninja
pip install xformers==0.0.28.post1 --index-url https://download.pytorch.org/whl/cu121
pip install flash-attn --no-build-isolation

# 4. Install Helper Tools (Fixes "huggingface_hub not found")
echo '   - Upgrading Tools...'
python3 -m pip install --upgrade transformers huggingface_hub gradio gradio_client jupyterlab

# --- 4. Custom Workflows (Hugging Face) ---
if [ ! -z "$HF_WORKFLOWS" ]; then
    echo "📥 Syncing User Workflows from Hugging Face..."
    python3 -c "
import os, sys
try:
    from huggingface_hub import snapshot_download, login
except ImportError:
    print('❌ Error: huggingface_hub not installed!')
    sys.exit(0)

token = os.environ.get('HF_TOKEN')
repo_id = os.environ.get('HF_WORKFLOWS')
target_dir = '/workspace/ComfyUI/user/default/workflows'

if token and repo_id:
    try:
        login(token=token)
        print(f'⬇️  Downloading workflows from {repo_id}...')
        snapshot_download(repo_id=repo_id, repo_type='dataset', local_dir=target_dir, local_dir_use_symlinks=False, ignore_patterns=['*.git*'])
        print(f'✅ Workflows synced')
    except Exception as e:
        print(f'❌ Workflow Sync Failed: {e}')
"
fi

# --- 5. Hugging Face Models Sync ---
if [ ! -z "$HF_TOKEN" ] && [ ! -z "$HF_MODELS" ]; then
    echo "🔐 Syncing Model Dataset..."
    python3 -c "
import os
from huggingface_hub import snapshot_download, login
token = os.environ.get('HF_TOKEN')
dataset = os.environ.get('HF_MODELS')
if token:
    try:
        login(token=token)
        print(f'⬇️  Downloading models from {dataset}...')
        snapshot_download(repo_id=dataset, repo_type='dataset', local_dir='/workspace/ComfyUI/models', local_dir_use_symlinks=False, ignore_patterns=['*.git*'])
        print('✅ Models synced')
    except Exception as e:
        print(f'❌ Model Download Failed: {e}')
"
else
    echo '⚠️ Skipping HF Sync: Variables not set.'
fi

# --- 6. Dependency Manager & Launch ---
cat <<EOF > /workspace/dep_manager.py
import gradio as gr, subprocess, sys
def install(pkg):
    try: subprocess.check_call([sys.executable, '-m', 'pip', 'install', pkg]); return f'✅ Installed: {pkg}'
    except Exception as e: return f'❌ Error: {str(e)}'
def freeze(): return subprocess.check_output([sys.executable, '-m', 'pip', 'freeze']).decode('utf-8')
with gr.Blocks(title='RunPod Dep Manager') as demo:
    gr.Markdown('## 📦 Dependency Manager')
    with gr.Row(): inp = gr.Textbox(placeholder='package', label='Package'); btn = gr.Button('Install')
    out = gr.Textbox(label='Status'); btn.click(install, inputs=inp, outputs=out)
    with gr.Accordion('List', open=False): gr.Button('Refresh').click(freeze, outputs=gr.TextArea())
demo.launch(server_name='0.0.0.0', server_port=3000)
EOF

echo '✅ Starting Services...'
chmod -R 777 /workspace/ComfyUI/custom_nodes
filebrowser -r /workspace -p 8080 -a 0.0.0.0 --noauth -d /tmp/fb.db &
nohup jupyter lab --ip 0.0.0.0 --port 8888 --allow-root --no-browser --NotebookApp.token='' --notebook-dir=/workspace > /workspace/jupyter.log 2>&1 &
python3 /workspace/dep_manager.py &

cd /workspace/ComfyUI
echo '🎨 Launching ComfyUI...'
nohup python3 main.py --listen 0.0.0.0 --port 8188 --preview-method auto > /workspace/comfyui.log 2>&1 &

echo '🚀 SETUP COMPLETE.'
touch /workspace/keep_alive.log
tail -f /workspace/keep_alive.log