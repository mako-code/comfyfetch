# ComfyFetch

Post-startup script for syncing models and workflows to ComfyUI on RunPod.

## RunPod Template Settings

| Setting | Value |
|---------|-------|
| **Image** | `runpod/comfyui:latest` |
| **Startup Command** | See below |

## Startup Command

```bash
bash -c "curl -sSL https://raw.githubusercontent.com/mako-code/comfyfetch/main/setup.sh | bash"
```

> **Tipp:** Cache umgehen mit `.../setup.sh?v=1`

## Environment Variables

| Variable | Beschreibung | Beispiel |
| --- | --- | --- |
| `HF_TOKEN` | Hugging Face Token (Read) | `hf_...` |
| `HF_MODELS` | Dataset für Modelle → `/workspace/ComfyUI/models` | `User/comfy-models` |
| `HF_WORKFLOWS` | Dataset für Workflows → `/workspace/ComfyUI/user/default/workflows` | `User/comfy-workflows` |

## Ports (via runpod/comfyui)

| Service | Port |
|---------|------|
| ComfyUI | 3000 |
| Filebrowser | 8080 |
| JupyterLab | 8888 |

## Manueller Sync

```bash
curl -fsSL https://raw.githubusercontent.com/mako-code/comfyfetch/main/sync.sh | bash
```

Oder Alias einrichten:
```bash
echo 'curl -fsSL https://raw.githubusercontent.com/mako-code/comfyfetch/main/sync.sh | bash' > /usr/local/bin/sync-models && chmod +x /usr/local/bin/sync-models
```

## Hinweise

* **Struktur:** Das `HF_MODELS` Dataset sollte Unterordner wie `checkpoints`, `loras`, `vae` etc. enthalten
* **Updates:** Nach dem ersten Start über ComfyUI-Manager "Update all" ausführen