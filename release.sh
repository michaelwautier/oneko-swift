#!/bin/zsh
# Builds a versioned, zipped release: ./release.sh 1.1.0
# Produces build/Oneko-<version>.zip and prints its sha256 for the cask.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh <version>}"
./build.sh "$VERSION"

ZIP="build/Oneko-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/Oneko.app "$ZIP"

echo "Built $ZIP"
echo "sha256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
