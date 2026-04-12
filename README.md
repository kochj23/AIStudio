# AI Studio

![Build](https://github.com/kochj23/AIStudio/actions/workflows/build.yml/badge.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-2.3.2-orange)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-required-blueviolet)

**Local AI media creation studio for macOS, powered by Apple Silicon.**

AI Studio is a native SwiftUI application that connects to local Stable Diffusion backends (Automatic1111, ComfyUI, SwarmUI) and runs MLX-native inference directly on your Mac. Generate images, videos, audio, and more -- all locally, no cloud required. Includes a multi-backend LLM chat interface, a full audio suite with voice cloning, and a WidgetKit extension for at-a-glance status.

Written by Jordan Koch.

---

## Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Backend Setup](#backend-setup)
- [Configuration](#configuration)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Project Structure](#project-structure)
- [Security](#security)
- [Version History](#version-history)
- [License](#license)

---

## Architecture

```
+------------------------------------------------------------------+
|                     AI Studio (SwiftUI macOS)                     |
|                                                                   |
|  +------------+  +------------+  +----------+  +------+  +------+ |
|  |  Images    |  |   Videos   |  |  Audio   |  | Chat |  |Gallery| |
|  |  Tab       |  |   Tab      |  |  Tab     |  | Tab  |  | Tab  | |
|  +-----+------+  +-----+------+  +----+-----+  +--+---+  +--+---+ |
|        |              |              |            |          |     |
+------------------------------------------------------------------+
         |              |              |            |          |
         v              v              v            v          v
+------------------+  +----------+  +----------+  +----------+  +----------+
| ImageBackend     |  | ComfyUI  |  | MLXAudio |  | LLMBackend|  | Gallery  |
| Protocol         |  | Animate  |  | Service  |  | Manager   |  | Service  |
+--------+---------+  | Diff     |  +----+-----+  +-----+-----+  +----------+
         |            +----------+       |               |
         v                               v               v
+--------+---------+             +-------+------+ +------+------+------+------+
| Automatic1111    |             | Python       | | Ollama      TinyLLM      |
| Service (REST)   |             | Daemon       | | (stream)    (stream)     |
+------------------+             | Service      | +-------------+            |
| ComfyUI Service  |             | (stdin/JSON) | | TinyChat    OpenWebUI    |
| (REST+WebSocket  |             +------+-------+ | (REST)      (SSE stream) |
|  +ControlNet)    |                    |         +-------------+            |
+------------------+                    v         | MLX (local subprocess)   |
| SwarmUI Service  |             +------+-------+ +--------------------------+
| (REST sessions)  |             | aistudio_    |
+------------------+             | daemon.py    |
| MLX Image        | <--------> |              |
| Service (daemon) |            | +----------+ |
+------------------+            | |mlx_tts   | |
                                | |mlx_voice | |
  RetryHandler                  | |mlx_whis. | |
  (exp. backoff + jitter)       | |mlx_music | |
  +-- httpBackend preset        | |mlx_image | |
  +-- pythonDaemon preset       | +----------+ |
  +-- healthCheck preset        +--------------+

+------------------------------------------------------------------+
| NovaAPIServer (port 37425, loopback) -- /api/status, /api/ping   |
+------------------------------------------------------------------+
| GenerationQueue (FIFO, 50 items, pause/resume, reorder)          |
+------------------------------------------------------------------+
| PromptHistory (persistent, search, tags, favorites, dedup)       |
+------------------------------------------------------------------+
| WidgetKit Extension (small/medium/large status widgets)          |
+------------------------------------------------------------------+
```

**Key design decision:** `ImageBackendProtocol` abstracts all image generation backends behind an actor-based interface. The ViewModel calls `backendManager.activeBackend.textToImage(request)` without knowing which backend is active. Switching backends is a one-line configuration change with no impact on the generation pipeline.

The Python daemon (`aistudio_daemon.py`) communicates with Swift via stdin/stdout JSON-line protocol. Each request carries a UUID `request_id` that is echoed back in the response, allowing concurrent requests. Modules are lazy-loaded on first use to keep startup fast.

---

## Features

### Image Generation

- **Automatic1111** -- Full txt2img and img2img via REST API
- **ComfyUI** -- Workflow-based generation with WebSocket progress tracking and ControlNet support (control images, preprocessors, configurable strength)
- **SwarmUI** -- Session-based image generation via REST
- **MLX Native** -- Run Stable Diffusion directly on Apple Silicon via diffusionkit/mflux through the Python daemon
- **Model picker** -- Browse and select from available checkpoints per backend; auto-selects on connect
- **SafeTensors enforcement** -- `.ckpt`, `.bin`, and `.pt` (PyTorch pickle) checkpoint files are blocked at both the model picker and request level; only `.safetensors` format is permitted
- Parameter controls: steps, CFG scale, sampler, dimensions, seed, batch size
- Auto-save with date-organized output directories
- Metadata JSON export alongside each generated image

### Generation Queue

- **Batch generation** -- Stack up to 50 prompts and walk away
- FIFO processing with pause/resume control
- Reorder, cancel, and remove individual items
- Queue management UI with live status indicators
- Auto-starts on enqueue; pauses cleanly between items

### Prompt History

- **Persistent prompt library** with search, sort, and tag filtering
- Automatic recording of every generation with deduplication
- Favorites and use-count tracking
- Import from existing metadata JSON files
- One-click to reload any prompt with its original parameters

### Image Comparison

- **Side-by-side** mode with synchronized zoom
- **Slider overlay** mode with draggable divider
- Zoom controls: fit, 1:1 actual size, zoom in/out
- Optional metadata display per image

### Video Generation

- **AnimateDiff** via ComfyUI -- Generate animated sequences from text prompts
- Frame-to-MP4 combining with AVAssetWriter
- Configurable frame count, FPS, and resolution

### Audio Suite

- **Text-to-Speech (TTS)** -- 6 MLX engines via mlx-audio: Kokoro (11 voices), Dia, Chatterbox, Spark, Breeze, OuteTTS with configurable speed
- **Voice Cloning** -- f5-tts-mlx reference-based voice cloning with automatic sample rate conversion (24kHz) and auto-transcription via mlx-whisper
- **Speech-to-Text (STT)** -- mlx-whisper transcription with models from tiny through large-v3
- **Music Generation** -- MusicGen via transformers (text-to-music with configurable duration)
- Built-in audio player with playback controls
- Drag-and-drop audio files for voice cloning reference
- Supports WAV, MP3, M4A input at any sample rate

### LLM Chat

- **5 backends:** Ollama, TinyLLM, TinyChat, OpenWebUI, MLX
- **Streaming** for Ollama, TinyLLM, and OpenWebUI (SSE / Server-Sent Events)
- Auto-detection with priority-based fallback (Ollama > TinyChat > TinyLLM > OpenWebUI > MLX)
- Conversation history with configurable system prompt
- Temperature and max token controls

### Gallery

- Browse all generated media (images, videos, audio)
- Filter by type, search by prompt, sort by date or name
- Metadata panel displaying full generation parameters
- Reveal in Finder and delete with confirmation

### WidgetKit Extension

- Small, medium, and large widget sizes
- At-a-glance backend status and recent generation info
- Shared data via App Group container

### Backend Resilience

- **Retry with exponential backoff and jitter** for transient connection failures
- Three retry presets: `httpBackend` (3 attempts, retries on connection errors), `pythonDaemon` (2 attempts, retries on daemon termination), `healthCheck` (2 attempts, quick)
- **Python daemon crash recovery** -- Auto-restart up to 5 times with exponential delays (1s, 2s, 4s, 8s, 16s); crash counter resets after 5 minutes of stability

### Local API Server

- HTTP API on port **37425** (loopback only, no external exposure)
- `GET /api/status` -- App status, version, uptime
- `GET /api/ping` -- Health check
- Built with NWListener (Network framework); starts automatically on launch

---

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** (M1, M2, M3, M4 series)

### Optional Dependencies

For MLX-native features (local image generation, TTS, voice cloning, STT, music):

- **Python 3.10+** (3.13 recommended; mlx-audio requires modern type syntax)
- A dedicated Python virtual environment is strongly recommended

---

## Installation

### From DMG (Recommended)

1. Download the latest DMG from [Releases](https://github.com/kochj23/AIStudio/releases).
2. Open the DMG and drag AI Studio to your Applications folder.
3. Launch from Applications. macOS may prompt you to allow the app on first run since it is distributed outside the Mac App Store.

AI Studio is distributed exclusively via DMG. It is not available on the Mac App Store. The app runs without sandbox restrictions to allow direct file system access for media output and Python subprocess management.

### From Source

```bash
git clone git@github.com:kochj23/AIStudio.git
cd AIStudio
open AIStudio.xcodeproj
# Build and run (Cmd+R) -- requires Xcode 15+ and macOS 14 SDK
```

---

## Backend Setup

AI Studio does not bundle any AI models. You bring your own backends and models. At minimum, set up one image generation backend or the MLX native pipeline.

### Image Generation Backends

```bash
# Automatic1111 (default: http://localhost:7860)
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
cd stable-diffusion-webui
./webui.sh --api    # The --api flag is required

# ComfyUI (default: http://localhost:8188)
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI
python main.py

# SwarmUI (default: http://localhost:7801)
# See https://github.com/mcmonkeyprojects/SwarmUI
```

### LLM Backends

```bash
# Ollama (default: http://localhost:11434)
brew install ollama
ollama serve
ollama pull mistral:latest

# OpenWebUI, TinyLLM, TinyChat -- configure URLs in Settings
```

### MLX Native Setup (Optional)

Enables on-device image generation, TTS, voice cloning, STT, and music generation without any external backend.

```bash
# Create a dedicated Python venv (3.10+ required, 3.13 recommended)
python3 -m venv venv
source venv/bin/activate

# Install core dependencies
pip install 'mlx-audio[kokoro]' f5-tts-mlx mlx-whisper numpy Pillow

# Voice cloning requires espeak-ng for phonemizer
brew install espeak-ng

# Optional: MusicGen support
pip install transformers torch

# Optional: MLX image generation
pip install mflux
```

Then set the Python path in AI Studio > Settings to your venv's `python3` binary (e.g., `./venv/bin/python3`).

---

## Configuration

All settings are accessible via the Settings window (Cmd+,).

### Image Backend Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Automatic1111 URL | `http://localhost:7860` | AUTOMATIC1111 WebUI API endpoint |
| ComfyUI URL | `http://localhost:8188` | ComfyUI API endpoint |
| SwarmUI URL | `http://localhost:7801` | SwarmUI API endpoint |
| Python Path | `./venv/bin/python3` | Path to Python interpreter for MLX daemon |
| Output Directory | `~/Documents/AIStudio/output` | Where generated media is saved |
| Auto-Save | Enabled | Automatically save all generated images |

### LLM Backend Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Ollama URL | `http://localhost:11434` | Ollama API endpoint |
| TinyLLM URL | `http://localhost:8000` | TinyLLM OpenAI-compatible endpoint |
| TinyChat URL | `http://localhost:8000` | TinyChat API endpoint |
| OpenWebUI URL | `http://localhost:8080` | OpenWebUI endpoint (also checks port 3000) |
| Active Backend | Auto | Auto-detect or pin to a specific backend |
| Temperature | 0.7 | LLM sampling temperature |
| Max Tokens | 2048 | Maximum response length |

### Default Generation Parameters

| Parameter | Default | Range |
|-----------|---------|-------|
| Steps | 20 | 1-150 |
| CFG Scale | 7.0 | 1.0-30.0 |
| Width | 512 | 64-2048 |
| Height | 512 | 64-2048 |
| Sampler | Euler a | Backend-dependent |
| Batch Size | 1 | 1-8 |

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+1` through `Cmd+5` | Switch tabs (Images, Videos, Audio, Chat, Gallery) |
| `Cmd+Return` | Generate |
| `Escape` | Cancel generation |
| `Shift+Cmd+R` | Randomize seed |
| `Shift+Cmd+D` | Swap dimensions (width/height) |
| `Shift+Cmd+Q` | Add current prompt to queue |
| `Cmd+S` | Save image |
| `Shift+Cmd+C` | Copy image to clipboard |
| `Cmd+,` | Open Settings |

---

## Project Structure

```
AIStudio/
├── AIStudioApp.swift           # App entry point, window/scene config, menu commands
├── ContentView.swift           # Tab-based navigation (Images, Videos, Audio, Chat, Gallery)
├── NovaAPIServer.swift         # Local HTTP API server (port 37425, loopback only)
│
├── Models/
│   ├── AppSettings.swift       # Persisted settings via UserDefaults
│   ├── BackendConfiguration.swift  # BackendType enum, BackendStatus, config struct
│   ├── GenerationRequest.swift # Image generation request/result models
│   ├── GenerationResult.swift  # Result containers with metadata
│   ├── MediaItem.swift         # Gallery media item model
│   ├── ChatMessage.swift       # Chat message model with roles
│   └── LLMBackendType.swift    # LLM backend type enum
│
├── Services/
│   ├── ImageBackendProtocol.swift  # Actor protocol all image backends conform to
│   ├── Automatic1111Service.swift  # AUTOMATIC1111 WebUI REST client
│   ├── ComfyUIService.swift        # ComfyUI REST + WebSocket + ControlNet client
│   ├── SwarmUIService.swift        # SwarmUI session-based REST client
│   ├── MLXImageService.swift       # MLX native image gen via Python daemon
│   ├── MLXAudioService.swift       # TTS, voice cloning, STT, music via daemon
│   ├── BackendManager.swift        # Owns all image backends, health checks, active selection
│   ├── LLMBackendManager.swift     # Owns all LLM backends, streaming, auto-detect
│   ├── PythonDaemonService.swift   # Manages Python subprocess (stdin/stdout JSON protocol)
│   ├── GenerationQueue.swift       # FIFO batch queue with pause/resume
│   ├── PromptHistory.swift         # Persistent prompt library with search/tags
│   ├── GalleryService.swift        # File-based media index
│   ├── MediaExportService.swift    # Media export utilities
│   └── WidgetDataSync.swift        # Shared data for WidgetKit extension
│
├── ViewModels/
│   ├── ImageGenerationViewModel.swift
│   ├── VideoGenerationViewModel.swift
│   ├── AudioViewModel.swift
│   ├── ChatViewModel.swift
│   └── GalleryViewModel.swift
│
├── Views/
│   ├── Images/                 # Image generation, queue, comparison, prompt history, parameters
│   ├── Videos/                 # Video generation + AVPlayer preview
│   ├── Audio/                  # TTS, Voice Clone, Music, STT sub-tabs
│   ├── Chat/                   # LLM chat interface with backend status
│   ├── Gallery/                # Grid browser + detail/metadata panel
│   ├── Common/                 # Progress overlay, status bar
│   └── Settings/               # Backend URLs, paths, Python config, LLM settings
│
├── Utilities/
│   ├── RetryHandler.swift      # Exponential backoff with jitter and preset configs
│   ├── SecureLogger.swift      # Logging with PII/credential redaction
│   ├── SecurityUtils.swift     # Input validation, sanitization, path traversal prevention
│   ├── ImageUtils.swift        # Image processing helpers
│   └── FileOrganizer.swift     # Date-organized output directory management
│
├── Python/
│   ├── aistudio_daemon.py      # Main daemon: stdin/stdout JSON dispatcher
│   ├── mlx_image_gen.py        # MLX Stable Diffusion wrapper (mflux/diffusionkit)
│   ├── mlx_tts.py              # Text-to-speech (6 engines via mlx-audio)
│   ├── mlx_voice_clone.py      # Voice cloning (f5-tts-mlx)
│   ├── mlx_whisper_stt.py      # Speech-to-text (mlx-whisper, tiny through large-v3)
│   ├── mlx_music_gen.py        # Music generation (MusicGen via transformers)
│   └── requirements.txt        # Python dependency manifest
│
└── Assets.xcassets/            # App icons and image assets

AIStudio Widget/
├── AIStudioWidget.swift        # WidgetKit timeline provider and views
├── SharedDataManager.swift     # App Group shared data access
├── WidgetData.swift            # Widget data models
└── Info.plist                  # Widget extension configuration
```

---

## Security

AI Studio takes a defense-in-depth approach to security despite running entirely locally.

### Input Validation and Sanitization

- **Prompt sanitization** -- Control characters stripped while preserving Stable Diffusion syntax (parentheses for emphasis, brackets for de-emphasis, colons for weights)
- **Path traversal prevention** -- All file paths validated against `../` sequences, symlink resolution, and 4096-byte length cap
- **URL validation** -- Only `http`, `https`, and `file` schemes accepted
- **File size caps** -- 50MB for images, 100MB for audio, 500MB for video

### Model Safety

- **SafeTensors-only enforcement** -- `.ckpt`, `.bin`, and `.pt` (PyTorch pickle) checkpoint files are blocked at both the model picker and request level. PyTorch pickle files can execute arbitrary code on load and are a known supply chain attack vector.

### Python Daemon Security

- **Prompt injection prevention** -- User prompts are written to a temporary file and read by the Python script rather than embedded as string literals. This prevents triple-quote injection attacks via `'''` sequences in user input.
- **stdout isolation** -- All ML operations redirect stdout to prevent model output from corrupting the JSON protocol channel

### Network

- No cloud services, no telemetry, no analytics
- All backend communication is localhost HTTP/WebSocket
- Nova API server binds to `127.0.0.1` only (loopback); no external network exposure
- `com.apple.security.network.client` entitlement for local backend connections

### Logging

- **SecureLogger** redacts API keys, tokens, and PII from all log output
- No sensitive data written to disk logs

### Sandbox Policy

- App sandbox is disabled (`com.apple.security.app-sandbox = false`) to allow direct file system access for media output, Python subprocess management, and backend communication
- Distributed via DMG, not the Mac App Store

---

## Version History

### v2.3.2 (March 4, 2026) -- Current

- **Security:** Python prompt injection fix -- user prompts written to temp file instead of embedded as string literals
- **Security:** `URLComponents` force unwrap replaced with safe guard/throw in `ComfyUIService.getImage()`
- **Security:** SafeTensors-only model enforcement -- `.ckpt`, `.bin`, and `.pt` checkpoint files blocked

### v2.3.1 (February 23, 2026)

- **Fix:** Python daemon pipe buffering -- large responses (>64KB) no longer silently dropped
- **Fix:** Voice cloning auto-transcribes reference audio via mlx-whisper for proper alignment
- **Fix:** Voice cloning uses `estimate_duration` for correct output length
- **Fix:** TTS rewritten for mlx-audio 0.3.x API (Kokoro, Dia, Chatterbox, Spark, Breeze, OuteTTS)
- **Fix:** stdout isolation for all ML operations prevents JSON protocol corruption
- **Fix:** Music generation stdout redirect for transformers/MusicGen
- Python 3.10+ venv support (required for mlx-audio modern type syntax)

### v2.3.0 (February 20, 2026)

- Generation queue with FIFO processing (up to 50 items, pause/resume)
- Prompt history with persistent library, search, favorites, tags
- Image comparison (side-by-side and slider overlay)
- ControlNet support for ComfyUI backend
- LLM streaming for TinyLLM and OpenWebUI (SSE)
- Keyboard shortcuts for full creative workflow
- Backend resilience with retry and exponential backoff
- Python daemon crash recovery (auto-restart with backoff)
- Drag-and-drop image import
- Prompt auto-recording with deduplication
- Model picker with auto-detection per backend

### v2.2.0 (February 2026)

- WidgetKit extension with small/medium/large widget sizes

### v2.1.0 (February 2026)

- LLM chat tab with 5 backend support (Ollama, TinyLLM, TinyChat, OpenWebUI, MLX)

### v2.0.0 (February 2026)

- Complete rewrite: audio suite, video generation, gallery, multi-backend architecture

### v1.0.0 (February 2026)

- Initial release with Automatic1111 image generation

---

## Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit your changes with descriptive messages.
4. Open a pull request against `main`.

Please review the [Security Policy](SECURITY.md) before submitting changes.

---

## License

MIT License -- Copyright (c) 2026 Jordan Koch

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

See [LICENSE](LICENSE) for the full text.

---

Written by Jordan Koch ([kochj23](https://github.com/kochj23)).

> **Disclaimer:** This is a personal project created on my own time. It is not affiliated with, endorsed by, or representative of my employer.
