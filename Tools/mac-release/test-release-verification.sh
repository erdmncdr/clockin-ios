#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
# --self-test creates a throwaway key in memory and fixtures under /tmp.
SELF_TEST=0
FILTERED=()
for arg in "$@"; do
    if [[ "$arg" == --self-test ]]; then SELF_TEST=1; else FILTERED+=("$arg"); fi
done
parse_args "${FILTERED[@]+"${FILTERED[@]}"}"
if [[ "$DRY_RUN" == 1 ]]; then
    step 'Compile verifier offline; accept signed fixture/release, reject modified feed, same-length archive corruption, missing signature, wrong key and wrong metadata.'
    exit 0
fi
if [[ "$SELF_TEST" == 1 ]]; then
    [[ "${#ARGS[@]}" == 0 ]] || fail 'Usage: test-release-verification.sh --self-test [--dry-run]'
    TEST_WORK="$(mktemp -d /tmp/clockin-release-test.XXXXXX)"
else
    [[ "${#ARGS[@]}" == 2 ]] || fail 'Usage: test-release-verification.sh RELEASE_DIR INFO_PLIST [--dry-run]'
    mkdir -p "$OUTPUT_ROOT/tests"
    TEST_WORK="$(mktemp -d "$OUTPUT_ROOT/tests/verification.XXXXXX")"
fi
trap 'rm -rf "$TEST_WORK"' EXIT
# Keep compiler caches within the allowed scratch location as well.
export CLANG_MODULE_CACHE_PATH="$TEST_WORK/module-cache"
export SWIFT_MODULECACHE_PATH="$TEST_WORK/module-cache"
swiftc -module-cache-path "$TEST_WORK/module-cache" "$TOOLS_DIR/verify-release.swift" -o "$TEST_WORK/verify"
if [[ "$SELF_TEST" == 1 ]]; then
    swift "$TOOLS_DIR/test-fixtures.swift" "$TEST_WORK/fixtures"
    RELEASE_INPUT="$TEST_WORK/fixtures/valid"
    INFO="$RELEASE_INPUT/Info.plist"
else
    RELEASE_INPUT="${ARGS[0]}"
    INFO="${ARGS[1]}"
fi
"$TEST_WORK/verify" "$RELEASE_INPUT/appcast.xml" "$INFO"
printf 'PASS: valid signed release\n'
mkdir "$TEST_WORK/tampered"
cp "$RELEASE_INPUT/appcast.xml" "$TEST_WORK/tampered/"
cp "$RELEASE_INPUT/"*.dmg "$TEST_WORK/tampered/"
# Like the old pipeline, Python edits bytes only in disposable test copies.
python3 - "$TEST_WORK/tampered/appcast.xml" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
data = path.read_bytes()
assert b'<title>' in data
path.write_bytes(data.replace(b'<title>', b'<title>X', 1))
PY
expect_failure() {
    local feed="$1" plist="$2" pattern="$3"
    if "$TEST_WORK/verify" "$feed" "$plist" > "$TEST_WORK/result.log" 2>&1; then
        fail "Invalid fixture accepted: $pattern"
    fi
    grep -Eq "$pattern" "$TEST_WORK/result.log" || { cat "$TEST_WORK/result.log"; fail 'Unexpected verification failure.'; }
    printf 'PASS: rejected %s\n' "$pattern"
}
expect_failure "$TEST_WORK/tampered/appcast.xml" "$INFO" 'Feed length mismatch|Feed signature does not match'
cp "$RELEASE_INPUT/appcast.xml" "$TEST_WORK/tampered/appcast.xml"
python3 - "$TEST_WORK/tampered" <<'PY'
from pathlib import Path
import sys
path = next(Path(sys.argv[1]).glob('*.dmg'))
data = bytearray(path.read_bytes())
data[len(data) // 2] ^= 1
path.write_bytes(data)
PY
expect_failure "$TEST_WORK/tampered/appcast.xml" "$INFO" 'Invalid archive signature'
if [[ "$SELF_TEST" == 1 ]]; then
    for spec in 'same-length-feed|Feed signature does not match' \
        'missing-signature|Missing feed signature' 'wrong-key|Feed signature does not match' \
        'archive-length|Archive length mismatch' 'http|Update URL must use HTTPS' \
        'wrong-build|Feed build does not match app' 'wrong-url|Unexpected release archive URL' \
        'bad-block|Invalid signature block'; do
        fixture="${spec%%|*}"
        pattern="${spec#*|}"
        expect_failure "$TEST_WORK/fixtures/$fixture/appcast.xml" "$TEST_WORK/fixtures/$fixture/Info.plist" "$pattern"
    done
fi
