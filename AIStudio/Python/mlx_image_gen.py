"""
MLX Image Generation
Uses diffusionkit or mflux for local Stable Diffusion on Apple Silicon.
"""

import base64
import io
import os
import random

try:
    import mlx.core as mx
except ImportError:
    mx = None


class MLXImageGenerator:
    def __init__(self):
        self._pipeline = None
        self._model_name = None

    def _load_pipeline(self, model_name="stable-diffusion"):
        """Lazy-load the diffusion pipeline."""
        if self._pipeline is not None and self._model_name == model_name:
            return self._pipeline

        try:
            from diffusionkit import DiffusionPipeline
            self._pipeline = DiffusionPipeline.from_pretrained(model_name)
            self._model_name = model_name
        except ImportError:
            try:
                from mflux import Flux1
                self._pipeline = Flux1(model_name=model_name)
                self._model_name = model_name
            except ImportError:
                raise RuntimeError(
                    "No MLX diffusion library found. Install diffusionkit or mflux:\n"
                    "  pip install diffusionkit\n"
                    "  pip install mflux"
                )

        return self._pipeline

    def generate(self, prompt, negative_prompt="", steps=20, cfg_scale=7.0,
                 width=512, height=512, seed=-1):
        """Generate image from text prompt."""
        pipeline = self._load_pipeline()

        if seed == -1:
            seed = random.randint(0, 2**31 - 1)

        # Generate
        image = pipeline(
            prompt=prompt,
            negative_prompt=negative_prompt,
            num_inference_steps=steps,
            guidance_scale=cfg_scale,
            width=width,
            height=height,
            seed=seed,
        )

        # Convert to base64 PNG
        buf = io.BytesIO()
        image.save(buf, format="PNG")
        b64 = base64.b64encode(buf.getvalue()).decode("utf-8")

        return {
            "images": [b64],
            "seed": seed,
        }

    def img2img(self, prompt, init_image, denoising_strength=0.75,
                steps=20, cfg_scale=7.0, seed=-1):
        """Generate image from existing image + prompt."""
        pipeline = self._load_pipeline()

        if seed == -1:
            seed = random.randint(0, 2**31 - 1)

        # Decode init image
        from PIL import Image
        init_data = base64.b64decode(init_image)
        init_img = Image.open(io.BytesIO(init_data))

        image = pipeline(
            prompt=prompt,
            image=init_img,
            strength=denoising_strength,
            num_inference_steps=steps,
            guidance_scale=cfg_scale,
            seed=seed,
        )

        buf = io.BytesIO()
        image.save(buf, format="PNG")
        b64 = base64.b64encode(buf.getvalue()).decode("utf-8")

        return {
            "images": [b64],
            "seed": seed,
        }

    def list_models(self):
        """List available local models."""
        models = []
        # Check common model directories
        for path in [
            os.path.expanduser("~/.cache/huggingface/hub"),
            os.path.expanduser("~/models"),
        ]:
            if os.path.isdir(path):
                for item in os.listdir(path):
                    if "diffusion" in item.lower() or "flux" in item.lower() or "sd" in item.lower():
                        models.append({"name": item, "path": os.path.join(path, item)})

        return models
