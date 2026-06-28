#!/usr/bin/env bash
# Usage: run-pi.sh --skills /path/to/skills
#
# Options:
#   --skills /path/to/skills    Mount a local skills directory into the container

set -euo pipefail

SKILLS_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --skills requires a path argument" >&2
        exit 1
      fi
      SKILLS_DIR="$2"
      shift 2
      ;;
    *)
      echo "Error: unknown argument '$1'. Usage: $0 --skills /path/to/skills" >&2
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
  -v ~/.pi/agent/docker-models.json:/root/.pi/agent/models.json
  -v ~/.pi/agent/auth.json:/root/.pi/agent/auth.json
  -v ~/.pi/agent/sessions:/root/.pi/agent/sessions
  -v "$PWD:/workspace"
)

CMD+=(pi-sandbox)

echo "Running: ${CMD[*]}"
exec "${CMD[@]}"
