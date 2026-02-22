#!/usr/bin/env bash
# Update prebuilt Prisma engine binary hashes after bumping @prisma/client.
#
# Usage: ./nix/scripts/update-prisma-hashes.sh
#
# This reads the engine commit hash from yarn.lock and prefetches
# binaries for all supported platforms, then updates the hashes
# in nix/packages/prisma-engines-prebuilt.nix.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
NIX_FILE="$SCRIPT_DIR/../packages/prisma-engines-prebuilt.nix"

# Extract engine hash from yarn.lock
ENGINE_HASH=$(grep '@prisma/engines-version' "$REPO_ROOT/yarn.lock" | head -1 | grep -oP '[a-f0-9]{40}')

if [ -z "$ENGINE_HASH" ]; then
  echo "ERROR: Could not find @prisma/engines-version in yarn.lock"
  exit 1
fi

echo "Engine commit hash: $ENGINE_HASH"

BASE_URL="https://binaries.prisma.sh/all_commits/$ENGINE_HASH"

prefetch() {
  local url="$1"
  echo "  Fetching: $url" >&2
  nix-prefetch-url "$url" --type sha256 2>/dev/null
}

update_hash() {
  local old_hash="$1"
  local new_hash="$2"
  if [ "$old_hash" != "$new_hash" ]; then
    sed -i '' "s|$old_hash|$new_hash|g" "$NIX_FILE"
    echo "  Updated: $old_hash -> $new_hash"
  else
    echo "  Unchanged: $old_hash"
  fi
}

echo ""
echo "Prefetching aarch64-linux binaries..."
AARCH64_LINUX_QE=$(prefetch "$BASE_URL/linux-arm64-openssl-3.0.x/libquery_engine.so.node.gz")
AARCH64_LINUX_SE=$(prefetch "$BASE_URL/linux-arm64-openssl-3.0.x/schema-engine.gz")

echo "Prefetching aarch64-darwin binaries..."
AARCH64_DARWIN_QE=$(prefetch "$BASE_URL/darwin-arm64/libquery_engine.dylib.node.gz")
AARCH64_DARWIN_SE=$(prefetch "$BASE_URL/darwin-arm64/schema-engine.gz")

echo "Prefetching x86_64-linux binaries..."
X86_64_LINUX_QE=$(prefetch "$BASE_URL/debian-openssl-3.0.x/libquery_engine.so.node.gz")
X86_64_LINUX_SE=$(prefetch "$BASE_URL/debian-openssl-3.0.x/schema-engine.gz")

echo ""
echo "Updating hashes in $NIX_FILE..."

# Read current hashes from the nix file (in order of appearance)
CURRENT_HASHES=($(grep -oP '(?<=Hash = ")[^"]+' "$NIX_FILE"))

# Update in order: aarch64-linux QE, SE, aarch64-darwin QE, SE, x86_64-linux QE, SE
NEW_HASHES=("$AARCH64_LINUX_QE" "$AARCH64_LINUX_SE" "$AARCH64_DARWIN_QE" "$AARCH64_DARWIN_SE" "$X86_64_LINUX_QE" "$X86_64_LINUX_SE")

for i in "${!CURRENT_HASHES[@]}"; do
  update_hash "${CURRENT_HASHES[$i]}" "${NEW_HASHES[$i]}"
done

echo ""
echo "Done! Verify with: nix build .#happier-server"
