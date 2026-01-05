#!/bin/bash

# --- 1. GPU Detection & Mode Selection ---
echo "🔍 Checking GPU Hardware..."
CURRENT_GPU=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | head -n 1)
echo "   - Found: $CURRENT_GPU"

# Check for Blackwell architecture (Future proofing)
IS_BLACKWELL=false
if [[ "$CURRENT_GPU" == *"Blackwell"* ]] || [[ "$CURRENT_GPU" == *"RTX 6000"* ]]; then
    # Note: RTX 6000 Ada is sm_89, but "Blackwell Server Edition" triggered your error.
    # We assume if it triggers the error, we need the bleeding edge mode.
    # Safe bet: If the card requires sm_120, we need latest torch.
    echo "🚀 High-End/Next-Gen GPU detected. Enabling Bleeding Edge PyTorch mode."
    IS_BLACKWELL=true
fi

# GPU Change Protection
LAST_GPU_FILE="/workspace/last_gpu_name"
if [ -f "$LAST_GPU_FILE" ]; then
    LAST_GPU=$(cat "$LAST_GPU_FILE")
    if [ "$CURRENT_GPU" != "$LAST_GPU" ]; then
        echo "⚠️ GPU Changed: $LAST_GPU -> $CURRENT_GPU"
        echo "♻️  Forcing re-installation..."
        rm -f "/workspace/comfy_deps_installed_v2"
        rm -rf /root/.triton/cache
    fi
fi
echo "$CURRENT_GPU" > "$LAST_GPU_FILE"

# --- 2. System Setup ---
echo '🚀 Setting up Container...'
if [ ! -f "/workspace/sys_deps_installed" ]; then
    apt-get update >/dev/null && apt-get install -y fish git curl aria2 nano >/dev/null
    touch /workspace/sys_deps_installed
fi

if [ ! -f /usr/local/bin/filebrowser ]; then
    echo '📥 Installing Filebrowser...'
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash >/dev/null
fi

# --- 3. ComfyUI Installation ---
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

# --- 4. Dependencies (Dynamic Branching) ---

# Check if we need to install dependencies
if [ -f "/workspace/comfy_deps_installed_v2" ]; then
    echo "✅ Dependencies already installed. Skipping..."
else
    echo "📦 Installing/Updating Python Dependencies..."
    cd /workspace/ComfyUI
    
    # Pre-install helpers
    pip install ninja einops packaging

    if [ "$IS_BLACKWELL" = true ]; then
        # --- PATH A: BLACKWELL (Bleeding Edge) ---
        echo "🔥 BLACKWELL MODE: Installing latest PyTorch (ignoring versions)..."
        
        # 1. Uninstall old stuff to be safe
        pip uninstall -y torch torchvision torchaudio xformers flash-attn
        
        # 2. Install latest Torch (This pulls the sm_120 compatible version)
        # We allow pip to resolve the latest compatible versions for all 3
        pip install --upgrade torch torchvision torchaudio
        
        # 3. Compile Flash Attention (Takes time, but ensures compatibility with new torch)
        echo "   - Compiling Flash Attention for Blackwell..."
        pip install flash-attn --no-build-isolation --force-reinstall
        
        # 4. Try installing xformers (might fail or need build, we try standard pip)
        echo "   - Installing xformers..."
        pip install xformers --no-deps || echo "⚠️ xformers install failed (expected on bleeding edge), skipping."

    else
        # --- PATH B: STANDARD (Stable / Hopper / Ada) ---
        echo "🛡️ STANDARD MODE: Installing Stable PyTorch 2.4.1..."
        
        # 1. Install core requirements
        pip install -r requirements.txt >/dev/null

        # 2. Upgrade PyTorch to 2.4.1 (Stable)
        pip install torch==2.4.1 torchvision==0.19.1 torchaudio==2.4.1 --index-url https://download.pytorch.org/whl/cu121

        # 3. Flash Attention & Xformers (Binary compatible)
        pip install xformers==0.0.28.post1 --index-url https://download.pytorch.org/whl/cu121
        pip install flash-attn --no-build-isolation --no-deps
    fi

    # 5. Install Tools (Common)
    echo '   - Installing Tools...'
    # We deliberately upgrade these at the end to ensure tqdm/gradio are present
    python3 -m pip install --upgrade transformers huggingface_hub gradio gradio_client jupyterlab tqdm

    # Create marker file
    touch /workspace/comfy_deps_installed_v2
fi

# --- 5. Custom Workflows (Hugging Face) ---
if [ ! -z "$HF_WORKFLOWS" ]; then
    echo "📥 Checking Workflows..."
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
except Exception:
    pass
"
fi

# --- 6. Hugging Face Models Sync ---
if [ ! -z "$HF_TOKEN" ] && [ ! -z "$HF_MODELS" ]; then
    echo "🔐 Checking Models..."
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
except Exception:
    pass
"
fi

# --- 7. Launch Services ---
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