"""
MLX Voice Cloning
Uses f5-tts-mlx for reference-based voice cloning on Apple Silicon.
"""

import base64
import io
import time
import numpy as np


class MLXVoiceClone:
    def __init__(self):
        pass

    def clone(self, text, reference_audio, speed=1.0):
        """Clone a voice from reference audio and generate speech."""
        try:
            from f5_tts_mlx.generate import generate as f5_generate
        except ImportError:
            raise RuntimeError(
                "f5-tts-mlx not available. Install it:\n"
                "  pip install f5-tts-mlx"
            )

        import tempfile
        import os

        start = time.time()

        # Generate to a temp file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp_path = tmp.name

        try:
            f5_generate(
                generation_text=text,
                ref_audio_path=reference_audio,
                speed=speed,
                output_path=tmp_path,
            )

            with open(tmp_path, "rb") as f:
                wav_bytes = f.read()
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

        elapsed = time.time() - start
        b64 = base64.b64encode(wav_bytes).decode("utf-8")

        # Estimate duration from WAV data (header is 44 bytes, 16-bit mono 24kHz)
        sample_rate = 24000
        data_size = max(len(wav_bytes) - 44, 0)
        duration = data_size / (sample_rate * 2)

        return {
            "audio": b64,
            "sample_rate": sample_rate,
            "duration": round(duration, 2),
            "generation_time": round(elapsed, 2),
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
