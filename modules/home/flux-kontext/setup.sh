# Rebuilds the venv and fetches the weights; safe to rerun (aria2 resumes, uv skips what's installed).
set -euo pipefail
cd "$FLUX_KONTEXT_HOME" 2>/dev/null || { mkdir -p "$FLUX_KONTEXT_HOME"; cd "$FLUX_KONTEXT_HOME"; }

[ -x venv/bin/python ] || uv venv --python "$FLUX_PYTHON" venv
VIRTUAL_ENV="$PWD/venv" uv pip install --index-strategy unsafe-best-match -r "$FLUX_REQUIREMENTS"

# The GGUF transformer is ungated; the encoders/VAE/configs need the HF licence click + `hf auth login`.
token_file="${HF_TOKEN_PATH:-$HOME/.cache/huggingface/token}"
[ -r "$token_file" ] || { echo "no HF token at $token_file: accept the licence on huggingface.co/black-forest-labs/FLUX.1-Kontext-dev, then hf auth login" >&2; exit 1; }

mkdir -p weights/kontext-base
aria2c -c -x16 -s16 -k8M --summary-interval=0 --console-log-level=warn -d weights \
  -o flux1-kontext-dev-Q8_0.gguf \
  https://huggingface.co/QuantStack/FLUX.1-Kontext-dev-GGUF/resolve/main/flux1-kontext-dev-Q8_0.gguf

base=https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev/resolve/main
list=$(mktemp)
for f in model_index.json LICENSE.md scheduler/scheduler_config.json \
  vae/config.json vae/diffusion_pytorch_model.safetensors \
  text_encoder/config.json text_encoder/model.safetensors \
  text_encoder_2/config.json text_encoder_2/model.safetensors.index.json \
  text_encoder_2/model-00001-of-00002.safetensors text_encoder_2/model-00002-of-00002.safetensors \
  tokenizer/merges.txt tokenizer/special_tokens_map.json tokenizer/tokenizer_config.json tokenizer/vocab.json \
  tokenizer_2/special_tokens_map.json tokenizer_2/spiece.model tokenizer_2/tokenizer.json tokenizer_2/tokenizer_config.json \
  transformer/config.json; do
  printf '%s/%s\n  dir=%s\n  out=%s\n' "$base" "$f" "$PWD/weights/kontext-base/$(dirname "$f")" "$(basename "$f")" >> "$list"
done
aria2c -c -j2 -x8 -s8 -k8M --summary-interval=0 --console-log-level=warn \
  --header="Authorization: Bearer $(cat "$token_file")" -i "$list"
rm -f "$list"
echo "flux-kontext ready in $FLUX_KONTEXT_HOME"
