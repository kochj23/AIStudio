"""
MLX TTS (Text-to-Speech)
Uses mlx-audio for text-to-speech on Apple Silicon.
Supports Kokoro and other mlx-audio TTS models.
"""

import base64
import io
import time
import numpy as np

# Default model for each engine
ENGINE_MODELS = {
    "kokoro": "mlx-community/Kokoro-82M-bf16",
    "dia": "mlx-community/Dia-1.6B-bf16",
    "chatterbox": "mlx-community/Chatterbox-TTS-bf16",
    "spark": "mlx-community/SparkTTS-0.5B-bf16",
    "breeze": "mlx-community/Breeze2-TTSFRD-bf16",
    "outetts": "mlx-community/OuteTTS-0.3-500M-bf16",
}


class MLXTTS:
    def __init__(self):
        self._models = {}

    def _load_model(self, engine_name):
        """Lazy-load a TTS model."""
        if engine_name in self._models:
            return self._models[engine_name]

        try:
            from mlx_audio.tts import load_model
        except ImportError:
            raise RuntimeError(
                "mlx-audio not available. Install it:\n"
                "  pip install 'mlx-audio[kokoro]'"
            )

        model_path = ENGINE_MODELS.get(engine_name)
        if not model_path:
            raise RuntimeError(
                f"Unknown TTS engine: {engine_name}. "
                f"Available: {', '.join(ENGINE_MODELS.keys())}"
            )

        import sys
        # Redirect stdout to stderr during model loading to prevent print
        # statements from corrupting the JSON protocol on stdout.
        old_stdout = sys.stdout
        sys.stdout = sys.stderr
        try:
            model = load_model(model_path)
            self._models[engine_name] = model
            return model
        except Exception as e:
            raise RuntimeError(f"Failed to load {engine_name} model: {e}")
        finally:
            sys.stdout = old_stdout

    def generate(self, text, voice="af_heart", speed=1.0, engine="kokoro"):
        """Generate speech from text."""
        import sys, os

        model = self._load_model(engine)
        start = time.time()

        # Redirect stdout to stderr during generation to prevent model print
        # statements from corrupting the JSON protocol on stdout.
        old_stdout = sys.stdout
        sys.stdout = sys.stderr
        try:
            results = model.generate(text=text, voice=voice, speed=speed)

            # Collect all audio segments (iterate inside redirect since results is a generator)
            audio_segments = []
            sample_rate = getattr(model, "sample_rate", 24000)

            for result in results:
                audio = np.array(result.audio)
                audio_segments.append(audio)
                sample_rate = getattr(result, "sample_rate", sample_rate)
        finally:
            sys.stdout = old_stdout

        if not audio_segments:
            raise RuntimeError("TTS generated no audio")

        # Concatenate all segments
        full_audio = np.concatenate(audio_segments) if len(audio_segments) > 1 else audio_segments[0]

        wav_bytes = self._array_to_wav(full_audio, sample_rate)
        b64 = base64.b64encode(wav_bytes).decode("utf-8")
        duration = len(full_audio) / sample_rate
        elapsed = time.time() - start

        return {
            "audio": b64,
            "sample_rate": sample_rate,
            "duration": round(duration, 2),
            "generation_time": round(elapsed, 2),
        }

    def list_engines(self):
        """List available TTS engines."""
        available = []
        for engine in ENGINE_MODELS:
            try:
                self._load_model(engine)
                available.append(engine)
            except RuntimeError:
                pass
        return available if available else list(ENGINE_MODELS.keys())

    def list_voices(self, engine="kokoro"):
        """List available voices for an engine."""
        if engine == "kokoro":
            return [
                "af_heart", "af_bella", "af_nicole", "af_sarah", "af_sky",
                "am_adam", "am_michael",
                "bf_emma", "bf_isabella",
                "bm_george", "bm_lewis",
            ]
        return ["default"]

    def _array_to_wav(self, audio_array, sample_rate):
        """Convert numpy array to WAV bytes."""
        import struct

        if hasattr(audio_array, "numpy"):
            audio_array = audio_array.numpy()

        audio_array = np.array(audio_array, dtype=np.float32)

        if len(audio_array) > 0:
            peak = max(abs(audio_array.max()), abs(audio_array.min()))
            if peak > 1.0:
                audio_array = audio_array / peak

        int_data = (audio_array * 32767).astype(np.int16)

        buf = io.BytesIO()
        num_samples = len(int_data)
        data_size = num_samples * 2

        buf.write(b"RIFF")
        buf.write(struct.pack("<I", 36 + data_size))
        buf.write(b"WAVE")
        buf.write(b"fmt ")
        buf.write(struct.pack("<I", 16))
        buf.write(struct.pack("<H", 1))
        buf.write(struct.pack("<H", 1))
        buf.write(struct.pack("<I", sample_rate))
        buf.write(struct.pack("<I", sample_rate * 2))
        buf.write(struct.pack("<H", 2))
        buf.write(struct.pack("<H", 16))
        buf.write(b"data")
        buf.write(struct.pack("<I", data_size))
        buf.write(int_data.tobytes())

        return buf.getvalue()
