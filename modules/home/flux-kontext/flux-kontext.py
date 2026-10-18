"""FLUX.1 Kontext [dev] image editing: GGUF transformer + bf16 encoders, ROCm.

FLUX.1 Kontext [dev] is NON-COMMERCIAL (FLUX.1 [dev] Non-Commercial License).
"""
import argparse
import json
import os
import sys
import threading
import time
from pathlib import Path

HOME = Path(os.environ.get("FLUX_KONTEXT_HOME", "/mnt/nvme950/ai/flux-kontext"))
WEIGHTS = HOME / "weights"
BASE = WEIGHTS / "kontext-base"


def vram_used_bytes():
    total = 0
    for p in Path("/sys/class/drm").glob("card*/device/mem_info_vram_used"):
        try:
            total = max(total, int(p.read_text()))
        except OSError:
            pass
    return total


class VramSampler(threading.Thread):
    """Samples device-wide VRAM (includes the desktop and other apps)."""

    def __init__(self, interval=0.05):
        super().__init__(daemon=True)
        self.interval, self.peak, self._stop = interval, 0, threading.Event()

    def run(self):
        while not self._stop.is_set():
            self.peak = max(self.peak, vram_used_bytes())
            time.sleep(self.interval)

    def stop(self):
        self._stop.set()
        self.join()
        return self.peak


def load_pipeline(quant, prompt):
    """Encode the prompt once, drop the text encoders, then keep the transformer resident.

    T5 (9.5 GB) and the Q8 transformer (12.7 GB) never coexist in RAM or VRAM this way.
    """
    import gc
    import torch
    from diffusers import FluxKontextPipeline, FluxTransformer2DModel, GGUFQuantizationConfig

    pipe = FluxKontextPipeline.from_pretrained(str(BASE), transformer=None, dtype=torch.bfloat16)
    pipe.to("cuda")
    with torch.no_grad():
        embeds, pooled, _ = pipe.encode_prompt(prompt=prompt, prompt_2=None, device="cuda")
    pipe.text_encoder = pipe.text_encoder_2 = None
    gc.collect()
    torch.cuda.empty_cache()

    pipe.transformer = FluxTransformer2DModel.from_single_file(
        str(WEIGHTS / f"flux1-kontext-dev-{quant}.gguf"),
        quantization_config=GGUFQuantizationConfig(compute_dtype=torch.bfloat16),
        config=str(BASE),
        subfolder="transformer",
        dtype=torch.bfloat16,
    ).to("cuda")
    # Untiled VAE convs at 1024² need ~2.3 GB on top of the 13 GB transformer; tiling only kicks in above these.
    pipe.vae.enable_tiling()
    pipe.vae.tile_sample_min_size, pipe.vae.tile_latent_min_size = 512, 64
    return pipe, embeds, pooled


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-i", "--input", action="append", required=True, help="input image (repeatable)")
    ap.add_argument("-o", "--output", required=True, help="output file (one input) or directory")
    ap.add_argument("-p", "--prompt", required=True)
    ap.add_argument("--steps", type=int, default=28)
    ap.add_argument("--guidance", type=float, default=2.5)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--quant", default="Q8_0", help="GGUF quant file suffix in weights/")
    ap.add_argument("--keep-size", action="store_true",
                    help="keep Kontext's output resolution instead of resizing back to the input's")
    args = ap.parse_args()

    import torch
    from PIL import Image

    # MIOpen convs return NaN on gfx1201 (ROCm 7.2 wheels, even fp32) → black images; native conv is correct.
    torch.backends.cudnn.enabled = False

    out = Path(args.output)
    if len(args.input) > 1 or out.is_dir() or args.output.endswith("/"):
        out.mkdir(parents=True, exist_ok=True)
        targets = [out / (Path(i).stem + ".kontext.png") for i in args.input]
    else:
        out.parent.mkdir(parents=True, exist_ok=True)
        targets = [out]

    baseline = vram_used_bytes()
    t0 = time.perf_counter()
    pipe, embeds, pooled = load_pipeline(args.quant, args.prompt)
    load_s = time.perf_counter() - t0

    for src, dst in zip(args.input, targets):
        image = Image.open(src).convert("RGB")
        torch.cuda.reset_peak_memory_stats()
        sampler = VramSampler()
        sampler.start()
        t = time.perf_counter()
        result = pipe(
            image=image,
            prompt_embeds=embeds,
            pooled_prompt_embeds=pooled,
            guidance_scale=args.guidance,
            num_inference_steps=args.steps,
            generator=torch.Generator("cpu").manual_seed(args.seed),
        ).images[0]
        secs = time.perf_counter() - t
        peak = sampler.stop()
        gen_size = result.size
        if not args.keep_size and result.size != image.size:
            result = result.resize(image.size, Image.LANCZOS)
        result.save(dst)
        print(json.dumps({
            "input": src,
            "output": str(dst),
            "seconds": round(secs, 1),
            "load_seconds": round(load_s, 1),
            "generated_size": gen_size,
            "torch_peak_reserved_gib": round(torch.cuda.max_memory_reserved() / 2**30, 2),
            "device_vram_peak_gib": round(peak / 2**30, 2),
            "device_vram_baseline_gib": round(baseline / 2**30, 2),
        }), flush=True)


if __name__ == "__main__":
    sys.exit(main())
