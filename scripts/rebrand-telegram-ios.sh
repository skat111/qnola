#!/usr/bin/env bash
set -euo pipefail

app_name="Qnola"
lower_name="qnola"

repo_root="$(pwd)"

echo "Applying ${app_name} visible branding in ${repo_root}"

replace_text_file() {
  local file="$1"
  perl -0pi -e 's/Telegram/Qnola/g; s/telegram/qnola/g; s/TELEGRAM/QNOLA/g' "$file"
}

replace_strings_values_file() {
  local file="$1"
  perl -0pi -e '
    sub rebrand_value {
      my ($value) = @_;
      $value =~ s/TELEGRAM/QNOLA/g;
      $value =~ s/Telegram/Qnola/g;
      $value =~ s/telegram/qnola/g;
      return $value;
    }
    s/("(?:(?:\\.)|[^"\\])*"\s*=\s*")((?:\\.|[^"\\])*)(")/$1 . rebrand_value($2) . $3/gex;
  ' "$file"
}

if [[ -d "Telegram" ]]; then
  while IFS= read -r -d '' file; do
    case "$file" in
      *.strings)
        replace_strings_values_file "$file"
        ;;
      *)
        replace_text_file "$file"
        ;;
    esac
  done < <(
    find Telegram \
      \( -path '*/submodules/*' -o -path '*/third-party/*' -o -path '*/ThirdParty/*' \) -prune -o \
      -type f \
      \( -name 'Info.plist' -o -name 'InfoBazel.plist' -o -name 'InfoPlist.strings' -o -name 'Localizable.strings' -o -name '*.xcconfig' \) \
      -print0
  )
fi

if [[ -f "build-system/ci-configuration.json" ]]; then
  replace_text_file "build-system/ci-configuration.json"
fi

if command -v swift >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
  icon_src="$(mktemp -t qnola-icon).png"
  if swift /dev/stdin "$icon_src" <<'SWIFT'
import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
NSColor.black.setFill()
NSBezierPath(roundedRect: rect, xRadius: 224, yRadius: 224).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 560, weight: .bold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
]

let letter = NSString(string: "R")
let textRect = NSRect(x: 0, y: 210, width: 1024, height: 620)
letter.draw(in: textRect, withAttributes: attributes)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Unable to generate icon")
}

try png.write(to: URL(fileURLWithPath: output))
SWIFT
  then

    while IFS= read -r -d '' png; do
      width="$(sips -g pixelWidth "$png" 2>/dev/null | awk '/pixelWidth/ {print $2}' | tail -n 1)"
      height="$(sips -g pixelHeight "$png" 2>/dev/null | awk '/pixelHeight/ {print $2}' | tail -n 1)"
      if [[ -n "${width}" && -n "${height}" ]]; then
        sips -z "$height" "$width" "$icon_src" --out "$png" >/dev/null
      fi
    done < <(
      find Telegram \
        -type f \
        -name '*.png' \
        \( -path '*AppIcon*.appiconset/*' -o -path '*DefaultAppIcon.xcassets/*' -o -path '*.alticon/*' \) \
        -print0
    )
  else
    echo "::warning::Unable to generate Qnola icon with Swift; continuing without icon replacement."
  fi

  rm -f "$icon_src"
else
  echo "::warning::swift or sips is unavailable; skipping icon generation."
fi

echo "${app_name} branding applied."
