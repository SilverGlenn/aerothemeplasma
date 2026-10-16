#!/usr/bin/env bash
# Install just the desktop-number applet, never the entire theme.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
id=io.gitgud.wackyideas.desktopnumber
package="$root/plasma/plasmoids/$id"
mode="${1:-}"
case "$mode" in
    ""|--enable|--disable) ;;
    *) echo "Usage: $0 [--enable|--disable]" >&2; exit 2 ;;
esac

if [[ "$mode" != --disable ]]; then
    if [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/$id" ]]; then
        kpackagetool6 --type Plasma/Applet --upgrade "$package"
    else
        kpackagetool6 --type Plasma/Applet --install "$package"
    fi
fi

if [[ -n "$mode" ]]; then
    enabled=false
    [[ "$mode" == --enable ]] && enabled=true
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
        var pluginId = '$id';
        var enable = $enabled;
        var updated = 0;
        panels().forEach(function(panel) {
            panel.widgets().forEach(function(widget) {
                if (widget.type !== 'io.gitgud.wackyideas.systemtray'
                        && widget.type !== 'org.kde.plasma.systemtray') {
                    return;
                }
                var previousGroup = widget.currentConfigGroup;
                widget.currentConfigGroup = ['General'];
                ['extraItems', 'shownItems', 'knownItems'].forEach(function(key) {
                    var items = widget.readConfig(key, []);
                    items = items.filter(function(item) { return item !== pluginId; });
                    if (enable || key === 'knownItems') {
                        items.push(pluginId);
                    }
                    widget.writeConfig(key, items);
                });
                var hidden = widget.readConfig('hiddenItems', []);
                widget.writeConfig('hiddenItems', hidden.filter(function(item) {
                    return item !== pluginId;
                }));
                widget.currentConfigGroup = previousGroup;
                updated++;
            });
        });
        print((enable ? 'Enabled' : 'Disabled') + ' Desktop Number in ' + updated + ' tray(s).');
    "
else
    echo 'Installed Desktop Number. Enable it in System Tray Settings → Entries.'
    echo 'Or run this script again with --enable to show it in the current tray.'
fi
