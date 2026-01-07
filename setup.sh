#!/bin/bash

# --- ComfyFetch: Models & Workflows Sync Script ---
# This script ONLY handles downloading models and workflows from Hugging Face.
# Dependencies and ComfyUI setup should be handled separately (e.g., in Docker image).

echo "🔍 Starting ComfyFetch..."

# --- 1. Workflows Sync (Hugging Face) ---
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

# --- 2. Models Sync (Hugging Face) ---
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

echo "✅ ComfyFetch complete!"