# Local AI Hub

Local model management via llama-swap with opencode integration, Docker sandbox, and custom skills.

## Project Structure

```
├── configs/            # llama-swap & opencode configuration
│   ├── llama-swap-config.yaml
│   └── opencode.jsonc
├── logs/               # llama-swap access/runtime logs
├── skills/             # Custom pi-coding-agent skills
│   └── web-to-epub/
├── Dockerfile.pi       # pi-sandbox container image definition
├── llamaswap.sh        # llama-swap proxy lifecycle script
├── run-pi.sh           # Docker sandbox launcher with --skills mount support
├── .gitignore
└── README.md
```

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

## Pi Sandbox Container

A self-contained [pi-coding-agent](https://github.com/earendil-works/pi-coding-agent) environment for running `pi` commands without installing it on the host.

### Building

```bash
docker build -f Dockerfile.pi -t pi-sandbox .
```

**What's baked in:**

| Layer | Details |
|-------|--------|
| Base | `node:24-trixie-slim` + CLI tools (`git`, `ripgrep`, `fd-find`, `curl`) |
| Core | `@earendil-works/pi-coding-agent` (global npm install) |
| Packages | `pi-venice` (image/video), `pi-subagents` (multi-agent delegation), `pi-web-access` (web search/fetch) |
| RTK | [Rust Token Killer](https://github.com/rtk-ai/rtk) — token-optimized bash command outputs, auto-initialized via `rtk init -g --agent pi` |

**Default pi config (`settings.json`):**

```jsonc
{
  "defaultProvider": "llamaswap",
  "defaultModel": "qwen3.6-35b-a3b-instruct-general",
  "defaultThinkingLevel": "medium",
  "packages": ["npm:pi-venice", "npm:pi-subagents", "npm:pi-web-access"],
  "theme": "dark"
}
```

### Running

```bash
# Standard — mounts ~/.pi config + workspace as /workspace
docker run -it --rm \
  -v ~/.pi/agent/docker-models.json:/root/.pi/agent/models.json \
  -v ~/.pi/agent/auth.json:/root/.pi/agent/auth.json \
  -v ~/.pi/agent/sessions:/root/.pi/agent/sessions \
  -v "$PWD:/workspace" \
  pi-sandbox
```

The container's `ENTRYPOINT` is `pi`, so everything runs as a pi session. Connects to the local llama-swap proxy at `127.0.0.1:1235/v1` by default.

### Overriding Skills at Runtime

```bash
# Mount external skills into the container
./run-pi.sh --skills /path/to/skills
```

This symlinks each subdirectory under `/path/to/skills/` into `/root/.pi/agent/skills/`, allowing you to test or use custom skills without rebuilding the image.

### Bind Mount Reference

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `~/.pi/agent/docker-models.json` | `/root/.pi/agent/models.json` | Hugging Face model cache index (read-only) |
| `~/.pi/agent/auth.json` | `/root/.pi/agent/auth.json` | API auth credentials for provider access |
| `~/.pi/agent/sessions` | `/root/.pi/agent/sessions` | Persistent pi session history across runs |
| `$PWD` | `/workspace` | Working directory — where `pi` operates |

> **Note:** `settings.json` is baked into the image at build time. To change packages or provider defaults, rebuild the Dockerfile. Auth, model cache, and sessions are overridable via bind mounts.

## Skills

| Skill | Description |
|-------|-------------|
| `web-to-epub` | Convert blog posts, articles, and newsletter content from web URLs into clean EPUB files with embedded images for offline reading |
