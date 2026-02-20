"""
MLX Music Generation
Uses MusicGen via MLX for text-to-music on Apple Silicon.
"""

import base64
import io
import numpy as np


class MLXMusicGen:
    def __init__(self):
        self._model = None
        self._model_size = None

    def _load_model(self, model_size="small"):
        if self._model is not None and self._model_size == model_size:
            return self._model

        try:
            # Try MLX-native MusicGen
            from mlx_audio.models import MusicGen
            self._model = MusicGen(model_size=model_size)
            self._model_size = model_size
        except ImportError:
            try:
                # Fallback to transformers-based approach
                from transformers import AutoProcessor, MusicgenForConditionalGeneration
                model_name = f"facebook/musicgen-{model_size}"
                self._processor = AutoProcessor.from_pretrained(model_name)
                self._model = MusicgenForConditionalGeneration.from_pretrained(model_name)
                self._model_size = model_size
            except ImportError:
                raise RuntimeError(
                    "MusicGen not available. Install:\n"
                    "  pip install mlx-audio\n"
                    "  # or: pip install transformers torch"
                )

        return self._model

    def generate(self, prompt, duration=10.0, model_size="small"):
        """Generate music from a text description."""
        model = self._load_model(model_size)

        sample_rate = 32000

        if hasattr(model, "generate_music"):
            # MLX native path
            audio_array = model.generate_music(prompt, duration=duration)
            sample_rate = getattr(model, "sample_rate", 32000)
        else:
            # Transformers path
            inputs = self._processor(
                text=[prompt],
                padding=True,
                return_tensors="pt",
            )
            max_tokens = int(duration * 50)  # ~50 tokens per second for MusicGen
            audio_values = model.generate(**inputs, max_new_tokens=max_tokens)
            audio_array = audio_values[0, 0].cpu().numpy()

        wav_bytes = self._array_to_wav(audio_array, sample_rate)
        b64 = base64.b64encode(wav_bytes).decode("utf-8")

        actual_duration = len(audio_array) / sample_rate

        return {
            "audio": b64,
            "sample_rate": sample_rate,
            "duration": actual_duration,
        }

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
