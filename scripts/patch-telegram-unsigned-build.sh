#!/usr/bin/env bash
set -euo pipefail

if [[ "${BUILD_MODE:-unsigned}" != "unsigned" ]]; then
  echo "Signed build mode; leaving Telegram build provisioning behavior unchanged."
  exit 0
fi

make_py="build-system/Make/Make.py"
if [[ ! -f "${make_py}" ]]; then
  echo "Cannot find ${make_py}" >&2
  exit 1
fi

python3 - "$make_py" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

if "Qnola unsigned mode builds simulator artifacts" in text:
    print("Telegram Make.py unsigned build patch already applied.")
    raise SystemExit(0)

replacements = [
    (
        "        self.disable_provisioning_profiles = False\n",
        "        self.disable_provisioning_profiles = False\n"
        "        self.disable_extensions = False\n",
    ),
    (
        "    def set_disable_provisioning_profiles(self):\n"
        "        self.disable_provisioning_profiles = True\n",
        "    def set_disable_provisioning_profiles(self):\n"
        "        self.disable_provisioning_profiles = True\n"
        "\n"
        "    def set_disable_extensions(self):\n"
        "        self.disable_extensions = True\n",
    ),
    (
        "        if self.disable_provisioning_profiles:\n"
        "            combined_arguments += ['--//Telegram:disableProvisioningProfiles']\n",
        "        if self.disable_extensions:\n"
        "            combined_arguments += ['--//Telegram:disableExtensions']\n"
        "        if self.disable_provisioning_profiles:\n"
        "            combined_arguments += ['--//Telegram:disableProvisioningProfiles']\n",
    ),
    (
        "    bazel_command_line.set_profile_swift(arguments.profileSwift)\n",
        "    bazel_command_line.set_profile_swift(arguments.profileSwift)\n"
        "\n"
        "    # Qnola unsigned mode builds simulator artifacts without extension/profile requirements.\n"
        "    bazel_command_line.set_disable_extensions()\n"
        "    bazel_command_line.set_disable_provisioning_profiles()\n",
    ),
]

for needle, replacement in replacements:
    if needle not in text:
        print(f"Unable to find Make.py patch anchor:\n{needle}", file=sys.stderr)
        raise SystemExit(1)
    text = text.replace(needle, replacement, 1)

if "Qnola unsigned mode builds simulator artifacts" not in text:
    print("Unsigned patch marker was not inserted.", file=sys.stderr)
    raise SystemExit(1)

path.write_text(text)
print("Patched Telegram Make.py for unsigned Qnola build.")
PY
