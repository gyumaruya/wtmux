#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  check-sensitive-changes.sh --staged
  check-sensitive-changes.sh --log-opts <git-log-opt>...
EOF
  exit 2
}

regex_escape() {
  printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\/]/\\&/g'
}

collect_added_lines() {
  if [[ "$mode" == "staged" ]]; then
    git diff --cached --no-ext-diff --no-color --text --unified=0
  else
    git log --format= --patch --unified=0 "${log_opts[@]}"
  fi | awk '
    /^diff --git / { file = ""; next }
    /^\+\+\+ b\// { file = substr($0, 7); next }
    /^@@ / { next }
    /^\+/ && $0 !~ /^\+\+\+/ && file != "" {
      print file "\t" substr($0, 2)
    }
  '
}

record_failure() {
  printf '%s|%s\n' "$1" "$2" >> "$findings_file"
}

add_sensitive_term() {
  local term="$1"
  local existing

  [[ -n "$term" ]] || return 0
  for existing in "${sensitive_terms[@]+"${sensitive_terms[@]}"}"; do
    if [[ "$existing" == "$term" ]]; then
      return 0
    fi
  done

  sensitive_terms+=("$term")
}

scan_for_fixed_patterns() {
  local file="$1"
  local line="$2"

  if printf '%s\n' "$line" | grep -Eq '([A-Z0-9]{5}-){4}[A-Z0-9]{5}'; then
    record_failure "$file" "windows-product-key"
  fi

  if printf '%s\n' "$line" | grep -Eq '\b((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\b'; then
    record_failure "$file" "ip-address"
  fi

  if printf '%s\n' "$line" | grep -Eq '/Users/[^/[:space:]]+'; then # sensitive-scan:allow
    record_failure "$file" "macos-home-path"
  fi

  if printf '%s\n' "$line" | grep -Eq '[A-Za-z]:\\\\Users\\\\[^\\\\/:*?"<>|[:space:]]+'; then # sensitive-scan:allow
    record_failure "$file" "windows-home-path"
  fi

  if printf '%s\n' "$line" | grep -Eq '[A-Za-z]:/Users/[^/[:space:]]+'; then # sensitive-scan:allow
    record_failure "$file" "windows-home-path"
  fi
}

scan_for_local_terms() {
  local file="$1"
  local line="$2"
  local term escaped

  for term in "${sensitive_terms[@]}"; do
    escaped="$(regex_escape "$term")"
    if printf '%s\n' "$line" | grep -Eq "(^|[^[:alnum:]_])${escaped}([^[:alnum:]_]|$)"; then
      record_failure "$file" "local-sensitive-term:${term}"
    fi
  done
}

mode=""
log_opts=()

case "${1:-}" in
  --staged)
    mode="staged"
    shift
    ;;
  --log-opts)
    mode="log"
    shift
    (($# > 0)) || usage
    log_opts=("$@")
    ;;
  *)
    usage
    ;;
esac

declare -a sensitive_terms=()
findings_file="$(mktemp)"
trap 'rm -f "$findings_file"' EXIT

if current_user="$(id -un 2>/dev/null)"; then
  add_sensitive_term "$current_user"
fi

home_name="$(basename "${HOME:-}" 2>/dev/null || true)"
add_sensitive_term "$home_name"

while IFS= read -r term; do
  add_sensitive_term "$term"
done < <(git config --local --get-all codex.sensitiveTerm || true)

while IFS=$'\t' read -r file line; do
  [[ -n "${file:-}" ]] || continue
  if [[ "$line" == *"sensitive-scan:allow"* ]]; then
    continue
  fi
  scan_for_fixed_patterns "$file" "$line"
  scan_for_local_terms "$file" "$line"
done < <(collect_added_lines)

if [[ ! -s "$findings_file" ]]; then
  exit 0
fi

echo "Sensitive content detected in changes." >&2
while IFS= read -r finding; do
  file="${finding%%|*}"
  rule="${finding#*|}"
  echo "  - ${file}: ${rule}" >&2
done < <(sort -u "$findings_file")

echo >&2
echo "Replace local paths, usernames, IPs, Windows keys, or other sensitive values with placeholders before committing or pushing." >&2
echo "Add extra local terms with: git config --local --add codex.sensitiveTerm <value>" >&2
exit 1
