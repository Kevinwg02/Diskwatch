#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
#  DiskWatch Dev Launcher
#  Usage:
#    ./dev.sh build    → build the Docker image
#    ./dev.sh run      → enter the dev container shell
#    ./dev.sh watch    → run DiskWatch directly (no shell)
#    ./dev.sh clean    → remove the container & image
# ─────────────────────────────────────────────────────────

set -euo pipefail

CMD="${1:-run}"

case "$CMD" in
  build)
    echo "🔨 Building DiskWatch dev image..."
    docker compose build
    echo "✅ Done. Run './dev.sh run' to enter the container."
    ;;

  run)
    echo "🐳 Entering DiskWatch dev container..."
    echo "   Inside the container, type:  python diskwatch.py"
    docker compose run --rm diskwatch-dev /bin/bash
    ;;

  watch)
    echo "🚀 Launching DiskWatch inside Docker..."
    docker compose run --rm diskwatch-dev python diskwatch.py
    ;;

  clean)
    echo "🧹 Cleaning up containers and image..."
    docker compose down --rmi local --volumes --remove-orphans 2>/dev/null || true
    echo "✅ Clean."
    ;;

  *)
    echo "Usage: $0 {build|run|watch|clean}"
    exit 1
    ;;
esac
