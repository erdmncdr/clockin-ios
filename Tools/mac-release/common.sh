#!/bin/bash
set -euo pipefail
# Shared by the entry points; sourcing this file has no external side effects.
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$TOOLS_DIR/../.." && pwd)"
OUTPUT_ROOT="$ROOT/build/mac-release"
TEAM=LU36PKDPT3
IDENTITY='Developer ID Application'
BUNDLE_ID=com.ismailakdag.clockin
FEED_URL=https://github.com/ismailakdag/clockin/releases/download/macos-updates/appcast.xml
PUBLIC_KEY='vsxEtDN88GYSuw5+GGeCk3eEvZxlDEalz1icmMBCvh8='
DRY_RUN=0
YES=0
ARGS=()

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
step() { printf '\n%s\n' "$*"; }
parse_args() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=1 ;;
            --yes) YES=1 ;;
            --*) fail "Unknown option: $arg" ;;
            *) ARGS+=("$arg") ;;
        esac
    done
}
run() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
    if [[ "$DRY_RUN" == 0 ]]; then "$@"; fi
}
version_paths() {
    VERSION="$1"
    BUILD="$2"
    [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'Version must be x.y.z.'
    [[ "$BUILD" =~ ^[1-9][0-9]*$ ]] || fail 'Build must be a positive integer.'
    WORK="$OUTPUT_ROOT/$VERSION-$BUILD"
    DERIVED_DATA="$WORK/DerivedData"
    ARCHIVE="$WORK/Clockin.xcarchive"
    APP="$WORK/export/Clockin.app"
    RELEASE="$OUTPUT_ROOT/releases/$VERSION-$BUILD"
    DMG_NAME="Clockin-$VERSION-$BUILD.dmg"
}
plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1"; }
require_plist() {
    local actual
    actual="$(plist_value "$1" "$2")" || fail "Missing plist key: $2"
    [[ "$actual" == "$3" ]] || fail "Unexpected $2: $actual (expected $3)"
}
# Inspect every actual Mach-O file and bundle; find does not follow symlinks.
# The depth ordering also supplies the inside-out repair order.
sparkle_components() {
    local path
    while IFS= read -r -d '' path; do
        if [[ -d "$path" ]]; then
            case "$path" in *.app|*.xpc|*.framework) printf '%s\n' "$path" ;; esac
        elif [[ "$(/usr/bin/file -b "$path")" == *Mach-O* ]]; then
            printf '%s\n' "$path"
        fi
    done < <(find "$1" -depth \( -type f -o -type d \) -print0)
}
verify_signature() {
    local details
    codesign --verify --strict "$1" || return 1
    details="$(codesign -d --verbose=4 "$1" 2>&1)" || return 1
    [[ "$details" == *"TeamIdentifier=$TEAM"* ]] || { printf 'Wrong team: %s\n' "$1" >&2; return 1; }
    [[ "$details" == *'Authority=Developer ID Application:'* ]] || return 1
    [[ "$details" == *'Timestamp='* && "$details" != *'Timestamp=none'* ]] || return 1
    if [[ "${2:-runtime}" == runtime ]]; then
        [[ "$details" == *'(runtime)'* ]] || { printf 'Missing hardened runtime: %s\n' "$1" >&2; return 1; }
    fi
}
verify_all_signatures() {
    local component failed=0
    while IFS= read -r component; do
        if ! verify_signature "$component"; then failed=1; fi
    done < <(sparkle_components "$1/Contents/Frameworks/Sparkle.framework")
    if ! verify_signature "$1"; then failed=1; fi
    if ! codesign --verify --deep --strict "$1"; then failed=1; fi
    [[ "$failed" == 0 ]]
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    [[ "${1:-}" == --dry-run && "$#" == 1 ]] || fail 'common.sh is a library; use build.sh, notarize.sh, package.sh or publish.sh.'
    printf 'Shared constants, argument parsing, paths and signature checks; no actions.\n'
fi
