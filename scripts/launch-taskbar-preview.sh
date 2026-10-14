#!/bin/bash
set -euo pipefail
if [[ $# != 1 ]]; then echo "Usage: $0 STAGE_PREFIX" >&2; exit 2; fi
stage=$(cd "$1" && pwd)
id=local.win7.seventasks.preview
[[ -f "$stage/share/plasma/plasmoids/$id/metadata.json" && -f "$stage/plugins/plasma/applets/lib$id.so" ]] || { echo 'Incomplete native preview stage' >&2; exit 2; }
# Fail before launching any bus/app if the dedicated viewer is unavailable.
command -v plasmoidviewer >/dev/null || { echo 'plasmoidviewer unavailable: use component tests and native-check; do not restart Plasma' >&2; exit 3; }
root=$(cd "$(dirname "$0")/.." && pwd)
sandbox=$(mktemp -d /tmp/win7-taskbar-viewer.XXXXXXXX)
mkdir -p "$sandbox"/{home,config,data,cache,runtime}
chmod 700 "$sandbox/runtime"
echo "Private viewer sandbox: $sandbox"
env HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" XDG_DATA_HOME="$sandbox/data" \
    XDG_CACHE_HOME="$sandbox/cache" XDG_RUNTIME_DIR="$sandbox/runtime" \
    XDG_DATA_DIRS="$stage/share:/usr/local/share:/usr/share" \
    QT_PLUGIN_PATH="$stage/plugins" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    dbus-run-session --config-file="$root/tests/taskbar/session-bus.conf" -- \
    plasmoidviewer --applet "$id"
