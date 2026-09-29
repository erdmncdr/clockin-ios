#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
parse_args "$@"
[[ "${#ARGS[@]}" == 1 ]] || fail 'Usage: notarize.sh APP_OR_DMG [--dry-run]'
TARGET="${ARGS[0]}"
case "$TARGET" in
    *.app) KIND=app ;;
    *.dmg) KIND=dmg ;;
    *) fail 'Pass an .app or .dmg.' ;;
esac
if [[ "$DRY_RUN" == 0 ]]; then
    [[ -e "$TARGET" ]] || fail "Missing: $TARGET"
    mkdir -p "$OUTPUT_ROOT/notary"
    JOB="$(mktemp -d "$OUTPUT_ROOT/notary/submission.XXXXXX")"
else
    JOB="$OUTPUT_ROOT/notary/<unique-submission>"
fi
SUBMISSION="$TARGET"
run codesign --verify --deep --strict "$TARGET"
if [[ "$KIND" == app ]]; then
    SUBMISSION="$JOB/Clockin.zip"
    run ditto -c -k --sequesterRsrc --keepParent "$TARGET" "$SUBMISSION"
fi
step "Submit with the existing ClockinNotary profile; save JSON to $JOB/result.json."
if [[ "$DRY_RUN" == 1 ]]; then
    run xcrun notarytool submit "$SUBMISSION" --keychain-profile ClockinNotary --wait --output-format json
else
    xcrun notarytool submit "$SUBMISSION" --keychain-profile ClockinNotary --wait \
        --output-format json > "$JOB/result.json"
    [[ "$(plutil -extract status raw "$JOB/result.json")" == Accepted ]] \
        || fail "Notarization was not Accepted. See $JOB/result.json; do not package or publish."
fi
step 'Require Accepted before stapling; then validate the ticket and Gatekeeper.'
run xcrun stapler staple "$TARGET"
run xcrun stapler validate "$TARGET"
if [[ "$KIND" == app ]]; then
    run spctl -a -vv --type execute "$TARGET"
else
    run spctl -a -vv --type open --context context:primary-signature "$TARGET"
fi
run codesign --verify --deep --strict "$TARGET"
