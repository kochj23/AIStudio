"""
MLX Voice Cloning
Uses f5-tts-mlx for reference-based voice cloning on Apple Silicon.
"""

import base64
import io
import numpy as np


class MLXVoiceClone:
    def __init__(self):
        self._model = None

    def _load_model(self):
        if self._model is not None:
            return self._model

        try:
            from f5_tts_mlx import F5TTS
            self._model = F5TTS()
        except ImportError:
            raise RuntimeError(
                "f5-tts-mlx not available. Install it:\n"
                "  pip install f5-tts-mlx"
            )

        return self._model

    def clone(self, text, reference_audio, speed=1.0):
        """Clone a voice from reference audio and generate speech."""
        model = self._load_model()

        audio_array = model.generate(
            text=text,
            ref_audio_path=reference_audio,
            speed=speed,
        )

        sample_rate = getattr(model, "sample_rate", 24000)
        wav_bytes = self._array_to_wav(audio_array, sample_rate)
        b64 = base64.b64encode(wav_bytes).decode("utf-8")

        duration = len(audio_array) / sample_rate

        return {
            "audio": b64,
            "sample_rate": sample_rate,
            "duration": duration,
        }

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
