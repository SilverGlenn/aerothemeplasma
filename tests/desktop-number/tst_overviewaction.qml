/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import QtTest
import "../../plasma/plasmoids/io.gitgud.wackyideas.desktopnumber/contents/ui" as Widget

Item {
    QtObject {
        id: mockBus
        property int calls: 0
        property var lastMessage: null
        property bool fail: false

        function asyncCall(message, resolve, reject) {
            calls++;
            lastMessage = message;
            if (fail) {
                reject({message: "Overview service unavailable"});
            } else {
                resolve({value: []});
            }
        }
    }

    Widget.OverviewAction {
        id: action
        sessionBus: mockBus
    }

    TestCase {
        name: "DesktopNumberOverviewAction"

        function init() {
            mockBus.calls = 0;
            mockBus.lastMessage = null;
            mockBus.fail = false;
        }

        function test_does_not_activate_on_creation() {
            compare(mockBus.calls, 0);
        }

        function test_activation_invokes_overview_exactly_once() {
            action.trigger();
            compare(mockBus.calls, 1);
            compare(mockBus.lastMessage.service, "org.kde.KWin");
            compare(mockBus.lastMessage.path, "/component/kwin");
            compare(mockBus.lastMessage.iface, "org.kde.kglobalaccel.Component");
            compare(mockBus.lastMessage.member, "invokeShortcut");
            compare(mockBus.lastMessage.signature, "(ss)");
            compare(mockBus.lastMessage.arguments.length, 2);
            compare(mockBus.lastMessage.arguments[0].value, "Overview");
            compare(mockBus.lastMessage.arguments[1].value, "default");
        }

        function test_dbus_failure_is_reported_without_throwing() {
            mockBus.fail = true;
            ignoreWarning("Desktop Number: could not open Overview: Overview service unavailable");
            action.trigger();
            compare(mockBus.calls, 1);
        }
    }
}
