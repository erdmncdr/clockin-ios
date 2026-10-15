#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
parse_args "$@"
[[ "${#ARGS[@]}" == 2 ]] || fail 'Usage: package.sh VERSION BUILD [--dry-run]'
version_paths "${ARGS[0]}" "${ARGS[1]}"
NOTES="$ROOT/docs/release-notes-mac-$VERSION.md"
if [[ "$DRY_RUN" == 0 ]]; then
    [[ -f "$WORK/build-verified" ]] || fail 'Run build.sh first.'
    [[ -f "$NOTES" ]] || fail "Missing release notes: $NOTES"
    [[ ! -e "$RELEASE" ]] || fail "Release already exists: $RELEASE"
    [[ "$(cat "$WORK/sparkle-artifacts.txt")" == "$DERIVED_DATA/SourcePackages/artifacts" ]] || fail 'Artifact directory mismatch.'
    SPARKLE_BINS=()
    while IFS= read -r -d '' candidate; do
        if [[ -x "$candidate" && -x "$(dirname "$candidate")/sign_update" ]]; then
            SPARKLE_BINS+=("$(dirname "$candidate")")
        fi
    done < <(find "$DERIVED_DATA/SourcePackages/artifacts" -type f -name generate_appcast -print0)
    [[ "${#SPARKLE_BINS[@]}" == 1 ]] || fail 'Expected exactly one Sparkle tool directory in this build’s artifacts.'
    SPARKLE_BIN="${SPARKLE_BINS[0]}"
    mkdir -p "$OUTPUT_ROOT/releases"
    PREPARING="$(mktemp -d "$OUTPUT_ROOT/releases/.preparing-$VERSION-$BUILD.XXXXXX")"
    STAGING="$(mktemp -d "$WORK/dmg-stage.XXXXXX")"
    trap 'rm -rf "$STAGING" "$PREPARING"' EXIT
else
    SPARKLE_BIN="$DERIVED_DATA/SourcePackages/artifacts/<resolved-Sparkle>/bin"
    PREPARING="$OUTPUT_ROOT/releases/.preparing-$VERSION-$BUILD"
    STAGING="$WORK/dmg-stage"
fi
run "$TOOLS_DIR/verify-app.sh" "$APP" "$VERSION" "$BUILD"
run xcrun stapler validate "$APP"
run spctl -a -vv --type execute "$APP"
step 'Create a compressed HFS+ installer: Clockin, an arrow and the Applications shortcut, with the license/attribution hidden inside.'
# dmgbuild writes the Finder window layout (.DS_Store and background); it runs
# from a pinned virtual environment under build/, created on first use.
DMG_VENV="$OUTPUT_ROOT/dmg-venv"
if [[ "$DRY_RUN" == 0 && ! -x "$DMG_VENV/bin/dmgbuild" ]]; then
    python3 -m venv "$DMG_VENV"
    "$DMG_VENV/bin/pip" install --quiet --disable-pip-version-check 'dmgbuild==1.6.5'
fi
run ditto "$APP" "$STAGING/Clockin.app"
run cp "$ROOT/LICENSE" "$STAGING/LICENSE.txt"
run cp "$ROOT/NOTICE.md" "$STAGING/NOTICE.md"
run "$DMG_VENV/bin/dmgbuild" -s "$TOOLS_DIR/dmg/dmg-settings.py" -D "staging=$STAGING" \
    -D "background=$TOOLS_DIR/dmg/background.tiff" Clockin "$PREPARING/$DMG_NAME"
run hdiutil verify "$PREPARING/$DMG_NAME"
run codesign --sign "$IDENTITY" --timestamp "$PREPARING/$DMG_NAME"
run codesign --verify --strict "$PREPARING/$DMG_NAME"
if [[ "$DRY_RUN" == 0 ]]; then
    verify_signature "$PREPARING/$DMG_NAME" disk-image || fail 'DMG must have this team’s Developer ID signature and timestamp.'
fi
# Stapling changes bytes: complete notarization before either Sparkle signature.
run "$TOOLS_DIR/notarize.sh" "$PREPARING/$DMG_NAME"
run cp "$NOTES" "$PREPARING/Clockin-$VERSION-$BUILD.md"
step 'Sign only via Sparkle’s existing Keychain account; no private-key file or export.'
run "$SPARKLE_BIN/sign_update" --account "$BUNDLE_ID" "$PREPARING/$DMG_NAME"
run "$SPARKLE_BIN/generate_appcast" --account "$BUNDLE_ID" --maximum-deltas 0 \
    --download-url-prefix "https://github.com/erdmncdr/clockin-macos/releases/download/macos-v$VERSION/" \
    --embed-release-notes -o "$PREPARING/appcast.xml" "$PREPARING"
run swift "$TOOLS_DIR/verify-release.swift" "$PREPARING/appcast.xml" "$APP/Contents/Info.plist"
run "$TOOLS_DIR/test-release-verification.sh" "$PREPARING" "$APP/Contents/Info.plist"
# After the feed exists, so generate_appcast never sees a second archive.
step 'Zip the stapled app for the website: Safari unpacks it and Clockin offers to move itself to Applications.'
ZIP_NAME="Clockin-$VERSION-$BUILD.zip"
run ditto -c -k --sequesterRsrc --keepParent "$APP" "$PREPARING/$ZIP_NAME"
step 'Write SHA256SUMS and provenance, then atomically mark the release ready.'
if [[ "$DRY_RUN" == 0 ]]; then
    (cd "$PREPARING" && shasum -a 256 "$DMG_NAME" "$ZIP_NAME" appcast.xml > SHA256SUMS)
    cp "$WORK/source-commit.txt" "$WORK/source-status.txt" "$PREPARING/"
    touch "$PREPARING/ready"
    mv "$PREPARING" "$RELEASE"
else
    run shasum -a 256 "$PREPARING/$DMG_NAME" "$PREPARING/appcast.xml"
    run mv "$PREPARING" "$RELEASE"
fi
step "Prepared release: $RELEASE"
