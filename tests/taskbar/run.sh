#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
output=${1:-$(mktemp -d /tmp/win7-taskbar-tests.XXXXXXXX)}
mkdir -p "$output"
output=$(cd "$output" && pwd)
export SOURCE_ROOT="$root" TASKBAR_TEST_OUTPUT="$output"
python3 "$root/tests/taskbar/generate-fixtures.py"
node "$root/tests/taskbar/policy-tests.js" "$root/plasma/plasmoids/io.gitgud.wackyideas.seventasks/contents/ui" | tee "$output/policy.log"
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
            /usr/lib/qt6/bin/qmltestrunner -input "$output/$suite" \
            -import /usr/lib/x86_64-linux-gnu/qt6/qml 2>&1 | tee "$output/$suite-$scale.log"
    done
done
printf 'Evidence: %s\n' "$output"
