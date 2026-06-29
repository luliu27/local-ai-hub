#!/usr/bin/env bash
# Usage: run-pi.sh [--auth path/to/auth.json] [--sessions path/to/sessions] [--skills /path/to/skills]
#
# Options:
#   --auth     path/to/auth.json          Path to auth.json (default: ~/.pi/agent/auth.json)
#   --sessions path/to/sessions           Path to sessions directory (default: ~/.pi/agent/sessions)
#   --skills /path/to/skills             Mount a local skills directory into the container

set -euo pipefail

MODEL_CONFIG="$HOME/.pi/agent/docker-models.json"
AUTH_DIR="$HOME/.pi/agent/auth.json"
SESSIONS_DIR="$HOME/.pi/agent/sessions"
SKILLS_DIR=""

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
    *)
      echo "Error: unknown argument '$1'. Usage: $0 [--auth /path/to/auth.json] [--sessions /path/to/sessions] [--skills /path/to/skills]" >&2
      exit 1
      ;;
  esac
done

# Build the docker run command
CMD=(docker run -it --rm)

# Mount individual skill symlinks if --skills is specified
if [[ -n "$SKILLS_DIR" ]]; then
  if [[ ! -d "$SKILLS_DIR" ]]; then
    echo "Error: skills directory '$SKILLS_DIR' does not exist" >&2
    exit 1
  fi
  for skill_link in "$SKILLS_DIR"/*/; do
    # Skip if glob didn't match anything
    [[ -e "$skill_link" ]] || continue
    skill_target="$(readlink -f "$skill_link")"
    skill_name="$(basename "$skill_link")"
    CMD+=(-v "${skill_target}:/root/.pi/agent/skills/${skill_name}")
  done
fi

# Common bind mounts (from Dockerfile usage comments)
CMD+=(
  -v "${MODEL_CONFIG}:/root/.pi/agent/models.json"
  -v "${AUTH_DIR}:/root/.pi/agent/auth.json"
  -v "${SESSIONS_DIR}:/root/.pi/agent/sessions"
  -v "$PWD:/workspace"
)

CMD+=(pi-sandbox)

echo "Running: ${CMD[*]}"
exec "${CMD[@]}"
