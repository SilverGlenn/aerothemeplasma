#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dest="${XDG_DATA_HOME:-$HOME/.local/share}/kwin/scripts/aerooverview"
if [[ "$(qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded overview)" != true ]]; then
    echo "The built-in overview must be enabled first." >&2
    exit 1
fi
# Do not replace a native plugin while the running QML engine has it mapped.
cmake -S "$root" -B "$root/build" -G Ninja
cmake --build "$root/build"
mkdir -p "$dest/contents/ui/native"
cp "$root/metadata.json" "$dest/"
cp -a "$root/contents/ui/." "$dest/contents/ui/"
cp "$root/native/qmldir" "$dest/contents/ui/native/"
# Install via rename, so a mapped old inode is never truncated.
cp "$root/build/native/libaerooverviewplugin.so" "$dest/contents/ui/native/libaerooverviewplugin.so.new"
mv "$dest/contents/ui/native/libaerooverviewplugin.so.new" "$dest/contents/ui/native/libaerooverviewplugin.so"
if [[ "$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded aerooverview)" == true ]]; then
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript aerooverview
fi
kwriteconfig6 --file kwinrc --group Plugins --key aerooverviewEnabled true
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure
echo "Installed local Aero overview. Close/reopen Overview to see it."
