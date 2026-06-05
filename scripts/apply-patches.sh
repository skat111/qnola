#!/usr/bin/env bash
set -euo pipefail

patch_dir="${1:-../patches}"

shopt -s nullglob
patches=("${patch_dir}"/*.patch)

if (( ${#patches[@]} == 0 )); then
  echo "No patches found in ${patch_dir}; building upstream source."
  exit 0
fi

for patch in "${patches[@]}"; do
  echo "Applying ${patch}"
  git am "${patch}"
done

