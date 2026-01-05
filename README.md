# ComfyFetch

Automatisches Setup-Skript für ComfyUI auf RunPod. Installiert PyTorch 2.4.1, Flash Attention 2 und synchronisiert private Daten von Hugging Face.

## RunPod Start Command

Füge dies in das Feld **Container Start Command** im Template ein:

```bash
/bin/bash -c "curl -fsSL [https://raw.githubusercontent.com/mako-code/comfyfetch/main/setup.sh](https://raw.githubusercontent.com/mako-code/comfyfetch/main/setup.sh) | bash"

```

*Cache umgehen:* `.../setup.sh?v=1 | bash`

## Environment Variables

Diese Variablen im RunPod Template setzen:

| Variable | Beschreibung | Beispiel |
| --- | --- | --- |
| `HF_TOKEN` | Hugging Face Token (Read). | `hf_...` |
| `HF_MODELS` | Dataset für Modelle. Landet in `/models`. | `User/comfy-models` |
| `HF_WORKFLOWS` | Dataset für `.json` Workflows. Landet in `/user/...` | `User/comfy-workflows` |

## Dienste & Ports

* **8188:** ComfyUI
* **8888:** Jupyter Lab
* **8080:** Filebrowser
* **3000:** Dependency Manager (pip GUI)

## Hinweise

* **Dauer:** Erster Start dauert ca. 3-5 Min (Kompilierung von Flash Attention).
* **Struktur:** Das Skript erwartet im `HF_MODELS` Dataset Unterordner wie `checkpoints`, `loras`, `vae` etc.
* **Updates:** Nach dem erstmaligen Starten von ComfyUI sollte über den ComfyUI-Manager einmal "Update all" ausgeführt und im Anschluss der ComfyUI-Server neugestartet werden.
