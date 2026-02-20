#!/usr/bin/env python3
"""
AIStudio Python Daemon
Handles MLX-native inference for images, TTS, voice cloning, STT, and music.
Communication: stdin/stdout JSON (one JSON object per line).

Each request must contain:
  - "command": the operation to perform
  - "request_id": unique ID echoed back in the response

Responses are JSON objects written to stdout, one per line.
"""

import sys
import json
import traceback

# Lazy imports for each module
_image_gen = None
_tts = None
_voice_clone = None
_whisper_stt = None
_music_gen = None


def get_image_gen():
    global _image_gen
    if _image_gen is None:
        from mlx_image_gen import MLXImageGenerator
        _image_gen = MLXImageGenerator()
    return _image_gen


def get_tts():
    global _tts
    if _tts is None:
        from mlx_tts import MLXTTS
        _tts = MLXTTS()
    return _tts


def get_voice_clone():
    global _voice_clone
    if _voice_clone is None:
        from mlx_voice_clone import MLXVoiceClone
        _voice_clone = MLXVoiceClone()
    return _voice_clone


def get_whisper():
    global _whisper_stt
    if _whisper_stt is None:
        from mlx_whisper_stt import MLXWhisperSTT
        _whisper_stt = MLXWhisperSTT()
    return _whisper_stt


def get_music_gen():
    global _music_gen
    if _music_gen is None:
        from mlx_music_gen import MLXMusicGen
        _music_gen = MLXMusicGen()
    return _music_gen


def handle_request(request):
    """Dispatch a request to the appropriate handler."""
    command = request.get("command", "")
    request_id = request.get("request_id", "")

    try:
        if command == "health":
            return {"request_id": request_id, "status": "ok"}

        elif command == "generate_image":
            gen = get_image_gen()
            result = gen.generate(
                prompt=request.get("prompt", ""),
                negative_prompt=request.get("negative_prompt", ""),
                steps=request.get("steps", 20),
                cfg_scale=request.get("cfg_scale", 7.0),
                width=request.get("width", 512),
                height=request.get("height", 512),
                seed=request.get("seed", -1),
            )
            return {"request_id": request_id, **result}

        elif command == "img2img":
            gen = get_image_gen()
            result = gen.img2img(
                prompt=request.get("prompt", ""),
                init_image=request.get("init_image", ""),
                denoising_strength=request.get("denoising_strength", 0.75),
                steps=request.get("steps", 20),
                cfg_scale=request.get("cfg_scale", 7.0),
                seed=request.get("seed", -1),
            )
            return {"request_id": request_id, **result}

        elif command == "list_image_models":
            gen = get_image_gen()
            models = gen.list_models()
            return {"request_id": request_id, "models": models}

        elif command == "tts":
            tts = get_tts()
            result = tts.generate(
                text=request.get("text", ""),
                voice=request.get("voice", "default"),
                speed=request.get("speed", 1.0),
                engine=request.get("engine", "kokoro"),
            )
            return {"request_id": request_id, **result}

        elif command == "list_tts_engines":
            tts = get_tts()
            engines = tts.list_engines()
            return {"request_id": request_id, "engines": engines}

        elif command == "list_voices":
            tts = get_tts()
            voices = tts.list_voices(request.get("engine", "kokoro"))
            return {"request_id": request_id, "voices": voices}

        elif command == "voice_clone":
            vc = get_voice_clone()
            result = vc.clone(
                text=request.get("text", ""),
                reference_audio=request.get("reference_audio", ""),
                speed=request.get("speed", 1.0),
            )
            return {"request_id": request_id, **result}

        elif command == "transcribe":
            whisper = get_whisper()
            result = whisper.transcribe(
                audio_file=request.get("audio_file", ""),
                model=request.get("model", "base"),
                language=request.get("language"),
            )
            return {"request_id": request_id, **result}

        elif command == "generate_music":
            music = get_music_gen()
            result = music.generate(
                prompt=request.get("prompt", ""),
                duration=request.get("duration", 10.0),
                model_size=request.get("model_size", "small"),
            )
            return {"request_id": request_id, **result}

        elif command == "cancel":
            return {"request_id": request_id, "status": "cancelled"}

        else:
            return {"request_id": request_id, "error": f"Unknown command: {command}"}

    except Exception as e:
        traceback.print_exc(file=sys.stderr)
        return {"request_id": request_id, "error": str(e)}


def main():
    """Main loop: read JSON from stdin, process, write JSON to stdout."""
    sys.stderr.write("AIStudio daemon started\n")
    sys.stderr.flush()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            request = json.loads(line)
        except json.JSONDecodeError as e:
            response = {"error": f"Invalid JSON: {e}"}
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()
            continue

        response = handle_request(request)
        sys.stdout.write(json.dumps(response) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
