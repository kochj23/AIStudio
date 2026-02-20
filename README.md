# AI Studio

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-2.3.0-orange)

**Local AI media creation studio for macOS, powered by Apple Silicon.**

AI Studio connects to local Stable Diffusion backends (Automatic1111, ComfyUI, SwarmUI) and runs MLX-native inference directly on your Mac. Generate images, videos, audio, and more — all locally, no cloud required.

---

## Features

### Image Generation
- **Automatic1111** REST API client — full txt2img and img2img support
- **ComfyUI** workflow-based generation with WebSocket progress tracking
- **SwarmUI** session-based image generation
- **MLX Native** — run Stable Diffusion directly on Apple Silicon via diffusionkit/mflux
- **ControlNet** — guided generation with control images, preprocessors, and configurable strength (ComfyUI)
- **Model picker** — browse and select from available checkpoints per backend, auto-selects on connect
- Parameter controls: steps, CFG scale, sampler, size, seed, batch size
- Auto-save with date-organized output directories
- Metadata JSON export alongside each image

### Generation Queue
- **Batch generation** — stack multiple prompts and walk away
- FIFO processing with pause/resume control
- Reorder, cancel, and remove items
- Queue management UI with live status indicators
- Up to 50 items per queue

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
- **AnimateDiff** via ComfyUI — generate animated sequences from text prompts
- Frame-to-MP4 combining with AVAssetWriter
- Configurable frame count, FPS, resolution

### Audio Suite
- **Text-to-Speech** — 7 MLX engines: Kokoro, CSM, Chatterbox, Dia, Spark, Breeze, Mars5
- **Voice Cloning** — f5-tts-mlx reference-based voice cloning (drag & drop audio)
- **Speech-to-Text** — mlx-whisper transcription (tiny through large-v3 models)
- **Music Generation** — MusicGen via MLX or transformers fallback
- Built-in audio player with playback controls

### LLM Chat
- **5 backends:** Ollama, TinyLLM, TinyChat, OpenWebUI, MLX
- **Streaming** for Ollama, TinyLLM, and OpenWebUI (SSE)
- Auto-detection with priority-based fallback
- Conversation history with system prompt support

### Gallery
- Browse all generated media (images, videos, audio)
- Filter by type, search by prompt, sort by date or name
- Metadata panel with generation parameters
- Reveal in Finder, delete with confirmation

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| `Cmd+1-5` | Switch tabs (Images, Videos, Audio, Chat, Gallery) |
| `Cmd+Return` | Generate |
| `Escape` | Cancel generation |
| `Shift+Cmd+R` | Randomize seed |
| `Shift+Cmd+D` | Swap dimensions |
| `Shift+Cmd+Q` | Add to queue |
| `Cmd+S` | Save image |
| `Shift+Cmd+C` | Copy image to clipboard |

### Backend Resilience
- **Retry with exponential backoff** for transient connection failures
- **Python daemon crash recovery** — auto-restart up to 5 times with increasing delays
- Presets for HTTP backends, daemon operations, and health checks

---

## Architecture

```
AI Studio (SwiftUI macOS app)
  ├── Images Tab ─── ImageBackendProtocol ─┬── Automatic1111Service (REST)
  │                  GenerationQueue        ├── ComfyUIService (REST + WebSocket + ControlNet)
  │                  PromptHistory          ├── SwarmUIService (REST)
  │                  ImageComparisonView    └── MLXImageService (Python daemon)
  ├── Videos Tab ─── ComfyUI AnimateDiff workflows
  ├── Audio Tab ──── MLXAudioService ─── Python daemon ─┬── mlx-audio (TTS)
  │                                                     ├── f5-tts-mlx (voice clone)
  │                                                     ├── mlx-whisper (STT)
  │                                                     └── MusicGen (music)
  ├── Chat Tab ──── LLMBackendManager ─┬── Ollama (streaming)
  │                                    ├── TinyLLM (streaming)
  │                                    ├── OpenWebUI (streaming)
  │                                    ├── TinyChat
  │                                    └── MLX
  ├── Gallery Tab ── GalleryService (file-based index)
  └── Python/aistudio_daemon.py (stdin/stdout JSON protocol)
      └── RetryHandler (exponential backoff + crash recovery)
```

