#!/usr/bin/env bash
set -euo pipefail

# Repo that holds .env.training, helpers.sh, start.training.sh
RUNTIME_REPO_URL="${RUNTIME_REPO_URL:-https://github.com/markwelshboy/pod-runtime.git}"
RUNTIME_DIR="${RUNTIME_DIR:-/workspace/pod-runtime}"

mkdir -p /workspace

if [ -d "$RUNTIME_DIR/.git" ]; then
  echo "[start_script] Updating runtime repo in $RUNTIME_DIR..."
  git -C "$RUNTIME_DIR" pull --rebase --autostash || true
else
  echo "[start_script] Cloning runtime repo into $RUNTIME_DIR..."
  git clone --depth 1 "$RUNTIME_REPO_URL" "$RUNTIME_DIR"
fi

cd "$RUNTIME_DIR"

if [ ! -x ./start.training.sh ]; then
  chmod +x ./srart.training.sh
fi

echo "[start_script] Handing off to runtime start.training.sh..."
exec ./start.training.sh
