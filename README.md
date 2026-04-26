# Local AI Hub

Local model management via llama-swap with opencode integration and custom skills.

## Llama-Swap & Configs

`llamaswap.sh` manages the [llama-swap](https://github.com/jeffrey-lam/llama-swap) proxy server, which runs local llama-server models on demand and swaps between them automatically.

### Usage

```bash
./llamaswap.sh {start|stop|restart|status}
```

- **start** — Launch llama-swap proxy on `0.0.0.0:1235`
- **stop** — Kill the running proxy
- **restart** — Stop then start
- **status** — Check if proxy is running

### Configuration

| File | Purpose |
|------|---------|
| `configs/llama-swap-config.yaml` | Model definitions, groups, and llama-server launch commands |
| `configs/opencode.jsonc` | Opencode provider config pointing to the proxy at `127.0.0.1:1235/v1` |

**Models configured:**

| Model | Hugging Face | Group |
|-------|-------------|-------|
| qwen3.5-2b | unsloth/Qwen3.5-2B-GGUF:BF16 | always-on |
| qwen3.5-9b | unsloth/Qwen3.5-9B-GGUF:Q5_K_M | large-models |
| qwen3.6-27b | unsloth/Qwen3.6-27B-GGUF:UD-Q4_K_XL | large-models |
| qwen3.6-27b-thinking | unsloth/Qwen3.6-27B-GGUF:UD-Q4_K_XL | large-models |
| qwen3.6-27b-coding | unsloth/Qwen3.6-27B-GGUF:UD-Q4_K_XL | large-models |
| qwen3.6-35b-a3b-thinking-general | unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q5_K_XL | large-models |
| qwen3.6-35b-a3b-thinking-coding | unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q5_K_XL | large-models |
| qwen3.6-35b-a3b-instruct-general | unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q5_K_XL | large-models |
| qwen3.6-35b-a3b-instruct-reasoning | unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q5_K_XL | large-models |
| gemma4-31b | unsloth/gemma-4-31B-it-GGUF:UD-Q4_K_XL | large-models |
| gemma4-e4b | unsloth/gemma-4-E4B-it-GGUF:UD-Q4_K_XL | large-models |
| gpt-oss-20b | unsloth/gpt-oss-20b-GGUF:F16 | large-models |

**Groups:**
- **always-on** — qwen3.5-2b (persistent, never swapped out)
- **large-models** — All other models (exclusive, only one runs at a time)

## Skills

| Skill | Description |
|-------|-------------|
| `web-to-epub` | Convert blog posts, articles, and newsletter content from web URLs into clean EPUB files |
