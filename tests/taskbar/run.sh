#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
if [ -n "${1:-}" ]; then
    output=$1
else
    output=$(mktemp -d /tmp/win7-taskbar-tests.XXXXXXXX)
    # Scratch output created by this script is removed after a passing run;
    # it is kept on failure so the logs can be inspected. Pass an explicit
    # directory as $1 to keep the evidence.
    trap 'rc=$?; if [ "$rc" -eq 0 ]; then rm -rf -- "$output"; else echo "Test output kept in $output" >&2; fi' EXIT
fi
mkdir -p "$output"
output=$(cd "$output" && pwd)
qml_root=$(qtpaths6 --query QT_INSTALL_QML)
qmltestrunner=$(qtpaths6 --query QT_INSTALL_BINS)/qmltestrunner
if [ ! -x "$qmltestrunner" ]; then
    qmltestrunner=$(command -v qmltestrunner6 || command -v qmltestrunner) || {
        echo "qmltestrunner not found" >&2
        exit 1
    }
fi
export SOURCE_ROOT="$root" TASKBAR_TEST_OUTPUT="$output"
python3 "$root/tests/taskbar/generate-fixtures.py"
node "$root/tests/taskbar/policy-tests.js" "$root/plasma/plasmoids/io.gitgud.wackyideas.seventasks/contents/ui" | tee "$output/policy.log"
node "$root/tests/taskbar/shortcut-tests.js" "$root/plasma/plasmoids/io.gitgud.wackyideas.seventasks/contents/ui" | tee "$output/shortcuts.log"
for scale in 1 1.25 1.5; do
    for suite in tests previews; do
        printf 'var directory = "%s/snapshots"; var expectedDpr = %s;\n' "$output" "$scale" > "$output/$suite/SnapshotPaths.js"
    done
    sandbox="$output/sandbox-$scale"
    mkdir -p "$sandbox"/{home,config,data,cache,runtime}
    chmod 700 "$sandbox/runtime"
    for suite in tests previews; do
        env HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" XDG_DATA_HOME="$sandbox/data" \
            XDG_CACHE_HOME="$sandbox/cache" XDG_RUNTIME_DIR="$sandbox/runtime" \
            QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_SCALE_FACTOR="$scale" \
            QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough TASKBAR_SNAPSHOTS="$output/snapshots-$scale" \
            dbus-run-session --config-file="$root/tests/taskbar/session-bus.conf" -- \
            "$qmltestrunner" -input "$output/$suite" \
            -import "$qml_root" 2>&1 | tee "$output/$suite-$scale.log"
    done
done
printf 'Evidence: %s\n' "$output"
