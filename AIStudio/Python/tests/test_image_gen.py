"""
Tests for mlx_image_gen.py — image generation, model listing.
Tests that don't require ML libraries test structure and list_models.

Written by Jordan Koch.
"""

import sys
import os
import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mlx_image_gen import MLXImageGenerator


class TestMLXImageGeneratorInit:
    """Tests for initialization."""

    def test_init_no_pipeline(self):
        gen = MLXImageGenerator()
        assert gen._pipeline is None
        assert gen._model_name is None


class TestModelListing:
    """Tests for list_models (does not require ML libraries)."""

    def test_list_models_returns_list(self):
        gen = MLXImageGenerator()
        models = gen.list_models()
        assert isinstance(models, list)

    def test_list_models_entries_have_name_and_path(self):
        gen = MLXImageGenerator()
        models = gen.list_models()
        for model in models:
            assert "name" in model
            assert "path" in model


class TestPipelineLoading:
    """Tests for pipeline loading behavior (may fail without ML libs)."""

    def test_load_pipeline_checks_dependencies(self):
        """Pipeline loading should check for diffusionkit/mflux."""
        import inspect
        source = inspect.getsource(MLXImageGenerator._load_pipeline)
        assert "diffusionkit" in source or "mflux" in source

    def test_pipeline_caching(self):
        """Pipeline should only load once for same model name."""
        gen = MLXImageGenerator()
        # Set a fake pipeline to test caching
        gen._pipeline = "fake_pipeline"
        gen._model_name = "test-model"
        result = gen._load_pipeline("test-model")
        assert result == "fake_pipeline"
