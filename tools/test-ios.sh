#!/usr/bin/env bash
# Native build, unit tests and UI tests. Requires macOS/Xcode; never reports a Linux skip as a pass.
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]] || ! command -v xcodebuild >/dev/null; then
 printf '%s\n' 'Native iOS tests require macOS with Xcode and an installed iOS Simulator runtime.' >&2
 exit 2
fi
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
result_path="${CRISIS_IOS_RESULTS:-$repo_root/ios/TestResults/CRISIS-$(date +%Y%m%d-%H%M%S).xcresult}"
mkdir -p "$(dirname "$result_path")"
device_id="${CRISIS_IOS_DEVICE_ID:-}"
if [[ -z "$device_id" ]]; then
 device_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(v["udid"] for runtime,devices in d["devices"].items() if ".iOS-" in runtime for v in devices if "iPhone" in v["name"] and v.get("isAvailable",False)))')"
fi
if ! xcrun simctl boot "$device_id"; then
 # bootstatus verifies readiness and also accepts a previously booted device.
 xcrun simctl bootstatus "$device_id" -b
fi
xcrun simctl bootstatus "$device_id" -b
exec xcodebuild -project ios/CRISIS.xcodeproj -scheme CRISIS \
 -destination "platform=iOS Simulator,id=$device_id" \
 -parallel-testing-enabled NO -resultBundlePath "$result_path" \
 CODE_SIGNING_ALLOWED=NO test "$@"
