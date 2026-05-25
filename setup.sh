#!/usr/bin/env bash

set -euo pipefail

auto_repos=("automol" "autostorage" "autoengine")
qc_repos=("qcdata" "qccodec" "qccompute")

USE_DETACHED_ENVS=false

while getopts "d" opt; do
  case "$opt" in
    d)
      USE_DETACHED_ENVS=true
      ;;
    *)
      echo "Usage: $0 [-d]"
      exit 1
      ;;
  esac
done

# Prompt for GitHub username, using git config user.name as the default
DEFAULT_GITHUB_USERNAME="$(git config user.name)"
if [[ -z "$DEFAULT_GITHUB_USERNAME" ]]; then
  read -rp "GitHub username: " GITHUB_USERNAME
else
  read -rp "GitHub username (default: ${DEFAULT_GITHUB_USERNAME}): " GITHUB_USERNAME
  GITHUB_USERNAME="${GITHUB_USERNAME:-$DEFAULT_GITHUB_USERNAME}"
fi

# --- Clone everything (idempotent) ---
for repo in "${auto_repos[@]}" "${qc_repos[@]}"; do
  if [[ -d "$repo" ]]; then
    echo "Skipping clone (already exists): $repo"
  else
    echo "Cloning $repo..."
    git clone "git@github.com:${GITHUB_USERNAME}/${repo}.git"
  fi
done

echo

# --- Configure qc* repos ---
for repo in "${qc_repos[@]}"; do
  echo "Configuring $repo..."
  (
    cd "$repo"

    git remote get-url upstream >/dev/null 2>&1 || \
      git remote add upstream "https://github.com/coltonbh/${repo}.git"
  )
done

echo

# --- Configure auto* repos ---
for repo in "${auto_repos[@]}"; do
  echo "Configuring $repo..."
  (
    cd "$repo"

    git remote get-url upstream >/dev/null 2>&1 || \
      git remote add upstream "git@github.com:avcopan/${repo}.git"

    if [[ "$USE_DETACHED_ENVS" == true ]]; then
      mkdir -p .pixi
      grep -qxF 'detached-environments = "/lscratch/'"$USER"'"' .pixi/config.toml 2>/dev/null || \
        echo "detached-environments = \"/lscratch/$USER\"" >> .pixi/config.toml

      mkdir -p .pixi_local_true
      grep -qxF 'detached-environments = "/lscratch/'"$USER"'/local"' .pixi_local_true/config.toml 2>/dev/null || \
        echo "detached-environments = \"/lscratch/$USER/local\"" >> .pixi_local_true/config.toml
    fi

    ./scripts/local.sh stop
    pixi install
    pixi install -e dev

    pixi run local start
    pixi install
    pixi install -e dev

    pixi run local stop
  )
done

echo "Done."
