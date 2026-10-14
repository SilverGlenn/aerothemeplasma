#!/bin/bash
set -euo pipefail
if [[ $# != 2 ]]; then echo "Usage: $0 NATIVE_BUILD STAGE_PREFIX" >&2; exit 2; fi
root=$(cd "$(dirname "$0")/../.." && pwd)
build=$(cd "$1" && pwd)
stage=$(cd "$2" && pwd)
sandbox=$(mktemp -d /tmp/win7-taskbar-native-check.XXXXXXXX)
mkdir -p "$sandbox"/{home,config,data,cache,runtime}
chmod 700 "$sandbox/runtime"
env HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" XDG_DATA_HOME="$sandbox/data" \
    XDG_CACHE_HOME="$sandbox/cache" XDG_RUNTIME_DIR="$sandbox/runtime" \
    XDG_DATA_DIRS="$stage/share:/usr/local/share:/usr/share" QT_PLUGIN_PATH="$stage/plugins" \
    QT_QPA_PLATFORM=offscreen dbus-run-session --config-file="$root/tests/taskbar/session-bus.conf" -- \
    "$build/preview-native-check" "$stage/plugins/plasma/applets/liblocal.win7.seventasks.preview.so"
