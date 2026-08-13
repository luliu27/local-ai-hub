#!/usr/bin/env bash
# Build all pi-sandbox Docker images.
#
# Usage:
#   ./build-docker.sh                           # build all four
#   ./build-docker.sh base|coding|wiki|learn    # build only one
#   ./build-docker.sh --no-cache             # bypass Docker layer cache
#   ./build-docker.sh --help

set -euo pipefail
cd "$(dirname "$0")"

# Single source of truth for the image family.
# Change this one line to rename every image; the ARG flow propagates it.
IMAGE="pi-sandbox"
BASE_TAG="${IMAGE}:base"

BUILD_BASE=true
BUILD_CODING=true
BUILD_WIKI=true
BUILD_LEARN=true
NO_CACHE=false

for arg in "$@"; do
  case "$arg" in
    base)        BUILD_CODING=false; BUILD_WIKI=false; BUILD_LEARN=false ;;
    wiki)        BUILD_BASE=false; BUILD_CODING=false; BUILD_LEARN=false ;;
    coding)      BUILD_BASE=false; BUILD_WIKI=false; BUILD_LEARN=false ;;
    learn)       BUILD_BASE=false; BUILD_CODING=false; BUILD_WIKI=false ;;
    --no-cache)  NO_CACHE=true ;;
    --help|-h)   echo "Usage: $0 [base|coding|wiki|learn] [--no-cache|--help]"; exit 0 ;;
    *)           echo "Usage: $0 [base|coding|wiki|learn] [--no-cache|--help]"; exit 1 ;;
  esac
done

# Only add the flag when actually requested (${var:+} fires on any non-empty
# value, including the string "false", which would bust the cache every build).
# Plain string (not an array): empty-array expansion under `set -u` fails on
# bash < 4.4, and --no-cache contains no spaces so unquoted use is safe.
BUILD_OPTS=""
$NO_CACHE && BUILD_OPTS="--no-cache"

if $BUILD_BASE; then
  echo "=== Building ${BASE_TAG} ==="
  docker build $BUILD_OPTS -f Dockerfile.pi.base -t "$BASE_TAG" .
fi

if $BUILD_CODING; then
  echo ""
  echo "=== Building ${IMAGE}:coding ==="
  docker build $BUILD_OPTS \
    --build-arg BASE_IMAGE="$BASE_TAG" \
    -f Dockerfile.pi.coding -t "${IMAGE}:coding" .
fi

if $BUILD_WIKI; then
  echo ""
  echo "=== Building ${IMAGE}:wiki ==="
  docker build $BUILD_OPTS \
    --build-arg BASE_IMAGE="$BASE_TAG" \
    -f Dockerfile.pi.wiki -t "${IMAGE}:wiki" .
fi

if $BUILD_LEARN; then
  echo ""
  echo "=== Building ${IMAGE}:learn ==="
  docker build $BUILD_OPTS \
    --build-arg BASE_IMAGE="$BASE_TAG" \
    -f Dockerfile.pi.learn -t "${IMAGE}:learn" .
fi

echo ""
echo "Done. Images:"
docker images "$IMAGE"
