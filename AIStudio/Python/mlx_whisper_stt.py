"""
MLX Whisper Speech-to-Text
Uses mlx-whisper for local transcription on Apple Silicon.
"""


class MLXWhisperSTT:
    def __init__(self):
        self._model = None
        self._model_name = None

    def _load_model(self, model_name="base"):
        if self._model is not None and self._model_name == model_name:
            return self._model

        try:
            import mlx_whisper
            self._model = mlx_whisper
            self._model_name = model_name
        except ImportError:
            raise RuntimeError(
                "mlx-whisper not available. Install it:\n"
                "  pip install mlx-whisper"
            )

        return self._model

    def transcribe(self, audio_file, model="base", language=None):
        """Transcribe an audio file."""
        whisper = self._load_model(model)

        # Map model name to HuggingFace model ID
        model_map = {
            "tiny": "mlx-community/whisper-tiny-mlx",
            "base": "mlx-community/whisper-base-mlx",
            "small": "mlx-community/whisper-small-mlx",
            "medium": "mlx-community/whisper-medium-mlx",
            "large-v3": "mlx-community/whisper-large-v3-mlx",
        }

        model_id = model_map.get(model, f"mlx-community/whisper-{model}-mlx")

        kwargs = {
            "path_or_hf_repo": model_id,
        }
        if language:
            kwargs["language"] = language

        result = whisper.transcribe(audio_file, **kwargs)

        segments = []
        if "segments" in result:
            for seg in result["segments"]:
                segments.append({
                    "start": seg.get("start", 0),
                    "end": seg.get("end", 0),
                    "text": seg.get("text", ""),
                })

        return {
            "text": result.get("text", ""),
            "language": result.get("language", "unknown"),
            "segments": segments,
        }
