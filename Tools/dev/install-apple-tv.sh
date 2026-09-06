#!/usr/bin/env bash
# Build Stratix and install it on a connected Apple TV.
# Requires Xcode 26+, a Developer-mode Apple TV on the same network, and a signing team in Xcode.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

SCHEME="${SCHEME:-Stratix-Debug}"
BUNDLE_ID="${BUNDLE_ID:-com.sibwase.stratix.appletv}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/stratix_apple_tv_install}"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-appletvos/Stratix.app"

pick_device_id() {
  if [[ -n "${APPLE_TV_DEVICE_ID:-}" ]]; then
    printf '%s\n' "$APPLE_TV_DEVICE_ID"
    return
  fi

  local destinations
  destinations="$(xcodebuild -workspace Stratix.xcworkspace -scheme "$SCHEME" -showdestinations 2>/dev/null || true)"
  python3 - "$destinations" <<'PY'
import re, sys
blob = sys.argv[1]
ids = []
for match in re.finditer(r"\{([^}]+)\}", blob):
    fields = dict(
        part.split(":", 1)
        for part in (item.strip() for item in match.group(1).split(","))
        if ":" in part
    )
    platform = fields.get("platform", "")
    name = fields.get("name", "")
    ident = fields.get("id", "")
    if platform == "tvOS" and "Simulator" not in name and ident:
        ids.append(ident)
if not ids:
    sys.exit(1)
print(ids[0])
PY
}

DEVICE_ID="$(pick_device_id)" || {
  echo "No physical Apple TV found. Pair it in Xcode (Window > Devices and Simulators), then rerun." >&2
  echo "Or set APPLE_TV_DEVICE_ID to the device UDID." >&2
  exit 1
}

echo "Building Stratix for Apple TV ($DEVICE_ID)..."
xcodebuild \
  -workspace Stratix.xcworkspace \
  -scheme "$SCHEME" \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$DERIVED_DATA/spm" \
  -allowProvisioningUpdates \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but Stratix.app was not at $APP_PATH" >&2
  exit 1
fi

echo "Installing $APP_PATH..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
echo "Launching $BUNDLE_ID..."
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
echo "Stratix is installed and launching on the Apple TV."