**Key design:** `ImageBackendProtocol` abstracts all image backends. The ViewModel calls `backend.textToImage(request)` without knowing which backend is active.

---

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon** (M1, M2, M3, M4)

### Backend Setup

```bash
# Automatic1111 (default: http://localhost:7860)
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
cd stable-diffusion-webui
./webui.sh --api  # Must use --api flag

# ComfyUI (default: http://localhost:8188)
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI
python main.py

# SwarmUI (default: http://localhost:7801)
# See https://github.com/mcmonkeyprojects/SwarmUI
```

### MLX Native Setup (Optional)

```bash
pip install -r AIStudio/Python/requirements.txt
# Installs: mlx, mlx-audio, f5-tts-mlx, mlx-whisper, numpy, Pillow
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

## File Structure

```
AIStudio/
├── Models/          # AppSettings, GenerationRequest/Result, BackendConfiguration, MediaItem
├── Services/        # ImageBackendProtocol, A1111/ComfyUI/SwarmUI/MLX services,
│                    # PythonDaemonService, GalleryService, GenerationQueue, PromptHistory
├── ViewModels/      # Image, Video, Audio, Gallery, Chat view models
├── Views/
│   ├── Images/      # Image generation, queue, comparison, prompt history, parameters, preview
│   ├── Videos/      # Video generation + AVPlayer preview
│   ├── Audio/       # TTS, Voice Clone, Music, STT sub-tabs
│   ├── Chat/        # LLM chat interface
│   ├── Gallery/     # Grid browser + detail panel
│   ├── Common/      # Progress overlay, status bar
│   └── Settings/    # Backend URLs, output paths, Python config, LLM settings
├── Utilities/       # SecureLogger, SecurityUtils, ImageUtils, FileOrganizer, RetryHandler
└── Python/          # aistudio_daemon.py, MLX wrappers (TTS, STT, music, voice clone, image gen)
```

---

## Version History

### v2.3.0 (February 20, 2026) — Current
- Generation queue — batch multiple prompts with FIFO processing
- Prompt history — persistent library with search, favorites, tags
- Image comparison — side-by-side and slider overlay modes
- ControlNet support for ComfyUI backend
- LLM streaming for TinyLLM and OpenWebUI (SSE)
- Keyboard shortcuts for full creative workflow
- Backend resilience with retry and exponential backoff
- Python daemon crash recovery (auto-restart)
- Drag & drop for image import
- Prompt auto-recording with deduplication
- Model picker — select checkpoints per backend with auto-detection

### v2.2.0 (February 2026)
- WidgetKit extension with small/medium/large views

### v2.1.0 (February 2026)
- LLM chat tab with 5 backend support (Ollama, TinyLLM, TinyChat, OpenWebUI, MLX)

### v2.0.0 (February 2026)
- Complete rewrite: audio suite, video generation, gallery, multi-backend

### v1.0.0 (February 2026)
- Initial release with Automatic1111 image generation

---

## Security

- No sandbox — direct file system access for media output
- No third-party Swift dependencies — Foundation URLSession only
- Base64 image validation (PNG/JPEG magic bytes)
- File size caps: 50MB images, 100MB audio, 500MB video
- Prompt sanitization: strip control chars, preserve SD syntax
- Sanitized logging — redacts API keys, tokens, PII
- SafeTensors-only for MLX model loading

---

## License

MIT License - Copyright 2026 Jordan Koch

See [LICENSE](LICENSE) for details.

---

> **Disclaimer:** This is a personal project created on my own time. It is not affiliated with, endorsed by, or representative of my employer.
