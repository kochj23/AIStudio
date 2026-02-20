"""
MLX TTS (Text-to-Speech)
Supports multiple MLX-based TTS engines:
- Kokoro, CSM, Chatterbox, Dia, Spark, Breeze, Mars5
"""

import base64
import io
import numpy as np

ENGINES = ["kokoro", "csm", "chatterbox", "dia", "spark", "breeze", "mars5"]


class MLXTTS:
    def __init__(self):
        self._engines = {}

    def _load_engine(self, engine_name):
        """Lazy-load a TTS engine."""
        if engine_name in self._engines:
            return self._engines[engine_name]

        if engine_name == "kokoro":
            try:
                from mlx_audio.tts import KokoroTTS
                self._engines[engine_name] = KokoroTTS()
            except ImportError:
                raise RuntimeError("Kokoro TTS not available. Install mlx-audio: pip install mlx-audio")

        elif engine_name == "csm":
            try:
                from mlx_audio.tts import CSMTTS
                self._engines[engine_name] = CSMTTS()
            except ImportError:
                raise RuntimeError("CSM TTS not available. Install mlx-audio: pip install mlx-audio")

        elif engine_name == "chatterbox":
            try:
                from mlx_audio.tts import ChatterboxTTS
                self._engines[engine_name] = ChatterboxTTS()
            except ImportError:
                raise RuntimeError("Chatterbox not available. Install mlx-audio: pip install mlx-audio")

        elif engine_name == "dia":
            try:
                from mlx_audio.tts import DiaTTS
                self._engines[engine_name] = DiaTTS()
            except ImportError:
                raise RuntimeError("Dia TTS not available. Install mlx-audio: pip install mlx-audio")

        elif engine_name == "spark":
            try:
                from mlx_audio.tts import SparkTTS
                self._engines[engine_name] = SparkTTS()
            except ImportError:
                raise RuntimeError("Spark TTS not available. Install mlx-audio: pip install mlx-audio")

        elif engine_name == "breeze":
            try:
                from mlx_audio.tts import BreezeTTS
                self._engines[engine_name] = BreezeTTS()
            except ImportError:
                raise RuntimeError("Breeze TTS not available. Install mlx-audio: pip install mlx-audio")

        elif engine_name == "mars5":
            try:
                from mlx_audio.tts import Mars5TTS
                self._engines[engine_name] = Mars5TTS()
            except ImportError:
                raise RuntimeError("Mars5 TTS not available. Install mlx-audio: pip install mlx-audio")

        else:
            raise RuntimeError(f"Unknown TTS engine: {engine_name}")

        return self._engines[engine_name]

    def generate(self, text, voice="default", speed=1.0, engine="kokoro"):
        """Generate speech from text."""
        tts_engine = self._load_engine(engine)

        audio_array = tts_engine.synthesize(text, voice=voice, speed=speed)

        # Convert to WAV bytes
        sample_rate = getattr(tts_engine, "sample_rate", 24000)
        wav_bytes = self._array_to_wav(audio_array, sample_rate)
        b64 = base64.b64encode(wav_bytes).decode("utf-8")

        duration = len(audio_array) / sample_rate

        return {
            "audio": b64,
            "sample_rate": sample_rate,
            "duration": duration,
        }

    def list_engines(self):
        """List available TTS engines."""
        available = []
        for engine in ENGINES:
            try:
                self._load_engine(engine)
                available.append(engine)
            except RuntimeError:
                pass  # Engine not installed
        return available if available else ENGINES

    def list_voices(self, engine="kokoro"):
        """List available voices for an engine."""
        try:
            tts_engine = self._load_engine(engine)
            if hasattr(tts_engine, "list_voices"):
                return tts_engine.list_voices()
        except RuntimeError:
            pass
        return ["default"]

    def _array_to_wav(self, audio_array, sample_rate):
        """Convert numpy array to WAV bytes."""
        import struct

        if hasattr(audio_array, "numpy"):
            audio_array = audio_array.numpy()

        audio_array = np.array(audio_array, dtype=np.float32)

        if audio_array.max() > 1.0 or audio_array.min() < -1.0:
            audio_array = audio_array / max(abs(audio_array.max()), abs(audio_array.min()))

        int_data = (audio_array * 32767).astype(np.int16)

        buf = io.BytesIO()
        num_samples = len(int_data)
        data_size = num_samples * 2  # 16-bit = 2 bytes per sample

        # WAV header
        buf.write(b"RIFF")
        buf.write(struct.pack("<I", 36 + data_size))
        buf.write(b"WAVE")
        buf.write(b"fmt ")
        buf.write(struct.pack("<I", 16))       # chunk size
        buf.write(struct.pack("<H", 1))        # PCM
        buf.write(struct.pack("<H", 1))        # mono
        buf.write(struct.pack("<I", sample_rate))
        buf.write(struct.pack("<I", sample_rate * 2))  # byte rate
        buf.write(struct.pack("<H", 2))        # block align
        buf.write(struct.pack("<H", 16))       # bits per sample
        buf.write(b"data")
        buf.write(struct.pack("<I", data_size))
        buf.write(int_data.tobytes())

        return buf.getvalue()
