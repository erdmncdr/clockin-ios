#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
parse_args "$@"
[[ "${#ARGS[@]}" == 1 ]] || fail 'Usage: publish.sh VERSION --yes | --dry-run'
VERSION="${ARGS[0]}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'Version must be x.y.z.'
if [[ "$DRY_RUN" == 1 ]]; then
    python3 "$TOOLS_DIR/publish-release.py" "$VERSION" --dry-run
    exit 0
fi
[[ "$YES" == 1 ]] || fail 'Publishing requires --yes. Preview with --dry-run first.'
python3 "$TOOLS_DIR/publish-release.py" "$VERSION" --yes
