#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
parse_args "$@"
[[ "${#ARGS[@]}" == 3 ]] || fail 'Usage: verify-app.sh APP VERSION BUILD [--dry-run]'
version_paths "${ARGS[1]}" "${ARGS[2]}"
APP="${ARGS[0]}"
if [[ "$DRY_RUN" == 1 ]]; then
    step "Verify $APP: production bundle ID, $VERSION ($BUILD), macOS 14.0, universal app and Sparkle binaries."
    step 'Check pinned Sparkle feed/public key, required signed feed, pre-extraction verification, zero signature expiry.'
    step 'Verify deep/strict signatures; require Developer ID, LU36PKDPT3, timestamps and hardened runtime for app and every Sparkle component.'
    step 'Reject app sandbox or get-task-allow entitlements; require Sparkle 2.10.0 and its XPC services, Updater and Autoupdate.'
    exit 0
fi
PLIST="$APP/Contents/Info.plist"
require_plist "$PLIST" CFBundleIdentifier "$BUNDLE_ID"
require_plist "$PLIST" CFBundleShortVersionString "$VERSION"
require_plist "$PLIST" CFBundleVersion "$BUILD"
require_plist "$PLIST" LSMinimumSystemVersion 14.0
require_plist "$PLIST" SUFeedURL "$FEED_URL"
require_plist "$PLIST" SUPublicEDKey "$PUBLIC_KEY"
require_plist "$ROOT/Config/ClockinMac-Info.plist" SUPublicEDKey "$PUBLIC_KEY"
require_plist "$PLIST" SURequireSignedFeed true
require_plist "$PLIST" SUVerifyUpdateBeforeExtraction true
require_plist "$PLIST" SUSignedFeedFailureExpirationInterval 0
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
require_plist "$FRAMEWORK/Resources/Info.plist" CFBundleShortVersionString 2.10.0
for relative in Versions/B/Autoupdate Versions/B/Updater.app \
    Versions/B/XPCServices/Downloader.xpc Versions/B/XPCServices/Installer.xpc; do
    [[ -e "$FRAMEWORK/$relative" ]] || fail "Missing Sparkle component: $relative"
done
EXECUTABLE="$(plist_value "$PLIST" CFBundleExecutable)"
[[ "$EXECUTABLE" == Clockin ]] || fail 'Expected Clockin executable.'
# This lipo accepts one architecture per -verify_arch; check each slice.
verify_universal() {
    local arch
    for arch in arm64 x86_64; do run lipo "$1" -verify_arch "$arch"; done
}
verify_universal "$APP/Contents/MacOS/$EXECUTABLE"
while IFS= read -r component; do
    if [[ -f "$component" ]]; then verify_universal "$component"; fi
done < <(sparkle_components "$FRAMEWORK")
verify_all_signatures "$APP" || fail 'App or Sparkle signature requirements failed.'
ENTITLEMENTS="$(codesign -d --entitlements :- "$APP" 2>/dev/null)"
if [[ -n "$ENTITLEMENTS" ]]; then
    mkdir -p "$OUTPUT_ROOT/checks"
    ENTITLEMENTS_FILE="$(mktemp "$OUTPUT_ROOT/checks/entitlements.XXXXXX")"
    trap 'rm -f "$ENTITLEMENTS_FILE"' EXIT
    printf '%s' "$ENTITLEMENTS" > "$ENTITLEMENTS_FILE"
    plutil -lint "$ENTITLEMENTS_FILE"
    for key in com.apple.security.app-sandbox com.apple.security.get-task-allow; do
        # PlistBuddy treats dots literally; plutil -extract treats them as paths.
        value="$(plist_value "$ENTITLEMENTS_FILE" "$key" 2>/dev/null || true)"
        [[ "$value" != true ]] || fail "Distribution app has forbidden entitlement: $key"
    done
fi
# The desktop widget runs sandboxed and reads the snapshot from the team group.
WIDGET="$APP/Contents/PlugIns/ClockinMacWidgets.appex"
[[ -d "$WIDGET" ]] || fail 'Missing ClockinMacWidgets.appex.'
[[ "$(plist_value "$WIDGET/Contents/Info.plist" CFBundleIdentifier)" == com.ismailakdag.clockin.widgets ]] \
    || fail 'Unexpected widget bundle identifier.'
verify_universal "$WIDGET/Contents/MacOS/ClockinMacWidgets"
verify_signature "$WIDGET" || fail 'Widget signature requirements failed.'
WIDGET_ENTITLEMENTS="$(mktemp "$OUTPUT_ROOT/checks/widget-entitlements.XXXXXX")"
codesign -d --entitlements :- "$WIDGET" 2>/dev/null > "$WIDGET_ENTITLEMENTS"
[[ "$(plist_value "$WIDGET_ENTITLEMENTS" com.apple.security.app-sandbox)" == true ]] || fail 'Widget must be sandboxed.'
[[ "$(plist_value "$WIDGET_ENTITLEMENTS" com.apple.security.get-task-allow 2>/dev/null || true)" != true ]] \
    || fail 'Widget has get-task-allow.'
/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups' "$WIDGET_ENTITLEMENTS" \
    | grep -q 'LU36PKDPT3.com.ismailakdag.clockin' || fail 'Widget is missing the Clockin app group.'
rm -f "$WIDGET_ENTITLEMENTS"
step 'App metadata, architectures and distribution signatures verified.'
