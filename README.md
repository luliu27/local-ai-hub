# Local AI Hub

Local model management via llama-swap with opencode integration, Docker sandbox, and custom skills.

## Project Structure

```
├── configs/            # llama-swap & opencode configuration
│   ├── llama-swap-config.yaml
│   ├── opencode.jsonc
│   └── pi-docker-models.json
├── logs/               # llama-swap access/runtime logs
├── skills/             # Custom pi-coding-agent skills
│   └── web-to-epub/
├── Dockerfile.pi.base     # lean base image (pi-coding-agent + core tools)
├── Dockerfile.pi.coding   # base + pi-subagents + RTK
├── Dockerfile.pi.wiki     # base + pi-llm-wiki
├── Dockerfile.pi.learn    # base + opencode-engram-learning
├── llamaswap.sh        # llama-swap proxy lifecycle script
├── run-pi.sh           # Docker sandbox launcher with --auth, --sessions, --skills, --model-conf, and --learning options
├── .gitignore
└── README.md
```

## Llama-Swap & Configs

`llamaswap.sh` manages the [llama-swap](https://github.com/jeffrey-lam/llama-swap) proxy server, which runs local llama-server models on demand and swaps between them automatically.

### Usage

```bash
./llamaswap.sh {start|stop|restart|status}
```

- **start** — Launch llama-swap proxy on `localhost:1235`
- **stop** — Kill the running proxy
- **restart** — Stop then start
- **status** — Check if proxy is running

### Configuration

| File | Purpose |
|------|---------|
| `configs/llama-swap-config.yaml` | Model definitions, groups, macros, and llama-server launch commands |
| `configs/opencode.jsonc` | Opencode provider config pointing to the proxy at `127.0.0.1:1235/v1`, lists available models for opencode |
| `configs/pi-docker-models.json` | Docker sandbox model provider config (default model selection) |

**Global macros:**

| Macro | Value | Purpose |
|-------|-------|---------|
| `default_ctx` | 120000 | Context window size |
| `threads` | 8 | CPU threads for llama-server |
| `cache_prompt` | `--cache-prompt` | Prompt caching flag |
| `ub` | 512 | User buffer size |
| `repeat_penalty` | 1.0 | Repetition penalty |
| `presence_penalty` | 0.0 | Presence penalty |
| `jinja` | `--jinja` | Jinja template support (Qwen, DeepSeek) |

**Models configured:**

| Model | Hugging Face | Group | Reasoning |
|-------|-------------|-------|-----------|
| qwen3.5-2b | unsloth/Qwen3.5-2B-GGUF:BF16 | always-on | off |
| qwen3.5-9b | unsloth/Qwen3.5-9B-GGUF:Q5_K_M | large-models | off |
| qwen3.6-27b | unsloth/Qwen3.6-27B-GGUF:UD-Q6_K_XL | large-models | off |
| qwen3.6-27b-thinking | unsloth/Qwen3.6-27B-GGUF:UD-Q6_K_XL | large-models | on |
| qwen3.6-27b-coding | unsloth/Qwen3.6-27B-GGUF:UD-Q6_K_XL | large-models | on |
| qwen3.6-35b-a3b-thinking-general | unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q6_K_XL | large-models | on |
| qwen3.6-35b-a3b-thinking-coding | unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q5_K_XL | large-models | on |
| qwen3.6-35b-a3b-instruct-general | unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q5_K_XL | large-models | off |
| qwen3.6-35b-a3b-instruct-reasoning | unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q5_K_XL | large-models | off |
| gemma4-12b | unsloth/gemma-4-12b-it-GGUF:UD-Q4_K_XL | large-models | off |
| gemma4-e4b | unsloth/gemma-4-E4B-it-GGUF:UD-Q4_K_XL | large-models | off |
| gemma4-26B-A4B-qat | unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL | large-models | on |
| gpt-oss-20b | unsloth/gpt-oss-20b-GGUF:F16 | large-models | — |

**Groups:**
- **always-on** — qwen3.5-2b (`persistent: true`, never swapped out, not exclusive)
- **large-models** — All other models (`swap: true`, `exclusive: true`, only one runs at a time, will unload the always-on model)

## Pi Sandbox Container

A self-contained [pi-coding-agent](https://github.com/earendil-works/pi-coding-agent) environment for running `pi` commands without installing it on the host.

### Building

```bash
# Build all images
./build-docker.sh

# Build individually
./build-docker.sh base      # pi-sandbox:base (lean)
./build-docker.sh coding    # pi-sandbox:coding (base + pi-subagents + RTK)
./build-docker.sh wiki      # pi-sandbox:wiki (base + pi-llm-wiki)
./build-docker.sh learn     # pi-sandbox:learn (base + opencode-engram-learning)
```

**Image hierarchy:**

| Image | Layers |
|-------|--------|
| `pi-sandbox:base` | `node:24-trixie-slim` + CLI tools (`git`, `ripgrep`, `fd-find`, `curl`) + `@earendil-works/pi-coding-agent` + `pi-venice` + `pi-web-access` |
| `pi-sandbox:coding` | Extends base + adds `pi-subagents` (multi-agent delegation) + [RTK](https://github.com/rtk-ai/rtk) (token-optimized command outputs) |
| `pi-sandbox:wiki`   | Extends base + adds `pi-llm-wiki` (persistent markdown wiki) |
| `pi-sandbox:learn`  | Extends base + adds `opencode-engram-learning` (FSRS spaced-repetition learning engine) |

**Base image `settings.json`:**

```jsonc
{
  "defaultProvider": "llamaswap",
  "defaultModel": "qwen3.6-35b-a3b-instruct-general",
  "defaultThinkingLevel": "medium",
  "packages": ["npm:pi-venice", "npm:pi-web-access"],
  "theme": "dark"
}
```

Each derived image appends its additional packages to the base settings at build time.

### Running

```bash
# Standard — mounts ~/.pi config + workspace as /workspace
./run-pi.sh
```

The container's `ENTRYPOINT` is `pi`, so everything runs as a pi session. Connects to the local llama-swap proxy at `127.0.0.1:1235/v1` by default.

#### Learning Mode

For dedicated learning sessions with persistent learning data, run the `learn` image, which always mounts the current directory at `/root/.claude/learning` (engram's state directory):

```bash
# Add to ~/.zshrc (or ~/.bashrc):
pi-learner() {
    "$HOME/workspace/projects/local-ai-hub/run-pi.sh" \
        --image learn \
        --model-conf "$HOME/workspace/projects/local-ai-hub/configs/pi-docker-models.json"
}

# Then:
source ~/.zshrc
cd /path/to/learning/project
pi-learner
```

The current directory is mounted as the learning data volume at `/root/.claude/learning` inside the container.

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--auth /path/to/auth.json` | `$HOME/.pi/agent/auth.json` | Path to API auth credentials |
| `--sessions /path/to/sessions` | `$HOME/.pi/agent/sessions` | Path to persistent session history |
| `--skills /path/to/skills` | _(none)_ | Mount external skills into the container |
| `--model-conf /path/to/model-config.json` | `$HOME/.pi/agent/docker-models.json` | Path to custom model configuration file |
| `--image base\|coding\|wiki\|learn` | `base` | Which pi-sandbox image to run; `learn` mounts `$PWD` at `/root/.claude/learning` for persistent learning data |

### Overriding Skills at Runtime

```bash
# Mount external skills into the container
./run-pi.sh --skills /path/to/skills
```

This symlinks each subdirectory under `/path/to/skills/` into `/root/.pi/agent/skills/`, allowing you to test or use custom skills without rebuilding the image.

### Overriding Auth or Sessions at Runtime

```bash
# Use a different auth file and sessions directory
./run-pi.sh --auth /custom/path/auth.json --sessions /custom/path/sessions
```

### Bind Mount Reference

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `--model-conf` (default: `$HOME/.pi/agent/docker-models.json`) | `/root/.pi/agent/models.json` | Model provider configuration (llamaswap) — override with custom config path |
| `$PWD/configs/pi-docker-models.json` | `/root/.pi/agent/models.json` | Model provider configuration (llamaswap, default) |
| `--auth` (default: `$HOME/.pi/agent/auth.json`) | `/root/.pi/agent/auth.json` | API auth credentials for provider access |
| `--sessions` (default: `$HOME/.pi/agent/sessions`) | `/root/.pi/agent/sessions` | Persistent pi session history across runs |
| `$PWD` | `/workspace` | Working directory — where `pi` operates |
| `learn` image (`$PWD`) | `/root/.claude/learning` | Learning data directory for persistent study materials (engram state) |

> **Note:** `settings.json` is baked into the image at build time. To change packages or provider defaults, rebuild the Dockerfile. Auth, model cache, and sessions are overridable via bind mounts.

## Skills

| Skill | Description |
|-------|-------------|
| `web-to-epub` | Convert blog posts, articles, and newsletter content from web URLs into clean EPUB files with embedded images for offline reading |
