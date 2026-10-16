/* SPDX-License-Identifier: LGPL-2.0-or-later */
import QtQuick
import QtQuick.Window
import QtQml.Models
import QtTest
import org.kde.kitemmodels as KItemModels
import "../../plasma/plasmoids/src/systemtray_src/systemtray/package/contents/ui" as Tray

Item {
    id: harness
    width: 300
    height: 100
    property var instance

    Component {
        id: fixture
        Item {
            id: tray
            width: 300
            height: 100
            property bool reverseRegistration: false
            property alias controller: controller
            property alias ordering: ordering
            property alias panelModel: panelModel
            property alias drawerModel: drawerModel
            property alias panelView: panelView
            property alias drawerView: drawerView
            property alias panelDrop: panelDrop
            property alias drawerDrop: drawerDrop
            property int finishedCount: 0

            ListModel { id: entries }

            function syncVisibility() {
                const config = nativeSettings.configuration;
                for (let i = 0; i < entries.count; ++i) {
                    const entry = entries.get(i);
                    const status = config.shownItems.indexOf(entry.itemId) !== -1 ? 1
                        : config.hiddenItems.indexOf(entry.itemId) !== -1 ? 0 : entry.defaultStatus;
                    entries.setProperty(i, "effectiveStatus", status);
                }
            }

            Component.onCompleted: {
                let ids = ["one", "five", "two", "three", "four"];
                if (reverseRegistration) ids.reverse();
                for (const id of ids) {
                    const status = id === "one" || id === "five" ? 1 : 0;
                    entries.append({itemId: id, effectiveStatus: status, defaultStatus: status});
                }
                syncVisibility();
            }

            Tray.TrayOrdering { id: ordering; configuration: nativeSettings.configuration }
            Tray.TrayDragController {
                id: controller
                configuration: nativeSettings.configuration
                onReorderRequested: (itemId, hidden, targetId) => {
                    visibleItemIds = ordering.itemIds(panelModel);
                    ordering.move(hidden ? drawerModel : panelModel, itemId, targetId);
                }
                onFinished: {
                    tray.syncVisibility();
                    ++tray.finishedCount;
                }
            }
            Tray.OrderedTrayModel {
                id: panelModel
                ordering: ordering
                model: KItemModels.KSortFilterProxyModel {
                    sourceModel: entries
                    filterRoleName: "effectiveStatus"
                    filterRowCallback: (row, parent) => sourceModel.data(sourceModel.index(row, 0, parent), filterRole) === 1
                }
                delegate: Tray.TrayDropArea {
                    required property string itemId
                    width: 40
                    height: 40
                    controller: tray.controller
                    targetItemId: itemId
                }
            }
            Tray.OrderedTrayModel {
                id: drawerModel
                ordering: ordering
                model: KItemModels.KSortFilterProxyModel {
                    sourceModel: entries
                    filterRoleName: "effectiveStatus"
                    filterRowCallback: (row, parent) => sourceModel.data(sourceModel.index(row, 0, parent), filterRole) === 0
                }
                delegate: Tray.TrayDropArea {
                    required property string itemId
                    width: 40
                    height: 40
                    controller: tray.controller
                    hidden: true
                    targetItemId: itemId
                }
            }
            Tray.TrayDropArea {
                id: panelDrop
                anchors.fill: parent
                controller: controller
                GridView {
                    id: panelView
                    width: parent.width
                    height: 40
                    cellWidth: 40
                    cellHeight: 40
                    model: panelModel
                }
            }
            Window {
                width: 120
                height: 100
                visible: true
                Tray.TrayDropArea {
                    id: drawerDrop
                    anchors.fill: parent
                    controller: controller
                    hidden: true
                    GridView {
                        id: drawerView
                        width: parent.width
                        height: 40
                        cellWidth: 40
                        cellHeight: 40
                        model: drawerModel
                    }
                }
            }
        }
    }

    TestCase {
        name: "SystemTraySavedOrdering"
        when: windowShown

        function init() {
            nativeSettings.reset();
            instance = createTemporaryObject(fixture, harness);
            verify(instance);
            tryCompare(instance.panelModel.items, "count", 2);
            tryCompare(instance.drawerModel.items, "count", 3);
        }

        function cleanup() {
            instance.destroy();
            instance = null;
            wait(0);
        }

        function ids(hidden) {
            return instance.ordering.itemIds(hidden ? instance.drawerModel : instance.panelModel);
        }

        function move(id, fromHidden, toHidden, targetId) {
            const previous = instance.finishedCount;
            const grid = toHidden ? instance.drawerView : instance.panelView;
            const targetIndex = ids(toHidden).indexOf(targetId);
            if (targetIndex !== -1) tryVerify(() => grid.itemAtIndex(targetIndex) !== null && grid.itemAtIndex(targetIndex).targetItemId === targetId);
            const target = targetIndex === -1 ? (toHidden ? instance.drawerDrop : instance.panelDrop) : grid.itemAtIndex(targetIndex);
            verify(target);
            verify(instance.controller.begin(id, fromHidden));
            compare(nativeDrag.drop(target, instance.controller.mimeType, id, instance.controller.sessionMimeType), Qt.MoveAction);
            instance.controller.finish(Qt.MoveAction);
            tryCompare(instance, "finishedCount", previous + 1);
            wait(0);
        }

        function restart() {
            instance.destroy();
            wait(0);
            nativeSettings.reload();
            instance = createTemporaryObject(fixture, harness, {reverseRegistration: true});
            verify(instance);
            wait(0);
        }

        function test_reorderDrawerBothDirectionsAndAppend() {
            move("four", true, true, "two");
            compare(ids(true), ["four", "two", "three"]);
            move("four", true, true, "three");
            compare(ids(true), ["two", "three", "four"]);
            move("two", true, true, "");
            compare(ids(true), ["three", "four", "two"]);
            restart();
            compare(ids(true), ["three", "four", "two"]);
            compare(ids(false), ["five", "one"]);
        }

        function test_crossWindowMovesAndBothOrdersSurviveRestart() {
            move("one", false, true, "three");
            compare(ids(true), ["two", "one", "three", "four"]);
            compare(ids(false), ["five"]);
            move("four", true, false, "five");
            compare(ids(false), ["four", "five"]);
            compare(ids(true), ["two", "one", "three"]);
            move("three", true, true, "two");
            compare(ids(true), ["three", "two", "one"]);
            restart();
            compare(ids(false), ["four", "five"]);
            compare(ids(true), ["three", "two", "one"]);
            compare(Array.from(nativeSettings.configuration.shownItems), ["four"]);
            compare(Array.from(nativeSettings.configuration.hiddenItems), ["one"]);
        }

        function test_drawerOrderDoesNotChangeSavedPanelOrder() {
            move("one", false, false, "five");
            compare(ids(false), ["five", "one"]);
            move("four", true, true, "two");
            compare(ids(true), ["four", "two", "three"]);
            restart();
            compare(ids(false), ["five", "one"]);
            compare(ids(true), ["four", "two", "three"]);
        }

        function test_invalidSavedOrderDoesNotBreakDragging() {
            nativeSettings.configuration.itemOrdering = "invalid JSON";
            move("three", true, true, "two");
            compare(ids(true), ["three", "two", "four"]);
            restart();
            compare(ids(true), ["three", "two", "four"]);
        }
    }
}
