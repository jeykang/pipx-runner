#!/usr/bin/env bash
set -Eeuo pipefail

# Defaults (can be overridden at runtime)
: "${PIPX_HOME:=/opt/pipx}"
: "${PIPX_BIN_DIR:=/usr/local/bin}"
: "${PIPX_PACKAGES:=}"
: "${PIPX_PACKAGES_FILE:=}"
: "${PIPX_FORCE:=1}"                 # if "1", pipx install uses --force to upgrade to requested version
: "${PIPX_INSTALL_ARGS:=}"           # extra args to `pipx install` (e.g., --python python3.12)
: "${PIPX_PIP_ARGS:=}"               # extra args to pip (e.g., "--index-url https://mirror/simple")

# If we cannot write to the configured bin dir (e.g., running as non-root), fall back to ~/.local/bin
if ! (mkdir -p "${PIPX_BIN_DIR}" && test -w "${PIPX_BIN_DIR}"); then
  export PIPX_BIN_DIR="${HOME}/.local/bin"
  mkdir -p "${PIPX_BIN_DIR}"
  export PATH="${PIPX_BIN_DIR}:${PATH}"
fi

# Normalize input list into an array (supports spaces, commas, or newlines)
packages=()

if [[ -n "${PIPX_PACKAGES}" ]]; then
  # Convert commas/newlines to spaces, then read as array
  mapfile -t _from_env < <(printf '%s' "${PIPX_PACKAGES}" | tr ',\n' '  ' | xargs -n1 printf '%s\n')
  packages+=("${_from_env[@]}")
fi

if [[ -n "${PIPX_PACKAGES_FILE}" && -f "${PIPX_PACKAGES_FILE}" ]]; then
  while IFS= read -r line; do
    # skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    packages+=("$line")
  done < "${PIPX_PACKAGES_FILE}"
fi

# Dedupe while preserving order
declare -A seen=()
unique_packages=()
for p in "${packages[@]}"; do
  [[ -z "${p}" ]] && continue
  if [[ -z "${seen[$p]:-}" ]]; then
    unique_packages+=("$p")
    seen[$p]=1
  fi
done

if [[ "${#unique_packages[@]}" -gt 0 ]]; then
  echo "[pipx-runner] Installing ${#unique_packages[@]} package(s) via pipx..."
  # Build optional arg arrays safely
  install_args=()
  [[ -n "${PIPX_INSTALL_ARGS}" ]] && install_args+=(${PIPX_INSTALL_ARGS})
  pip_args=()
  [[ -n "${PIPX_PIP_ARGS}" ]] && pip_args+=(--pip-args "${PIPX_PIP_ARGS}")

  for spec in "${unique_packages[@]}"; do
    if [[ "${PIPX_FORCE}" == "1" ]]; then
      pipx install "${install_args[@]}" "${pip_args[@]}" --force "${spec}"
    else
      pipx install "${install_args[@]}" "${pip_args[@]}" "${spec}"
    fi
  done
fi

# Helpful debug
echo "[pipx-runner] PATH=${PATH}"
pipx --version || true

# If no command provided, give an interactive shell; otherwise exec the requested command
if [[ "$#" -eq 0 ]]; then
  exec bash
else
  exec "$@"
fi
