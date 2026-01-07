#!/bin/bash

# --- Fix for ComfyUI-SeedVR2_VideoUpscaler CUDA compatibility ---
# Patches the bfloat16 probe to handle CUDA kernel errors gracefully

COMPAT_FILE="/workspace/runpod-slim/ComfyUI/custom_nodes/seedvr2_videoupscaler/src/optimization/compatibility.py"

if [ ! -f "$COMPAT_FILE" ]; then
    echo "❌ SeedVR2 compatibility.py not found at: $COMPAT_FILE"
    exit 1
fi

echo "🔧 Patching SeedVR2 bfloat16 probe..."

# Create a Python script to patch the file
python3 << 'PATCH_SCRIPT'
import re

file_path = "/workspace/runpod-slim/ComfyUI/custom_nodes/seedvr2_videoupscaler/src/optimization/compatibility.py"

with open(file_path, 'r') as f:
    content = f.read()

# Find and replace the _probe_bfloat16_support function to catch RuntimeError
old_probe = r'''def _probe_bfloat16_support\(\) -> bool:
    """Probe whether bfloat16 is supported on the current device\."""
    if not torch\.cuda\.is_available\(\):
        return False
    try:
        a = torch\.randn\(8, 8, dtype=torch\.bfloat16, device='cuda:0'\)
        b = torch\.randn\(8, 8, dtype=torch\.bfloat16, device='cuda:0'\)
        _ = torch\.matmul\(a, b\)
        return True
    except.*?:
        return False'''

new_probe = '''def _probe_bfloat16_support() -> bool:
    """Probe whether bfloat16 is supported on the current device."""
    if not torch.cuda.is_available():
        return False
    try:
        a = torch.randn(8, 8, dtype=torch.bfloat16, device='cuda:0')
        b = torch.randn(8, 8, dtype=torch.bfloat16, device='cuda:0')
        _ = torch.matmul(a, b)
        return True
    except (RuntimeError, Exception):
        # Catch CUDA kernel errors for unsupported architectures
        return False'''

# Try a simpler approach - just add RuntimeError to the except clause
simple_fix = content.replace(
    "except Exception:",
    "except (RuntimeError, Exception):"
).replace(
    "except TypeError:",
    "except (RuntimeError, TypeError):"
)

# If the file has a bare except or specific exception, patch it
if "def _probe_bfloat16_support" in content:
    # Find lines around the probe function and patch the except clause
    lines = content.split('\n')
    patched_lines = []
    in_probe_func = False
    
    for i, line in enumerate(lines):
        if 'def _probe_bfloat16_support' in line:
            in_probe_func = True
        
        if in_probe_func and line.strip().startswith('except') and 'RuntimeError' not in line:
            # Add RuntimeError to the except clause
            if line.strip() == 'except:':
                line = line.replace('except:', 'except (RuntimeError, Exception):')
            elif 'except Exception' in line:
                line = line.replace('except Exception', 'except (RuntimeError, Exception)')
            elif 'except TypeError' in line:
                line = line.replace('except TypeError', 'except (RuntimeError, TypeError)')
            in_probe_func = False
        
        patched_lines.append(line)
    
    content = '\n'.join(patched_lines)

with open(file_path, 'w') as f:
    f.write(content)

print("✅ Patched _probe_bfloat16_support to catch RuntimeError")
PATCH_SCRIPT

echo "✅ SeedVR2 fix applied. Restart ComfyUI to take effect."
