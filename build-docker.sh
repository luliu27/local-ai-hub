#!/usr/bin/env bash
# Build all pi-sandbox Docker images.
#
# Usage:
#   ./build-docker.sh          # build both base and wiki
#   ./build-docker.sh base     # build only base
#   ./build-docker.sh wiki     # build only wiki
#   ./build-docker.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_BASE=true
BUILD_WIKI=true
NO_CACHE=false

for arg in "$@"; do
  case "$arg" in
    base)        BUILD_WIKI=false ;;
    wiki)        BUILD_BASE=false ;;
    --no-cache)  NO_CACHE=true ;;
    --help|-h)   echo "Usage: $0 [base|wiki] [--no-cache|--help]"; exit 0 ;;
    *)           echo "Usage: $0 [base|wiki] [--no-cache|--help]"; exit 1 ;;
  esac
done

if $BUILD_BASE; then
  echo "=== Building pi-sandbox:base ==="
  docker build ${NO_CACHE:+'--no-cache'} -f Dockerfile.pi.base -t pi-sandbox:base .
fi

if $BUILD_WIKI; then
  echo ""
  echo "=== Building pi-sandbox:wiki ==="
  docker build ${NO_CACHE:+'--no-cache'} -f Dockerfile.pi.wiki -t pi-sandbox:wiki .
fi

echo ""
echo "Done. Images:"
docker images pi-sandbox
