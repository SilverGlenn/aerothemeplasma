#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
if [[ $# != 1 ]]; then
    echo "Usage: bash $0 /path/to/patched/aeroshell-kwin-components" >&2
    exit 2
fi
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
python3 "$root/tests/aeroglassblur/test_scene_registration.py" "$1"
python3 "$root/tests/aeroglassblur/test_patch_application.py" "$1"
bash -n "$root/scripts/apply-aeroglassblur-patch.sh" "$root/install.sh"
