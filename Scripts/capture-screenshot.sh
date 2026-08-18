#!/usr/bin/env bash
set -euo pipefail

# Captures the search panel for the README.
#
# Screenshots cannot be automated end to end: opening the panel needs the global
# hotkey, and capturing needs Screen Recording permission. So this script does
# the parts it can — timing, cropping, file placement, README wiring — and asks
# you for the two seconds in between.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="${PROJECT_DIR}/docs/search-panel.png"

mkdir -p "${PROJECT_DIR}/docs"

if ! pgrep -x YipYip > /dev/null 2>&1; then
    echo "==> YipYip is not running. Starting it..."
    open -a YipYip || { echo "Install it first: ./Scripts/build-app.sh" >&2; exit 1; }
    sleep 2
fi

cat <<'INSTRUCTIONS'
==> Ready.

  1. Press your YipYip shortcut to open the search panel.
  2. Make sure the history on screen is one you are happy to publish.
  3. When the crosshair appears, click the panel once.

INSTRUCTIONS

for i in 5 4 3 2 1; do
    printf "\r    Capturing in %d… " "$i"
    sleep 1
done
printf "\r    Click the panel now.        \n"

# -w picks a whole window, -o drops the drop shadow so the image crops tightly.
screencapture -w -o "$OUTPUT"

if [[ ! -f "$OUTPUT" ]]; then
    echo "No screenshot was written — cancelled, or Screen Recording is denied." >&2
    echo "Grant it under System Settings > Privacy & Security > Screen Recording." >&2
    exit 1
fi

echo "==> Wrote docs/search-panel.png"

# Swap the README placeholder for the real image the first time round.
README="${PROJECT_DIR}/README.md"
PLACEHOLDER='<!-- Screenshot: add docs/search-panel.png and reference it here -->'
if grep -qF "$PLACEHOLDER" "$README"; then
    python3 - "$README" "$PLACEHOLDER" <<'PY'
import sys
path, placeholder = sys.argv[1], sys.argv[2]
text = open(path).read()
image = '<p align="center">\n  <img src="docs/search-panel.png" alt="The YipYip search panel" width="720">\n</p>'
open(path, "w").write(text.replace(placeholder, image))
PY
    echo "==> README now points at the screenshot."
fi
