#!/bin/bash
set -euo pipefail

# Point the Homebrew cask at a released version.
# Usage: ./scripts/update-cask.sh <version> <sha256 of EmojiCursor-<version>.zip>

VERSION="${1:?usage: update-cask.sh <version> <sha256>}"
SHA256="${2:?usage: update-cask.sh <version> <sha256>}"
CASK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Casks/emojicursor.rb"

[[ "$SHA256" =~ ^[0-9a-f]{64}$ ]] || { echo "error: '$SHA256' is not a sha256" >&2; exit 1; }

sed -i.bak -E \
    -e "s/^  version \".*\"/  version \"${VERSION}\"/" \
    -e "s/^  sha256 \".*\"/  sha256 \"${SHA256}\"/" \
    "$CASK"
rm -f "$CASK.bak"
echo "Updated $CASK to ${VERSION}"
