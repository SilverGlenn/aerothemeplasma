#!/usr/bin/env bash
# Build a separate preview and open it in Plasma's existing windowed applet host.
# Never installs a widget, edits a panel, or restarts Plasma.
set -euo pipefail
mode=interactive
case "${1:-}" in
    '') ;;
    --prepare-only) mode=prepare ;;
    --headless) mode=headless ;;
    -h|--help)
        echo "Usage: $0 [--prepare-only|--headless]"
        echo "Default: visible standalone window using your real desktop's tasks."
        echo "Close that window to stop; your existing panel stays unchanged."
        exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
esac
if (( $# > 1 )); then echo "Expected at most one option" >&2; exit 2; fi
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for command in cmake python3 plasmawindowed dbus-run-session flock; do
    command -v "$command" >/dev/null || { echo "Required command unavailable: $command" >&2; exit 3; }
done
if [[ "$mode" == interactive && -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" ]]; then
    echo "Run this from a terminal in your desktop session, or use --headless." >&2
    exit 3
fi
cache="${XDG_CACHE_HOME:-$HOME/.cache}/aerothemeplasma-win7-preview"
mkdir -p -- "$cache"
cache=$(cd -- "$cache" && pwd)
# Serialize only build/staging, not the running preview window.
exec 9>"$cache/build.lock"
flock 9
printf 'Preparing independent preview in %s\n' "$cache"
cmake -S "$root/scripts/preview-native" -B "$cache/native" >"$cache/configure.log" 2>&1 || {
    tail -50 "$cache/configure.log" >&2; exit 1;
}
cmake --build "$cache/native" -j2 >"$cache/build.log" 2>&1 || {
    tail -50 "$cache/build.log" >&2; exit 1;
}
python3 "$root/scripts/stage-taskbar-preview.py" stage "$cache/stage" \
    --native-build "$cache/native" >"$cache/stage.log" 2>&1 || {
    tail -50 "$cache/stage.log" >&2; exit 1;
}
flock -u 9
exec 9>&-
if [[ "$mode" == prepare ]]; then
    printf 'Ready. Run %s to open the preview window.\n' "$0"
    exit 0
fi
profile=$(mktemp -d "$cache/window.XXXXXXXX")
mkdir -p "$profile"/{config,data,cache,runtime,home}
chmod 700 "$profile/runtime"
# Read-only copies of UI preferences, never panel/session layout or shortcuts.
config_source="${XDG_CONFIG_HOME:-$HOME/.config}"
for file in kdeglobals plasmarc; do
    if [[ -f "$config_source/$file" ]]; then cp -- "$config_source/$file" "$profile/config/$file"; fi
done
user_data="${XDG_DATA_HOME:-$HOME/.local/share}"
data_dirs="$cache/stage/share:$user_data:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
plugin_dirs="$cache/stage/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
log="$profile/host.log"
printf 'Preview settings/log: %s\n' "$profile"
if [[ "$mode" == headless ]]; then
    # Private bus/runtime and no compositor connection for automated load checks.
    exec env HOME="$profile/home" XDG_CONFIG_HOME="$profile/config" \
        XDG_DATA_HOME="$profile/data" XDG_CACHE_HOME="$profile/cache" \
        XDG_RUNTIME_DIR="$profile/runtime" XDG_CONFIG_DIRS="$profile/config" \
        XDG_DATA_DIRS="$data_dirs" QT_PLUGIN_PATH="$plugin_dirs" \
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        dbus-run-session --config-file="$root/tests/taskbar/session-bus.conf" -- \
        plasmawindowed local.win7.seventasks.preview >"$log" 2>&1
fi
printf '%s\n' 'Opening a separate window; the current panel is not replaced.' \
    'Its buttons operate REAL windows: use Close/Minimize/Launch deliberately.'
# Keep HOME (fonts), runtime/display and the session bus for real window-model
# access. Only this host's config/data/cache are redirected. Programs launched
# from it may inherit those private XDG paths; this is a test, not a replacement.
exec env XDG_CONFIG_HOME="$profile/config" XDG_DATA_HOME="$profile/data" \
    XDG_CACHE_HOME="$profile/cache" XDG_DATA_DIRS="$data_dirs" \
    QT_PLUGIN_PATH="$plugin_dirs" \
    plasmawindowed local.win7.seventasks.preview >"$log" 2>&1
