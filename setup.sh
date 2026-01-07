#!/bin/bash

# --- ComfyFetch: RunPod Template Script ---
# For use with: runpod/pytorch:2.2.1-py3.10-cuda12.1.1-devel-ubuntu22.04

echo "🔍 Starting ComfyFetch..."

# --- 1. System Setup ---
echo '🚀 Setting up Container...'
if [ ! -f "/workspace/sys_deps_installed" ]; then
    apt-get update >/dev/null && apt-get install -y fish git curl aria2 nano >/dev/null
    touch /workspace/sys_deps_installed
fi

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

# --- 3. Python Dependencies ---
if [ ! -f "/workspace/comfy_deps_installed" ]; then
    echo '📦 Installing ComfyUI dependencies...'
    cd /workspace/ComfyUI
    pip install -r requirements.txt
    pip install xformers==0.0.28.post1 --index-url https://download.pytorch.org/whl/cu121
    touch /workspace/comfy_deps_installed
else
    echo '✅ Dependencies already installed.'
fi

# Install tools for sync and services
pip install --quiet huggingface_hub gradio jupyterlab

# --- 4. Workflows Sync (Hugging Face) ---
if [ ! -z "$HF_WORKFLOWS" ]; then
    echo "📥 Syncing Workflows..."
    python3 -c "
import os, sys
try:
    from huggingface_hub import snapshot_download, login
    token = os.environ.get('HF_TOKEN')
    repo_id = os.environ.get('HF_WORKFLOWS')
    if token and repo_id:
        login(token=token)
        snapshot_download(repo_id=repo_id, repo_type='dataset', local_dir='/workspace/ComfyUI/user/default/workflows', local_dir_use_symlinks=False, ignore_patterns=['*.git*'])
        print('✅ Workflows synced')
except Exception as e:
    print(f'⚠️ Workflows sync failed: {e}')
"
fi

# --- 5. Models Sync (Hugging Face) ---
if [ ! -z "$HF_TOKEN" ] && [ ! -z "$HF_MODELS" ]; then
    echo "🔐 Syncing Models..."
    python3 -c "
import os
try:
    from huggingface_hub import snapshot_download, login
    token = os.environ.get('HF_TOKEN')
    dataset = os.environ.get('HF_MODELS')
    if token and dataset:
        login(token=token)
        snapshot_download(repo_id=dataset, repo_type='dataset', local_dir='/workspace/ComfyUI/models', local_dir_use_symlinks=False, ignore_patterns=['*.git*'])
        print('✅ Models synced')
except Exception as e:
    print(f'⚠️ Models sync failed: {e}')
"
fi

# --- 6. Launch Services ---
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
python3 main.py --listen 0.0.0.0 --port 8188 --preview-method auto