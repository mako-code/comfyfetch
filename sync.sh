#!/bin/bash

echo "🔄 Starting Manual Sync..."

# 1. Check for Token
if [ -z "$HF_TOKEN" ]; then
    echo "❌ Error: HF_TOKEN environment variable is not set."
    exit 1
fi

# 2. Sync Workflows
if [ ! -z "$HF_WORKFLOWS" ]; then
    echo "📥 Checking Workflows from $HF_WORKFLOWS..."
    python3 -c "
import os
try:
    from huggingface_hub import snapshot_download, login
    token = os.environ.get('HF_TOKEN')
    repo_id = os.environ.get('HF_WORKFLOWS')
    target = '/workspace/ComfyUI/user/default/workflows'
    
    if token and repo_id:
        login(token=token)
        print(f'   Target: {target}')
        snapshot_download(repo_id=repo_id, repo_type='dataset', local_dir=target, local_dir_use_symlinks=False, ignore_patterns=['*.git*'])
        print('✅ Workflows synced successfully')
except Exception as e:
    print(f'❌ Workflow Sync Failed: {e}')
"
else
    echo "⚠️ HF_WORKFLOWS variable not set. Skipping workflows."
fi

# 3. Sync Models
if [ ! -z "$HF_MODELS" ]; then
    echo "🔐 Checking Models from $HF_MODELS..."
    python3 -c "
import os
try:
    from huggingface_hub import snapshot_download, login
    token = os.environ.get('HF_TOKEN')
    dataset = os.environ.get('HF_MODELS')
    target = '/workspace/ComfyUI/models'

    if token and dataset:
        login(token=token)
        print(f'   Target: {target}')
        # snapshot_download is smart: it only downloads changed/new files
        snapshot_download(repo_id=dataset, repo_type='dataset', local_dir=target, local_dir_use_symlinks=False, ignore_patterns=['*.git*'])
        print('✅ Models synced successfully')
except Exception as e:
    print(f'❌ Model Sync Failed: {e}')
"
else
    echo "⚠️ HF_MODELS variable not set. Skipping models."
fi

echo "🏁 Sync Complete."