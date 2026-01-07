#!/bin/bash

# --- ComfyFetch: Post-Startup Script for runpod/comfyui:latest ---
# Downloads models and workflows from Hugging Face after ComfyUI is installed

echo "� Starting ComfyFetch..."

# --- 1. Install huggingface_hub if needed ---
if ! python3 -c "import huggingface_hub" 2>/dev/null; then
    echo "📦 Installing huggingface_hub..."
    pip install --quiet huggingface_hub
fi

# --- 2. Sync Workflows from Hugging Face ---
if [ ! -z "$HF_WORKFLOWS" ]; then
    echo "📥 Syncing Workflows from $HF_WORKFLOWS..."
    python3 -c "
import os
try:
    from huggingface_hub import snapshot_download, login
    token = os.environ.get('HF_TOKEN')
    repo_id = os.environ.get('HF_WORKFLOWS')
    target = '/workspace/runpod-slim/ComfyUI/user/default/workflows'
    
    if repo_id:
        if token:
            login(token=token)
        snapshot_download(
            repo_id=repo_id,
            repo_type='dataset',
            local_dir=target,
            local_dir_use_symlinks=False,
            ignore_patterns=['*.git*']
        )
        print('✅ Workflows synced successfully')
except Exception as e:
    print(f'⚠️ Workflows sync failed: {e}')
"
else
    echo "⚠️ HF_WORKFLOWS not set. Skipping workflows sync."
fi

# --- 3. Sync Models from Hugging Face ---
if [ ! -z "$HF_MODELS" ]; then
    echo "🔐 Syncing Models from $HF_MODELS..."
    python3 -c "
import os
try:
    from huggingface_hub import snapshot_download, login
    token = os.environ.get('HF_TOKEN')
    dataset = os.environ.get('HF_MODELS')
    target = '/workspace/runpod-slim/ComfyUI/models'
    
    if dataset:
        if token:
            login(token=token)
        snapshot_download(
            repo_id=dataset,
            repo_type='dataset',
            local_dir=target,
            local_dir_use_symlinks=False,
            ignore_patterns=['*.git*']
        )
        print('✅ Models synced successfully')
except Exception as e:
    print(f'⚠️ Models sync failed: {e}')
"
else
    echo "⚠️ HF_MODELS not set. Skipping models sync."
fi

echo "🏁 ComfyFetch complete!"