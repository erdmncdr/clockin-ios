#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
parse_args "$@"
[[ "${#ARGS[@]}" == 2 ]] || fail 'Usage: build.sh VERSION BUILD [--dry-run]'
version_paths "${ARGS[0]}" "${ARGS[1]}"
if [[ "$DRY_RUN" == 0 ]]; then
    [[ ! -e "$WORK" ]] || fail "Already exists: $WORK; use a fresh build number."
    mkdir -p "$WORK"
    git -C "$ROOT" rev-parse HEAD > "$WORK/source-commit.txt"
    git -C "$ROOT" status --porcelain --untracked-files=all > "$WORK/source-status.txt"
fi
step 'Archive ClockinMac with explicit distribution signing (no project edits).'
run xcodebuild archive -project "$ROOT/Clockin.xcodeproj" -scheme ClockinMac \
    -configuration Release -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" -derivedDataPath "$DERIVED_DATA" \
    -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
    'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_IDENTITY="$IDENTITY" CODE_SIGN_STYLE=Manual \
    CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES 'OTHER_CODE_SIGN_FLAGS=--timestamp' \
    ENABLE_HARDENED_RUNTIME=YES ENABLE_APP_SANDBOX=NO \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD"
step 'Export the archive using the checked-in Developer ID options.'
run xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$TOOLS_DIR/ExportOptions.plist" -exportPath "$WORK/export"
if [[ "$DRY_RUN" == 1 ]]; then
    step 'Inspect all Sparkle Mach-O files, XPC services, Updater.app, Autoupdate and framework signatures.'
    step 'If team/timestamp/runtime verification fails, re-sign every nested component inside-out, preserving entitlements, then the app.'
    run codesign --force --sign "$IDENTITY" --options runtime --timestamp \
        --preserve-metadata=entitlements '<each nested Sparkle component, inside-out>'
    run codesign --force --sign "$IDENTITY" --options runtime --timestamp \
        --preserve-metadata=entitlements "$APP"
else
    [[ -d "$APP/Contents/Frameworks/Sparkle.framework" ]] || fail 'Export is missing Sparkle.'
    if ! verify_all_signatures "$APP"; then
        step 'Repairing exported Sparkle signatures inside-out; preserving helper entitlements.'
        while IFS= read -r component; do
            run codesign --force --sign "$IDENTITY" --options runtime --timestamp \
                --preserve-metadata=entitlements "$component"
        done < <(sparkle_components "$APP/Contents/Frameworks/Sparkle.framework")
        run codesign --force --sign "$IDENTITY" --options runtime --timestamp \
            --preserve-metadata=entitlements "$APP"
    fi
fi
run "$TOOLS_DIR/verify-app.sh" "$APP" "$VERSION" "$BUILD"
if [[ "$DRY_RUN" == 0 ]]; then
    # Record the exact artifact directory used by this archive, never a global cache.
    printf '%s\n' "$DERIVED_DATA/SourcePackages/artifacts" > "$WORK/sparkle-artifacts.txt"
    touch "$WORK/build-verified"
fi
step "Export ready for notarize.sh: $APP"
