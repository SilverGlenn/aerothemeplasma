/* SPDX-License-Identifier: LGPL-2.0-or-later */
import QtQuick
import QtQuick.Window
import QtTest
import "../../plasma/plasmoids/src/systemtray_src/systemtray/package/contents/ui" as Tray

Item {
    id: harness
    width: 360
    height: 180
    property int clicks: 0

    QtObject {
        id: config
        property var shownItems: []
        property var hiddenItems: []
        property bool showAllItems: false
        property var disabledStatusNotifiers: []
        property int writes: 0
        function writeConfig() { ++writes; }
    }

    Tray.TrayDragController {
        id: controller
        configuration: config
        visibleItemIds: ["one", "two", "three"]
    }
    SignalSpy { id: reorderSpy; target: controller; signalName: "reorderRequested" }
    SignalSpy { id: finishedSpy; target: controller; signalName: "finished" }

    Tray.TrayDropArea {
        id: panel
        x: 220
        width: 140
        height: 180
        controller: controller
        Tray.TrayDropArea {
            id: positionedIcon
            width: 40
            height: 40
            controller: controller
            targetItemId: "two"
        }
    }

    Window {
        id: drawerWindow
        width: 120
        height: 120
        visible: true
        Tray.TrayDropArea {
            id: drawer
            anchors.fill: parent
            controller: controller
            hidden: true
        }
    }

    // Like the existing applet-install drop area in main.qml, this overlay
    // rejects tray MIME data so the background target can receive it.
    Item {
        anchors.fill: parent
        MouseArea {
            anchors.fill: parent
            DropArea {
                anchors.fill: parent
                onEntered: event => { event.accepted = false; }
            }
        }
    }

    Rectangle {
        id: icon
        x: 30
        y: 30
        width: 40
        height: 40
        color: "blue"
        MouseArea {
            id: clickArea
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: source.suppressClick = false
            onClicked: if (!source.suppressClick) ++harness.clicks
        }
        Tray.TrayDragHandler {
            id: source
            parent: clickArea
            anchors.fill: parent
            controller: controller
            imageItem: icon
            itemId: "one"
        }
    }

    TestCase {
        name: "SystemTrayDrag"
        when: windowShown

        function init() {
            config.shownItems = ["one"];
            config.hiddenItems = ["two"];
            config.showAllItems = false;
            config.disabledStatusNotifiers = [];
            config.writes = 0;
            harness.clicks = 0;
            reorderSpy.clear();
            finishedSpy.clear();
            source.hidden = false;
        }

        function cleanup() {
            if (controller.active) controller.finish(Qt.IgnoreAction);
            wait(0);
        }

        function finishMove() {
            controller.finish(Qt.MoveAction);
            tryCompare(finishedSpy, "count", 1);
        }

        function test_panelToDrawerAcrossWindows() {
            verify(panel.Window.window !== drawer.Window.window);
            verify(controller.begin("one", false));
            compare(nativeDrag.drop(drawer, controller.mimeType, "one", controller.sessionMimeType), Qt.MoveAction);
            // The source model must survive until the native drag returns.
            compare(config.writes, 0);
            finishMove();
            compare(config.shownItems, []);
            compare(config.hiddenItems, ["two", "one"]);
            compare(config.writes, 1);
        }

        function test_drawerToPanelWhitespace() {
            verify(controller.begin("two", true));
            compare(nativeDrag.drop(panel, controller.mimeType, "two", controller.sessionMimeType), Qt.MoveAction);
            finishMove();
            compare(config.shownItems, ["one", "two"]);
            compare(config.hiddenItems, []);
            compare(Array.from(reorderSpy.signalArguments[0]), ["two", false, ""]);
        }

        function test_drawerToSpecificIcon() {
            verify(controller.begin("two", true));
            compare(nativeDrag.drop(positionedIcon, controller.mimeType, "two", controller.sessionMimeType), Qt.MoveAction);
            finishMove();
            compare(Array.from(reorderSpy.signalArguments[0]), ["two", false, "two"]);
        }

        function test_visibleReorderKeepsVisibilityPolicy() {
            verify(controller.begin("one", false));
            compare(nativeDrag.drop(positionedIcon, controller.mimeType, "one", controller.sessionMimeType), Qt.MoveAction);
            finishMove();
            compare(Array.from(reorderSpy.signalArguments[0]), ["one", false, "two"]);
            compare(config.writes, 0);
            compare(config.shownItems, ["one"]);
        }

        function test_showAllPreservesOtherVisibleIcons() {
            config.showAllItems = true;
            config.shownItems = ["absent", "one", "one"];
            verify(controller.begin("one", false));
            compare(nativeDrag.drop(drawer, controller.mimeType, "one", controller.sessionMimeType), Qt.MoveAction);
            finishMove();
            compare(config.showAllItems, false);
            compare(config.shownItems, ["absent", "two", "three"]);
            compare(config.hiddenItems, ["two", "one"]);
        }

        function test_stableNormalizedId() {
            config.hiddenItems = ["dropbox-client-PID"];
            verify(controller.begin("dropbox-client-PID", true));
            compare(nativeDrag.drop(panel, controller.mimeType, "dropbox-client-PID", controller.sessionMimeType), Qt.MoveAction);
            finishMove();
            compare(config.hiddenItems, []);
            compare(config.shownItems, ["one", "dropbox-client-PID"]);
        }

        function test_hidingDisabledIconFromShowAllKeepsItInDrawer() {
            config.showAllItems = true;
            config.disabledStatusNotifiers = ["one", "unrelated"];
            verify(controller.begin("one", false));
            compare(nativeDrag.drop(drawer, controller.mimeType, "one", controller.sessionMimeType), Qt.MoveAction);
            finishMove();
            compare(config.disabledStatusNotifiers, ["unrelated"]);
            verify(config.hiddenItems.indexOf("one") !== -1);
        }

        function test_cancelAfterAcceptedDrop() {
            verify(controller.begin("one", false));
            compare(nativeDrag.drop(drawer, controller.mimeType, "one", controller.sessionMimeType), Qt.MoveAction);
            controller.finish(Qt.IgnoreAction);
            tryCompare(finishedSpy, "count", 1);
            compare(config.writes, 0);
            compare(reorderSpy.count, 0);
            compare(config.shownItems, ["one"]);
        }

        function test_rejectUnrelatedOrForeignDrag() {
            compare(nativeDrag.drop(drawer, controller.mimeType, "one", controller.sessionMimeType), Qt.IgnoreAction);
            verify(controller.begin("one", false));
            compare(nativeDrag.drop(drawer, "text/plain", "one"), Qt.IgnoreAction);
            compare(nativeDrag.drop(drawer, controller.mimeType, "other", controller.sessionMimeType + "-foreign"), Qt.IgnoreAction);
            verify(!controller.dropPending);
            compare(config.writes, 0);
        }

        function test_enterDoesNotReadWaylandPayload() {
            verify(controller.begin("one", false));
            const event = {
                formats: [controller.mimeType, controller.sessionMimeType],
                getDataAsString: () => { fail("Cannot read payload before drop on Wayland"); }
            };
            verify(controller.accepts(event));
        }

        function test_dropDoesNotReadOwnWaylandPayload() {
            verify(controller.begin("one", false));
            const event = {
                formats: [controller.mimeType, controller.sessionMimeType],
                accepted: false,
                getDataAsString: () => { fail("Reading our own Wayland payload can crash Qt"); },
                accept: function(action) { this.accepted = action === Qt.MoveAction; }
            };
            controller.drop(event, true, "");
            verify(event.accepted);
            finishMove();
            compare(config.hiddenItems, ["two", "one"]);
        }

        function test_rejectPreviousDragSession() {
            verify(controller.begin("one", false));
            const previousFormat = controller.sessionMimeType;
            controller.finish(Qt.IgnoreAction);
            tryCompare(finishedSpy, "count", 1);
            verify(controller.begin("one", false));
            compare(nativeDrag.drop(drawer, controller.mimeType, "one", previousFormat), Qt.IgnoreAction);
            verify(!controller.dropPending);
        }

        function test_clickAndSmallMovementDoNotDrag() {
            mouseClick(icon, 20, 20, Qt.LeftButton);
            compare(harness.clicks, 1);
            mouseClick(icon, 20, 20, Qt.RightButton);
            mouseClick(icon, 20, 20, Qt.MiddleButton);
            compare(harness.clicks, 3);
            mousePress(icon, 20, 20, Qt.LeftButton);
            mouseMove(icon, 21, 20);
            verify(!controller.active);
            verify(!source.held);
            mouseRelease(icon, 21, 20, Qt.LeftButton);
            compare(harness.clicks, 4);
            compare(config.writes, 0);
        }

        function test_nativeDragStartsAndCleansUp_data() {
            return [{ tag: "visible", hidden: false }, { tag: "hidden", hidden: true }];
        }

        function test_nativeDragStartsAndCleansUp(data) {
            source.hidden = data.hidden;
            mousePress(icon, 20, 20, Qt.LeftButton);
            mouseMove(icon, 20 + Qt.styleHints.startDragDistance + 5, 20);
            // The offscreen platform cancels the native drag immediately.
            tryCompare(finishedSpy, "count", 1);
            verify(source.suppressClick);
            verify(!source.held);
            verify(!controller.active);
            compare(controller.fromHidden, data.hidden);
            mouseRelease(icon, 35, 20, Qt.LeftButton);
            compare(harness.clicks, 0);
            compare(config.writes, 0);
        }
    }
}
