#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Apply only the Wayland AeroGlassBlur repaint compatibility patch. No builds,
# installation, git checkout/reset, or running-session changes are performed.
set -euo pipefail

if [[ $# != 1 ]]; then
    echo "Usage: bash $0 /path/to/aeroshell-kwin-components" >&2
    exit 2
fi

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
patch="$root/patches/aeroshell-kwin-components/0001-register-background-damage.patch"
source="$(cd -- "$1" && pwd -P)"
if [[ "$(git -C "$source" rev-parse --show-toplevel)" != "$source" ]]; then
    echo "Expected the companion repository root, not a subdirectory: $source" >&2
    exit 1
fi

if git -C "$source" apply --check "$patch" 2>/dev/null; then
    git -C "$source" apply "$patch"
    echo "Applied AeroGlassBlur background-damage registration patch."
elif git -C "$source" apply --reverse --check "$patch" 2>/dev/null; then
    echo "AeroGlassBlur background-damage registration patch is already applied."
else
    echo "AeroGlassBlur source is incompatible or only partially patched; no files changed." >&2
    echo "Review local changes and the companion version before building." >&2
    git -C "$source" apply --check "$patch" >&2 || true
    exit 1
fi
