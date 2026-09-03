#!/usr/bin/env bash
# publish-game.sh <id> <web-bundle-dir> <apk-path> [--version v] [--notes file] [--dry-run]
#
# Copies a game's web bundle into <id>/, creates/updates a GitHub release on
# isa-kit/play tagged <id>-<version> with the APK plus a <id>-latest.apk
# alias asset, writes size + sha256 into games.json, commits and pushes.
#
# bash 3.2 compatible (macOS default bash). No mapfile, no ${var,,}.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  echo "usage: $0 <id> <web-bundle-dir> <apk-path> [--version v] [--notes file] [--dry-run]" >&2
  exit 1
}

[ $# -ge 3 ] || usage

GAME_ID="$1"; shift
WEB_DIR="$1"; shift
APK_PATH="$1"; shift

VERSION=""
NOTES_FILE=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="$2"; shift 2 ;;
    --notes)
      NOTES_FILE="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    *)
      echo "unknown arg: $1" >&2; usage ;;
  esac
done

if [ -z "$GAME_ID" ]; then
  echo "error: <id> must not be empty" >&2
  exit 1
fi
case "$GAME_ID" in
  */*) echo "error: <id> must not contain '/'" >&2; exit 1 ;;
esac

if [ ! -d "$WEB_DIR" ]; then
  echo "error: web bundle dir not found: $WEB_DIR" >&2
  exit 1
fi
if [ ! -f "$APK_PATH" ]; then
  echo "error: apk not found: $APK_PATH" >&2
  exit 1
fi
if [ -z "$VERSION" ]; then
  echo "error: --version is required" >&2
  exit 1
fi

TAG="${GAME_ID}-${VERSION}"
ASSET_NAME="${GAME_ID}-${VERSION}-arm64.apk"
ALIAS_NAME="${GAME_ID}-latest.apk"

APK_SIZE_BYTES=$(stat -f%z "$APK_PATH" 2>/dev/null || stat -c%s "$APK_PATH")
APK_SHA256=$(shasum -a 256 "$APK_PATH" | awk '{print $1}')

# Human-readable size (MB, one decimal)
APK_SIZE_HUMAN=$(python3 - "$APK_SIZE_BYTES" <<'PY'
import sys
b = int(sys.argv[1])
mb = b / (1024 * 1024)
print(f"{mb:.1f} MB")
PY
)

DATE_STR=$(date +%Y-%m-%d)

echo "== publish-game.sh =="
echo "id:        $GAME_ID"
echo "web dir:   $WEB_DIR"
echo "apk:       $APK_PATH ($APK_SIZE_HUMAN, sha256=$APK_SHA256)"
echo "tag:       $TAG"
echo "asset:     $ASSET_NAME"
echo "alias:     $ALIAS_NAME"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "-- dry run: no changes made --"
  exit 0
fi

# 1. Copy web bundle into <id>/
rm -rf "${REPO_ROOT:?}/${GAME_ID}"
mkdir -p "$REPO_ROOT/$GAME_ID"
cp -R "$WEB_DIR"/. "$REPO_ROOT/$GAME_ID/"

# 2. Create or update the GitHub release
RELEASE_ARGS=(--title "$GAME_ID $VERSION")
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
  RELEASE_ARGS+=(--notes-file "$NOTES_FILE")
else
  RELEASE_ARGS+=(--notes "$GAME_ID $VERSION")
fi

if gh release view "$TAG" --repo isa-kit/play >/dev/null 2>&1; then
  echo "release $TAG exists, updating"
else
  gh release create "$TAG" --repo isa-kit/play "${RELEASE_ARGS[@]}"
fi

# Upload arm64 asset (clobber if present)
gh release upload "$TAG" "$APK_PATH#$ASSET_NAME" --repo isa-kit/play --clobber

# Alias asset: delete then re-upload (gh has no rename for a differently-named local file)
gh release delete-asset "$TAG" "$ALIAS_NAME" --repo isa-kit/play -y 2>/dev/null || true
cp "$APK_PATH" "/tmp/${ALIAS_NAME}"
gh release upload "$TAG" "/tmp/${ALIAS_NAME}" --repo isa-kit/play --clobber
rm -f "/tmp/${ALIAS_NAME}"

ASSET_URL="https://github.com/isa-kit/play/releases/download/${TAG}/${ASSET_NAME}"
ALIAS_URL="https://github.com/isa-kit/play/releases/download/${TAG}/${ALIAS_NAME}"

# 3. Update games.json (python3, preserves other entries)
python3 - "$REPO_ROOT/games.json" "$GAME_ID" "$VERSION" "$DATE_STR" "$ASSET_URL" "$APK_SIZE_HUMAN" "$APK_SHA256" <<'PY'
import json, sys, os

path, game_id, version, date_str, apk_url, apk_size, apk_sha = sys.argv[1:8]

if os.path.exists(path):
    with open(path) as f:
        content = f.read().strip()
    games = json.loads(content) if content else []
else:
    games = []

entry = None
for g in games:
    if g.get("id") == game_id:
        entry = g
        break

if entry is None:
    entry = {"id": game_id}
    games.append(entry)

entry["version"] = version
entry["date"] = date_str
entry["apk"] = {
    "url": apk_url,
    "size": apk_size,
    "sha256": apk_sha,
    "preview": entry.get("apk", {}).get("preview", True),
}
entry.setdefault("name", game_id)
entry.setdefault("tagline", "")

with open(path, "w") as f:
    json.dump(games, f, indent=2)
    f.write("\n")
PY

# 4. Commit and push (scoped add)
git add "$GAME_ID" games.json
git commit -m "Publish ${GAME_ID} ${VERSION}"
git push origin main

echo ""
echo "== done =="
echo "web:       https://play.devisant.com/${GAME_ID}/"
echo "apk:       $ASSET_URL"
echo "apk alias: $ALIAS_URL"
