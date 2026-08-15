#!/usr/bin/env bash
# Usage: run-pi.sh [--image base|coding|wiki|learn] [--auth path/to/auth.json] [--sessions path/to/sessions] [--skills /path/to/skills] [--model-conf path/to/model-config.json]
#
# Options:
#   --image        base|coding|wiki|learn     Which pi-sandbox image to run (default: base)
#                                             base: default, coding: dev tools, wiki: wiki, learn: learning
#   --auth         path/to/auth.json          Path to auth.json (default: ~/.pi/agent/auth.json)
#   --sessions     path/to/sessions           Path to sessions directory (default: ~/.pi/agent/sessions)
#   --skills       /path/to/skills             Mount a local skills directory into the container
#   --model-conf   path/to/model-config.json  Path to model config file (default: ~/.pi/agent/docker-models.json)
#
# The learn image always mounts $PWD at /root/.claude/learning for the learning extension.
#
# To set up a dedicated command for learning, add the following to your ~/.zshrc (or ~/.bashrc):
#
#   pi-docker() {
#       local img="${1:-base}"
#       shift
#       "$HOME/workspace/projects/local-ai-hub/run-pi.sh" \
#           --image "$img" \
#           --model-conf "$HOME/workspace/projects/local-ai-hub/configs/pi-docker-models.json"
#.          "$@"
#   }
#
# Then run: source ~/.zshrc (or ~/.bashrc)
# Usage: cd into a learning project directory and run: pi-docker learn
# another usage: pi-docker coding --skills $HOME/.agents/skills

set -euo pipefail

MODEL_CONFIG="$HOME/.pi/agent/docker-models.json"
AUTH_DIR="$HOME/.pi/agent/auth.json"
SESSIONS_DIR="$HOME/.pi/agent/sessions"
SKILLS_DIR=""
MODEL_CONF_PATH=""
IMAGE_TAG="base"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auth)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --auth requires a path argument" >&2
        exit 1
      fi
      AUTH_DIR="$2"
      shift 2
      ;;
    --sessions)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --sessions requires a path argument" >&2
        exit 1
      fi
      SESSIONS_DIR="$2"
      shift 2
      ;;
    --skills)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --skills requires a path argument" >&2
        exit 1
      fi
      SKILLS_DIR="$2"
      shift 2
      ;;
    --model-conf)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --model-conf requires a path argument" >&2
        exit 1
      fi
      MODEL_CONF_PATH="$2"
      shift 2
      ;;
    --image)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --image requires an argument (base|coding|wiki|learn)" >&2
        exit 1
      fi
      case "$2" in
        base|coding|wiki|learn) IMAGE_TAG="$2" ;;
        *) echo "Error: unknown image '$2'. Allowed: base, coding, wiki, learn" >&2; exit 1 ;;
      esac
      shift 2
      ;;
    *)
      echo "Error: unknown argument '$1'. Usage: $0 [--image base|coding|wiki|learn] [--auth /path/to/auth.json] [--sessions /path/to/sessions] [--skills /path/to/skills] [--model-conf /path/to/model-config.json]" >&2
      exit 1
      ;;
  esac
done

# Resolve paths to absolute paths
AUTH_DIR="$(readlink -f "$AUTH_DIR")"
SESSIONS_DIR="$(readlink -f "$SESSIONS_DIR")"
if [[ -n "$SKILLS_DIR" ]]; then
  SKILLS_DIR="$(readlink -f "$SKILLS_DIR")"
fi

# Determine model config file
if [[ -n "$MODEL_CONF_PATH" ]]; then
  MODEL_FILE="$(readlink -f "$MODEL_CONF_PATH")"
else
  MODEL_FILE="$(readlink -f "$MODEL_CONFIG")"
fi

# Validate existence of critical files/directories
if [[ ! -f "$AUTH_DIR" ]]; then
  echo "Error: Auth file '$AUTH_DIR' not found." >&2
  exit 1
fi

if [[ ! -d "$SESSIONS_DIR" ]]; then
  echo "Error: Sessions directory '$SESSIONS_DIR' not found." >&2
  exit 1
fi

if [[ ! -f "$MODEL_FILE" ]]; then
  echo "Error: Model config file '$MODEL_FILE' not found." >&2
  exit 1
fi

# Build the docker run command
CMD=(docker run -it --rm)

# Mount individual skill symlinks if --skills is specified
if [[ -n "$SKILLS_DIR" ]]; then
  for skill_link in "$SKILLS_DIR"/*/; do
    # Skip if glob didn't match anything
    [[ -e "$skill_link" ]] || continue
    skill_target="$(readlink -f "$skill_link")"
    skill_name="$(basename "$skill_link")"
    CMD+=(-v "${skill_target}:/root/.pi/agent/skills/${skill_name}")
  done
fi

# Common bind mounts
CMD+=(
  -v "${AUTH_DIR}:/root/.pi/agent/auth.json"
  -v "${SESSIONS_DIR}:/root/.pi/agent/sessions"
  -v "$PWD:/workspace"
  -v "${MODEL_FILE}:/root/.pi/agent/models.json"
)

# The learn image always mounts $PWD as the learning data directory
if [[ "$IMAGE_TAG" == "learn" ]]; then
  CMD+=(-v "$PWD:/root/.claude/learning")
fi

CMD+=("pi-sandbox:${IMAGE_TAG}")

echo "Running: ${CMD[*]}"
exec "${CMD[@]}"
