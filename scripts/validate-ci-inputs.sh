#!/usr/bin/env bash
set -euo pipefail

missing=()

if [[ -z "${TELEGRAM_IOS_BUILD_CONFIG_BASE64:-}" ]]; then
  missing+=("TELEGRAM_IOS_BUILD_CONFIG_BASE64")
fi

if [[ "${BUILD_MODE:-unsigned}" == "signed" && -z "${TELEGRAM_IOS_CODESIGNING_TAR_BASE64:-}" ]]; then
  missing+=("TELEGRAM_IOS_CODESIGNING_TAR_BASE64")
fi

if (( ${#missing[@]} > 0 )); then
  {
    echo "Missing required GitHub Actions secrets:"
    for name in "${missing[@]}"; do
      echo "- ${name}"
    done
    echo
    echo "Add them in repository Settings -> Secrets and variables -> Actions."
  } >&2
  exit 1
fi

tmp_config="$(mktemp)"
trap 'rm -f "$tmp_config"' EXIT

if ! python3 scripts/restore-build-config.py "$tmp_config"; then
  exit 1
fi

if [[ "${BUILD_MODE:-unsigned}" == "signed" ]]; then
  if ! echo "${TELEGRAM_IOS_CODESIGNING_TAR_BASE64}" | base64 --decode | tar -tzf - >/dev/null; then
    echo "TELEGRAM_IOS_CODESIGNING_TAR_BASE64 must decode to a valid .tar.gz archive." >&2
    exit 1
  fi
fi

echo "CI inputs look valid."
