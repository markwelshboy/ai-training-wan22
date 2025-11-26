#!/usr/bin/env bash
set -euo pipefail

log() { printf '[start_script] %s\n' "$*"; }

RUNTIME_REPO_URL="${RUNTIME_REPO_URL:-https://github.com/markwelshboy/pod-runtime.git}"
RUNTIME_DIR="${RUNTIME_DIR:-/workspace/pod-runtime}"

mkdir -p /workspace

clone_or_update() {
  local url="$1" dir="$2" name
  name="$(basename "$dir")"
  if [ -d "${dir}/.git" ]; then
    log "Updating ${name} in ${dir}..."
    git -C "${dir}" pull --rebase --autostash || \
      log "Warning: git pull failed for ${name}; continuing with existing checkout."
  else
    log "Cloning ${name} from ${url} into ${dir}..."
    rm -rf "${dir}"
    git clone --depth 1 "${url}" "${dir}"
  fi
}

clone_or_update "${RUNTIME_REPO_URL}" "${RUNTIME_DIR}"

cd "${RUNTIME_DIR}"

if [ ! -x ./start.training.sh ]; then
  log "Making start.training.sh executable..."
  chmod +x ./start.training.sh
fi

log "Handing off to pod-runtime/start.training.sh..."
exec ./start.training.sh "$@"