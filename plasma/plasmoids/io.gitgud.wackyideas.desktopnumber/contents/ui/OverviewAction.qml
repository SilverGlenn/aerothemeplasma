/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQml
import org.kde.plasma.workspace.dbus as DBus

QtObject {
    // Kept injectable so tests never activate the real desktop overview.
    property var sessionBus: DBus.SessionBus

    function trigger() {
        sessionBus.asyncCall({
            service: "org.kde.KWin",
            path: "/component/kwin",
            iface: "org.kde.kglobalaccel.Component",
            member: "invokeShortcut",
            // This installation requires the explicit default shortcut context.
            arguments: [new DBus.string("Overview"), new DBus.string("default")],
            signature: "(ss)"
        }, function(reply) {
        }, function(error) {
            console.warn("Desktop Number: could not open Overview:", error.message);
        });
    }
}
