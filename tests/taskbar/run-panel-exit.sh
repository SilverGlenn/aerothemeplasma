#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
sandbox=$(mktemp -d /tmp/win7-panel-exit-test.XXXXXXXX)
trap 'rm -rf -- "$sandbox"' EXIT
mkdir -p "$sandbox"/{home,config,data,cache,runtime}
chmod 700 "$sandbox/runtime"
qml_root=$(qtpaths6 --query QT_INSTALL_QML)
for scale in 1 1.25 1.5; do
    env HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" XDG_DATA_HOME="$sandbox/data" \
        XDG_CACHE_HOME="$sandbox/cache" XDG_RUNTIME_DIR="$sandbox/runtime" \
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_SCALE_FACTOR="$scale" \
        QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough \
        dbus-run-session --config-file="$root/tests/taskbar/session-bus.conf" -- \
        /usr/lib/qt6/bin/qmltestrunner -input "$root/tests/taskbar/panel-preview" -import "$qml_root"
done
