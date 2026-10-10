#!/usr/bin/env bash
set -e

# Resolve repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found at $REPO_ROOT"
  exit 1
fi

# Extract version from pubspec.yaml
VERSION=$(grep -E '^version:' pubspec.yaml | head -n 1 | awk '{print $2}' | tr -d '\r\n"' | tr -d "'")

if [ -z "$VERSION" ]; then
  echo "❌ Error: Could not extract version from pubspec.yaml"
  exit 1
fi

TAG="v$VERSION"
FORCE_RETRY=false

# Check for flags
for arg in "$@"; do
  if [[ "$arg" == "--retry" || "$arg" == "--force" || "$arg" == "-f" ]]; then
    FORCE_RETRY=true
  fi
done

echo "📦 Target version in pubspec.yaml: $VERSION"
echo "🏷️  Release tag: $TAG"

TAG_EXISTS=false
if git rev-parse "$TAG" >/dev/null 2>&1 || git ls-remote --tags origin "$TAG" 2>/dev/null | grep -q "$TAG"; then
  TAG_EXISTS=true
fi

if [ "$TAG_EXISTS" = true ]; then
  if [ "$FORCE_RETRY" = false ]; then
    echo ""
    echo "⚠️  Tag $TAG already exists (build may have failed or already published)."
    read -p "👉 Would you like to overwrite/re-publish this tag to re-trigger the build? [y/N]: " CONFIRM
    case "$CONFIRM" in
      [yY][eE][sS]|[yY])
        FORCE_RETRY=true
        ;;
      *)
        echo "❌ Cancelled. Please bump the version in pubspec.yaml before releasing."
        exit 1
        ;;
    esac
  fi

  echo "🔄 Cleaning up existing tag $TAG..."
  git tag -d "$TAG" 2>/dev/null || true
  git push origin --delete "$TAG" 2>/dev/null || true
fi

echo "🚀 Staging and committing changes..."
git add .
git commit -m "chore: release $TAG" --allow-empty
git tag "$TAG"

echo "⬆️  Pushing commit and tag to origin..."
git push origin HEAD
git push origin "$TAG"

echo "============================================="
echo "✅ Release $TAG triggered successfully!"
echo "GitHub Actions should now build and publish it."
echo "============================================="
