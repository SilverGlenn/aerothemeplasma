#!/usr/bin/env bash
set -euo pipefail
kwriteconfig6 --file kwinrc --group Plugins --key aerooverviewEnabled false
if [[ "$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded aerooverview)" == true ]]; then
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript aerooverview
fi
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure
echo "Stock overview restored; desktop-switch popup setting was not changed."
