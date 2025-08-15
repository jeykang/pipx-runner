#!/usr/bin/env bash
set -Eeuo pipefail

# Defaults (can be overridden at runtime)
: "${PIPX_HOME:=/opt/pipx}"
: "${PIPX_BIN_DIR:=/usr/local/bin}"
: "${PIPX_PACKAGES:=}"      # whitespace/newline-separated list ONLY
: "${PIPX_PACKAGES_FILE:=}" # path inside container, newline-separated (comments ok)
: "${PIPX_FORCE:=1}"
: "${PIPX_INSTALL_ARGS:=}"  # e.g., --python python3.12
: "${PIPX_PIP_ARGS:=}"      # e.g., --index-url https://mirror/simple

# If we cannot write to the configured bin dir (e.g., running as non-root), fall back to ~/.local/bin
if ! (mkdir -p "${PIPX_BIN_DIR}" && test -w "${PIPX_BIN_DIR}"); then
  export PIPX_BIN_DIR="${HOME}/.local/bin"
  mkdir -p "${PIPX_BIN_DIR}"
  export PATH="${PIPX_BIN_DIR}:${PATH}"
fi

# Collect packages from env and/or file
packages=()

# NOTE: We intentionally split ONLY on whitespace/newlines to preserve commas in
# PEP 508 extras (pkg[foo,bar]) and version ranges (>=1.0,<2).
if [[ -n "${PIPX_PACKAGES}" ]]; then
  # Use default IFS (space, tab, newline) to split into an array
  # shellcheck disable=SC2206 # we want word splitting here by design
  from_env=( ${PIPX_PACKAGES} )
  packages+=("${from_env[@]}")
fi

if [[ -n "${PIPX_PACKAGES_FILE}" && -f "${PIPX_PACKAGES_FILE}" ]]; then
  while IFS= read -r line; do
    # Trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    # skip empty or comment lines
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    packages+=("$line")
  done < "${PIPX_PACKAGES_FILE}"
fi

# Dedupe while preserving order
declare -A seen=()
unique_packages=()
for p in "${packages[@]:-}"; do
  [[ -z "${p}" ]] && continue
  if [[ -z "${seen[$p]:-}" ]]; then
    unique_packages+=("$p")
    seen[$p]=1
  fi
done

if [[ "${#unique_packages[@]}" -gt 0 ]]; then
  echo "[pipx-runner] Installing ${#unique_packages[@]} package(s) via pipx..."
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

echo "[pipx-runner] PATH=${PATH}"
pipx --version || true

if [[ "$#" -eq 0 ]]; then
  exec bash
else
  exec "$@"
fi
