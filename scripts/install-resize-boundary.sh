#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
id=taskbarresizeguard
mode="${1:---enable}"
case "$mode" in
    --enable|--disable|--uninstall) ;;
    *) echo "Usage: $0 [--enable|--disable|--uninstall]" >&2; exit 2 ;;
esac
if (( $# > 1 )); then echo "Expected at most one option" >&2; exit 2; fi
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
# Same lookup as migration-uninstall.sh: Arch ships qdbus6, Fedora qdbus-qt6.
qdbus_bin=
for candidate in qdbus6 qdbus-qt6 qdbus; do
    if command -v "$candidate" >/dev/null; then qdbus_bin="$(command -v "$candidate")"; break; fi
done
if [[ -z "$qdbus_bin" ]]; then
    echo "qdbus6, qdbus-qt6 and qdbus were not found. Stopping." >&2
    exit 3
fi

if [[ "$mode" == --enable ]]; then
    package="$root/plasma/kwin-scripts/$id"
    if [[ -d "/usr/share/kwin/scripts/$id" ]]; then
        echo "Warning: the theme install already provides a system-wide $id;" >&2
        echo "this installs a user-local copy that overrides it. Use --uninstall to remove the copy." >&2
    fi
    if [[ -d "$data_home/kwin/scripts/$id" ]]; then
        kpackagetool6 --type KWin/Script --upgrade "$package"
    else
        kpackagetool6 --type KWin/Script --install "$package"
    fi
fi
if [[ "$("$qdbus_bin" org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded "$id")" == true ]]; then
    "$qdbus_bin" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$id"
fi
enabled=false
[[ "$mode" == --enable ]] && enabled=true
if [[ "$mode" == --uninstall ]]; then
    # The script is unloaded above. Drop the user-local package and, when the theme
    # provides a system-wide copy, the user's override so its default applies again.
    if [[ -d "$data_home/kwin/scripts/$id" ]]; then
        kpackagetool6 --type KWin/Script --remove "$id"
    fi
    if [[ -d "/usr/share/kwin/scripts/$id" ]]; then
        kwriteconfig6 --file kwinrc --group Plugins --key "${id}Enabled" --delete
    else
        kwriteconfig6 --file kwinrc --group Plugins --key "${id}Enabled" false
    fi
    "$qdbus_bin" org.kde.KWin /KWin org.kde.KWin.reconfigure
    echo 'Removed the user-local taskbar resize boundary; the system copy (if installed) follows its default.'
    exit 0
fi
kwriteconfig6 --file kwinrc --group Plugins --key "${id}Enabled" "$enabled"
"$qdbus_bin" org.kde.KWin /KWin org.kde.KWin.reconfigure
# Reconfiguration schedules script loading on the next compositor event turn.
applied=false
for attempt in {1..20}; do
    if [[ "$("$qdbus_bin" org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded "$id")" == "$enabled" ]]; then
        applied=true
        break
    fi
    sleep 0.1
done
if [[ "$applied" != true ]]; then
    echo 'KWin did not apply the resize boundary setting.' >&2
    exit 1
fi
echo "Taskbar resize boundary enabled: $enabled"
