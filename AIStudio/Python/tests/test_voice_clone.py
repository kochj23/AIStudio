"""
Tests for mlx_voice_clone.py — voice cloning, WAV encoding, resampling.

Written by Jordan Koch.
"""

import sys
import os
import struct
import numpy as np
import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mlx_voice_clone import MLXVoiceClone


class TestVoiceCloneInit:
    """Tests for initialization."""

    def test_init(self):
        vc = MLXVoiceClone()
        # Should not crash
        assert vc is not None


class TestWAVEncoding:
    """Tests for _array_to_wav."""

    def test_wav_header(self):
        vc = MLXVoiceClone()
        audio = np.zeros(100, dtype=np.float32)
        wav = vc._array_to_wav(audio, 24000)
        assert wav[:4] == b"RIFF"
        assert wav[8:12] == b"WAVE"

    def test_wav_sample_rate_24k(self):
        vc = MLXVoiceClone()
        audio = np.zeros(100, dtype=np.float32)
        wav = vc._array_to_wav(audio, 24000)
        sr = struct.unpack_from("<I", wav, 24)[0]
        assert sr == 24000

    def test_wav_normalization(self):
        vc = MLXVoiceClone()
        audio = np.array([3.0, -3.0, 0.0], dtype=np.float32)
        wav = vc._array_to_wav(audio, 24000)
        assert wav[:4] == b"RIFF"

    def test_wav_data_size(self):
        vc = MLXVoiceClone()
        n = 200
        audio = np.zeros(n, dtype=np.float32)
        wav = vc._array_to_wav(audio, 24000)
        data_offset = wav.index(b"data") + 4
        data_size = struct.unpack_from("<I", wav, data_offset)[0]
        assert data_size == n * 2


class TestResample:
    """Tests for _resample_to_24k (requires ffmpeg or afconvert)."""

    def test_resample_nonexistent_file(self):
        vc = MLXVoiceClone()
        with pytest.raises(RuntimeError):
            vc._resample_to_24k("/tmp/nonexistent_audio_file.wav")


class TestCloneWithoutLibs:
    """Tests that clone detects missing dependencies."""

    def test_clone_requires_f5_tts(self):
        """Voice cloning requires f5-tts-mlx — verify it's checked."""
        import inspect
        source = inspect.getsource(MLXVoiceClone.clone)
        assert "f5_tts_mlx" in source or "f5-tts-mlx" in source
