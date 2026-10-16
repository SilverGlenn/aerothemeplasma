/* SPDX-License-Identifier: GPL-2.0-or-later */
import org.kde.plasma.workspace.dbus as DBus

DBus.SignalWatcher {
    id: watcher
    busType: DBus.BusType.Session
    service: "org.kde.kglobalaccel"
    path: "/component/kmix"
    iface: "org.kde.kglobalaccel.Component"

    signal volumeAdjusted()
    signal playbackMuteToggled()

    function dispatchShortcut(component, shortcut) {
        // D-Bus delivers typed string wrappers, not plain JavaScript strings.
        component = String(component);
        shortcut = String(shortcut);
        if (component !== "kmix") {
            return;
        }
        if (["increase_volume", "decrease_volume",
             "increase_volume_small", "decrease_volume_small"].indexOf(shortcut) !== -1) {
            volumeAdjusted();
        } else if (shortcut === "mute") {
            playbackMuteToggled();
        }
    }

    function dbusglobalShortcutPressed(component, shortcut, timestamp) {
        dispatchShortcut(component, shortcut);
    }
    function dbusglobalShortcutRepeated(component, shortcut, timestamp) {
        if (String(shortcut) !== "mute") {
            dispatchShortcut(component, shortcut);
        }
    }
    function dbusglobalShortcutReleased(component, shortcut, timestamp) {}
}
