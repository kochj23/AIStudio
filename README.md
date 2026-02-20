# AI Studio

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

**Local AI media creation studio for macOS, powered by Apple Silicon.**

AI Studio connects to local Stable Diffusion backends (Automatic1111, ComfyUI, SwarmUI) and runs MLX-native inference directly on your Mac. Generate images, videos, audio, and more — all locally.

---

## Features

### Image Generation (v1.0.0)
- **Automatic1111** REST API client — full txt2img and img2img support
- **ComfyUI** workflow-based generation (Phase 2)
- **SwarmUI** integration (Phase 5)
- **MLX Native** — run Stable Diffusion directly on Apple Silicon (Phase 2)
- Parameter controls: steps, CFG scale, sampler, size, seed, batch size
- Auto-save with date-organized output directories
- Metadata JSON export alongside each image

### Coming Soon
- **Video Generation** — AnimateDiff via ComfyUI (Phase 3)
- **Text-to-Speech** — 7+ MLX models including Kokoro, CSM, Chatterbox (Phase 4)
- **Voice Cloning** — f5-tts-mlx reference-based cloning (Phase 4)
- **Speech-to-Text** — mlx-whisper transcription (Phase 4)
- **Music Generation** — MusicGen via MLX (Phase 4)
- **Gallery** — browse and manage all generated media (Phase 5)

---

## Architecture

```
AI Studio (SwiftUI macOS app)
  |
  |-- ImageBackendProtocol ----+-- Automatic1111Service (REST)
  |                            +-- ComfyUIService (REST + WebSocket)
  |                            +-- SwarmUIService (REST)
  |                            +-- MLXImageService (Python daemon)
  |
  |-- BackendManager           # Owns backends, health checks, active selection
  |-- ImageGenerationViewModel # Prompt, params, generate, auto-save
  |-- FileOrganizer            # Date-based output: {date}/images/
  |-- SecureLogger             # Sanitized logging (redacts keys, tokens, PII)
  |
  `-- Python/aistudio_daemon.py  (Phase 2 — MLX native inference)
```

**Key design:** `ImageBackendProtocol` abstracts all backends. The ViewModel calls `backend.textToImage(request)` without knowing which backend is active.

---

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** (M1, M2, M3, M4)
- **Automatic1111** running locally for image generation

### Backend Setup

```bash
# Automatic1111
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
cd stable-diffusion-webui
./webui.sh --api  # Must use --api flag
# Default: http://localhost:7860
```

---

## Installation

### From DMG

Download from [Releases](https://github.com/kochj23/AIStudio/releases), open the DMG, drag to Applications.

### From Source

```bash
git clone https://github.com/kochj23/AIStudio.git
cd AIStudio
open AIStudio.xcodeproj
# Build and run (Cmd+R)
```

---

## What It Doesn't Do (Yet)

- **Phase 1 (current):** Image generation via A1111 only
- Video, audio, gallery, ComfyUI, SwarmUI, and MLX native are planned for later phases
- No cloud services — everything runs locally

---

## License

MIT License - Copyright 2026 Jordan Koch

See [LICENSE](LICENSE) for details.

---

> **Disclaimer:** This is a personal project created on my own time. It is not affiliated with, endorsed by, or representative of my employer.
