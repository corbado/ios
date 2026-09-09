#!/bin/sh
# Refresh a vendored copy of this package: tools/vendor.sh <consumer>/Vendor/corbado-ios
# Ships what a source archive ships (see .gitattributes), from the current HEAD.
set -eu
dest="${1:?destination directory required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
(cd "$root" && swift package archive-source --output "$tmp/corbado-ios.zip" >/dev/null)
unzip -q "$tmp/corbado-ios.zip" -d "$tmp/unpacked"
rm -rf "$dest"
mkdir -p "$(dirname "$dest")"
mv "$tmp/unpacked/corbado-ios" "$dest"
echo "vendored $(git -C "$root" rev-parse --short HEAD) into $dest"
