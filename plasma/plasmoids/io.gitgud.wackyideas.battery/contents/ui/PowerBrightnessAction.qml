/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQml

QtObject {
    property var applets: []
    readonly property QtObject brightnessApplet: {
        for (let i = 0; i < applets.length; ++i) {
            if (applets[i].pluginName === "org.kde.plasma.brightness") {
                return applets[i];
            }
        }
        return null;
    }
    readonly property bool available: brightnessApplet !== null

    function activate() {
        if (!brightnessApplet) {
            return false;
        }
        brightnessApplet.activated();
        return true;
    }
}
