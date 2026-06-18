#!/usr/bin/env bash
# Installs Weave into a Roblox / Rojo project.
# Usage: ./scripts/install-weave.sh [target-dir] [--mode wally|local|rbxm]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="wally"
TARGET=""
VERSION=""
PROJECT_FILE=""

usage() {
  cat <<'EOF'
Usage: install-weave.sh [OPTIONS] [TARGET_DIR]

  TARGET_DIR   Project to install into (default: current directory)

Options:
  --mode MODE       wally | local | rbxm  (default: wally)
  --version VER     Override package version (default: from wally.toml)
  --project FILE    Rojo project file (default: default.project.json)
  -h, --help        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --project)
      PROJECT_FILE="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

TARGET="${TARGET:-$(pwd)}"
TARGET="$(cd "$TARGET" && pwd)"

info() { echo "[weave] $*"; }
ok() { echo "[weave] $*"; }
warn() { echo "[weave] $*" >&2; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[weave] '$1' is not on PATH. Run 'aftman install' in the Weave repo." >&2
    exit 1
  fi
}

get_version() {
  if [[ -n "$VERSION" ]]; then
    echo "$VERSION"
    return
  fi
  grep -E '^version\s*=' "$REPO_ROOT/wally.toml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
}

relative_path() {
  python3 -c "import os, sys; print(os.path.relpath(sys.argv[2], sys.argv[1]).replace(os.sep, '/'))" "$1" "$2"
}

find_project_file() {
  if [[ -n "$PROJECT_FILE" ]]; then
    echo "$TARGET/$PROJECT_FILE"
    return
  fi
  if [[ -f "$TARGET/default.project.json" ]]; then
    echo "$TARGET/default.project.json"
    return
  fi
  local f
  f="$(find "$TARGET" -maxdepth 1 -name '*.project.json' -type f 2>/dev/null | head -1)"
  if [[ -n "$f" ]]; then
    echo "$f"
  fi
}

ensure_wally_toml() {
  local wally="$TARGET/wally.toml"
  if [[ ! -f "$wally" ]]; then
    info "Creating wally.toml"
    cat >"$wally" <<'TOML'
[package]
name = "owner/project"
version = "0.1.0"
realm = "shared"

[dependencies]
TOML
  fi
  echo "$wally"
}

set_wally_dependency() {
  local wally="$1"
  local dep_mode="$2"
  local ver="$3"
  local weave_line

  if [[ "$dep_mode" == "local" ]]; then
    local rel
    rel="$(relative_path "$TARGET" "$REPO_ROOT")"
    weave_line="Weave = { path = \"$rel\" }"
  else
    weave_line="Weave = \"kiddydevofficial/weave@^$ver\""
  fi

  if grep -qE '^\s*(Framework|Weave)\s*=' "$wally"; then
    sed -i.bak -E "s|^\s*(Framework|Weave)\s*=.*|$weave_line|" "$wally"
    rm -f "$wally.bak"
  elif grep -qE '^\s*\[dependencies\]' "$wally"; then
    sed -i.bak "/^\s*\[dependencies\]/a\\
$weave_line
" "$wally"
    rm -f "$wally.bak"
  else
    printf '\n[dependencies]\n%s\n' "$weave_line" >>"$wally"
  fi
}

patch_rojo_project() {
  local project="$1"
  shift
  require_cmd python3
  python3 "$REPO_ROOT/scripts/patch-rojo-project.py" "$project" "$@"
}

ensure_packages_json() {
  patch_rojo_project "$1" --packages
}

ensure_local_rojo_mount() {
  patch_rojo_project "$1" --weave-src "$REPO_ROOT/src/Weave"
}

install_wally() {
  local dep_mode="$1"
  local ver="$2"
  local wally
  wally="$(ensure_wally_toml)"
  set_wally_dependency "$wally" "$dep_mode" "$ver"

  local project
  project="$(find_project_file || true)"
  if [[ -n "${project:-}" && -f "$project" ]]; then
    ensure_packages_json "$project"
  else
    warn "No *.project.json found — add ReplicatedStorage.Packages yourself."
  fi

  require_cmd wally
  (cd "$TARGET" && wally install)
}

install_rbxm() {
  require_cmd rojo
  local built="$REPO_ROOT/weave.rbxm"
  (cd "$REPO_ROOT" && rojo build package.project.json -o weave.rbxm)
  mkdir -p "$TARGET/vendor"
  cp "$built" "$TARGET/vendor/weave.rbxm"
  ok "Copied to $TARGET/vendor/weave.rbxm"
  warn "Import: drag vendor/weave.rbxm into ReplicatedStorage in Studio."
}

VER="$(get_version)"
info "Target: $TARGET"
info "Mode: $MODE"
info "Weave version: $VER"

case "$MODE" in
  wally)
    install_wally wally "$VER"
    ok "Installed via Wally."
    echo '  local Weave = require(game:GetService("ReplicatedStorage").Packages.Weave)'
    ;;
  local)
    project="$(find_project_file || true)"
    if [[ -n "${project:-}" && -f "$project" ]]; then
      ensure_local_rojo_mount "$project"
      ok "Linked Weave source via Rojo (no Wally)."
      echo '  local Weave = require(game:GetService("ReplicatedStorage").Weave)'
    else
      install_wally local "$VER"
      ok "Installed via Wally path dependency (this repo)."
      echo '  local Weave = require(game:GetService("ReplicatedStorage").Packages.Weave)'
    fi
    ;;
  rbxm)
    install_rbxm
    ;;
  *)
    echo "Invalid mode: $MODE (use wally, local, or rbxm)" >&2
    exit 1
    ;;
esac
