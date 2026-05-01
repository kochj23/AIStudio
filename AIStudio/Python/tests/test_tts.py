"""
Tests for mlx_tts.py — TTS engine configuration and WAV encoding.
Tests that don't require ML libraries use synthetic data.

Written by Jordan Koch.
"""

import sys
import os
import struct
import numpy as np
import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mlx_tts import MLXTTS, ENGINE_MODELS


class TestEngineModels:
    """Tests for the ENGINE_MODELS configuration dict."""

    def test_all_engines_defined(self):
        expected = {"kokoro", "dia", "chatterbox", "spark", "breeze", "outetts"}
        assert set(ENGINE_MODELS.keys()) == expected

    def test_model_paths_are_strings(self):
        for engine, path in ENGINE_MODELS.items():
            assert isinstance(path, str), f"{engine} model path is not a string"
            assert len(path) > 0, f"{engine} model path is empty"

    def test_model_paths_are_mlx_community(self):
        for engine, path in ENGINE_MODELS.items():
            assert "mlx-community/" in path, f"{engine} model not from mlx-community"


class TestVoiceListing:
    """Tests for voice listing."""

    def test_kokoro_voices(self):
        tts = MLXTTS()
        voices = tts.list_voices("kokoro")
        assert len(voices) == 11
        assert "af_heart" in voices
        assert "am_adam" in voices

    def test_non_kokoro_voices(self):
        tts = MLXTTS()
        voices = tts.list_voices("dia")
        assert voices == ["default"]

    def test_unknown_engine_voices(self):
        tts = MLXTTS()
        voices = tts.list_voices("nonexistent")
        assert voices == ["default"]


class TestWAVEncoding:
    """Tests for _array_to_wav — WAV file format correctness."""

    def test_wav_header_riff(self):
        tts = MLXTTS()
        audio = np.zeros(100, dtype=np.float32)
        wav = tts._array_to_wav(audio, 24000)
        assert wav[:4] == b"RIFF"

    def test_wav_header_wave(self):
        tts = MLXTTS()
        audio = np.zeros(100, dtype=np.float32)
        wav = tts._array_to_wav(audio, 24000)
        assert wav[8:12] == b"WAVE"

    def test_wav_header_fmt(self):
        tts = MLXTTS()
        audio = np.zeros(100, dtype=np.float32)
        wav = tts._array_to_wav(audio, 24000)
        assert wav[12:16] == b"fmt "

    def test_wav_sample_rate(self):
        tts = MLXTTS()
        audio = np.zeros(100, dtype=np.float32)
        wav = tts._array_to_wav(audio, 24000)
        # Sample rate is at offset 24 (little-endian uint32)
        sr = struct.unpack_from("<I", wav, 24)[0]
        assert sr == 24000

    def test_wav_sample_rate_32k(self):
        tts = MLXTTS()
        audio = np.zeros(100, dtype=np.float32)
        wav = tts._array_to_wav(audio, 32000)
        sr = struct.unpack_from("<I", wav, 24)[0]
        assert sr == 32000

    def test_wav_data_chunk(self):
        tts = MLXTTS()
        audio = np.zeros(100, dtype=np.float32)
        wav = tts._array_to_wav(audio, 24000)
        assert b"data" in wav

    def test_wav_data_size(self):
        tts = MLXTTS()
        num_samples = 100
        audio = np.zeros(num_samples, dtype=np.float32)
        wav = tts._array_to_wav(audio, 24000)
        # Data size should be num_samples * 2 (16-bit = 2 bytes per sample)
        data_offset = wav.index(b"data") + 4
        data_size = struct.unpack_from("<I", wav, data_offset)[0]
        assert data_size == num_samples * 2

    def test_wav_normalization(self):
        """Audio values > 1.0 should be normalized."""
        tts = MLXTTS()
        audio = np.array([2.0, -2.0, 1.0, 0.0], dtype=np.float32)
        wav = tts._array_to_wav(audio, 24000)
        # Should not crash and produce valid WAV
        assert wav[:4] == b"RIFF"

    def test_wav_empty_audio(self):
        tts = MLXTTS()
        audio = np.array([], dtype=np.float32)
        wav = tts._array_to_wav(audio, 24000)
        assert wav[:4] == b"RIFF"

    def test_wav_pcm_format(self):
        """WAV should use PCM format (format code 1)."""
        tts = MLXTTS()
        audio = np.zeros(10, dtype=np.float32)
        wav = tts._array_to_wav(audio, 24000)
        # Format code is at offset 20 (uint16)
        fmt_code = struct.unpack_from("<H", wav, 20)[0]
        assert fmt_code == 1, "WAV format should be PCM (1)"

    def test_wav_mono_channel(self):
        """WAV should be mono (1 channel)."""
        tts = MLXTTS()
        audio = np.zeros(10, dtype=np.float32)
        wav = tts._array_to_wav(audio, 24000)
        channels = struct.unpack_from("<H", wav, 22)[0]
        assert channels == 1

    def test_wav_16bit(self):
        """WAV should be 16-bit."""
        tts = MLXTTS()
        audio = np.zeros(10, dtype=np.float32)
        wav = tts._array_to_wav(audio, 24000)
        bits = struct.unpack_from("<H", wav, 34)[0]
        assert bits == 16


class TestTTSInit:
    """Tests for MLXTTS initialization."""

    def test_init_empty_models(self):
        tts = MLXTTS()
        assert len(tts._models) == 0

    def test_unknown_engine_not_in_models(self):
        """Unknown engines should not appear in ENGINE_MODELS."""
        assert "nonexistent_engine" not in ENGINE_MODELS

    def test_load_model_checks_mlx_audio(self):
        """Verify _load_model imports mlx_audio.tts."""
        import inspect
        source = inspect.getsource(MLXTTS._load_model)
        assert "mlx_audio" in source
