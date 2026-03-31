#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

git config --local core.hooksPath .githooks

current_user="$(id -un)"
if ! git config --local --get-all codex.sensitiveTerm | grep -Fxq "$current_user"; then
  git config --local --add codex.sensitiveTerm "$current_user"
fi

home_name="$(basename "${HOME:-}")"
if [[ -n "$home_name" ]] && ! git config --local --get-all codex.sensitiveTerm | grep -Fxq "$home_name"; then
  git config --local --add codex.sensitiveTerm "$home_name"
fi

echo "Installed repo-local hooks via core.hooksPath=.githooks"
echo "Sensitive terms configured:"
git config --local --get-all codex.sensitiveTerm || true
