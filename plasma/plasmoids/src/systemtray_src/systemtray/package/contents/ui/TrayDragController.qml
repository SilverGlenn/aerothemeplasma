/* SPDX-License-Identifier: LGPL-2.0-or-later */
import QtQuick

QtObject {
    id: controller

    required property var configuration
    property var visibleItemIds: []
    readonly property string mimeType: "application/x-aerotheme-systemtray-item"
    readonly property string instanceToken: Date.now().toString(36) + "-" + Math.floor(Math.random() * 1e10).toString(36)
    property int sessionSerial: 0
    readonly property string sessionMimeType: "application/x-aerotheme-systemtray-session-" + instanceToken + "-" + sessionSerial
    readonly property bool active: itemId !== ""
    property string itemId: ""
    property bool fromHidden: false
    property bool dropPending: false
    property bool targetHidden: false
    property string targetItemId: ""

    signal reorderRequested(string itemId, bool hidden, string targetItemId)
    signal finished()

    function begin(id, hidden) {
        if (active || !id) {
            return false;
        }
        ++sessionSerial;
        itemId = id;
        fromHidden = hidden;
        dropPending = false;
        targetItemId = "";
        return true;
    }

    function accepts(event) {
        // Reading our own native MIME payload can deadlock Qt Wayland's data
        // transfer and destroy its data source. Validate the unique drag format
        // instead; the item ID is already held by this tray's active session.
        return active && event.formats.indexOf(mimeType) !== -1
            && event.formats.indexOf(sessionMimeType) !== -1;
    }

    function drop(event, hidden, targetId) {
        event.accepted = false;
        if (!accepts(event)) {
            return;
        }
        targetHidden = hidden;
        targetItemId = targetId || "";
        dropPending = true;
        event.accept(Qt.MoveAction);
    }

    function finish(action) {
        if (!active) {
            return;
        }
        const id = itemId;
        const hidden = targetHidden;
        const targetId = targetItemId;
        const move = dropPending && action === Qt.MoveAction;
        const changeVisibility = move && fromHidden !== hidden;
        itemId = "";
        dropPending = false;

        // Changing the filtered models destroys the source delegate. Wait
        // until the native drag's nested event loop has returned first.
        Qt.callLater(() => {
            if (move) {
                reorderRequested(id, hidden, targetId);
            }
            if (changeVisibility) {
                let shown = Array.from(configuration.shownItems).filter(value => value !== id);
                const hiddenItems = Array.from(configuration.hiddenItems).filter(value => value !== id);
                if (hidden) {
                    if (configuration.showAllItems) {
                        // Keep every other currently visible icon on the panel.
                        shown = shown.concat(visibleItemIds).filter((value, index, values) => value !== id && values.indexOf(value) === index);
                    }
                    hiddenItems.push(id);
                } else {
                    shown.push(id);
                }
                configuration.shownItems = shown;
                configuration.hiddenItems = hiddenItems;
                configuration.disabledStatusNotifiers = Array.from(configuration.disabledStatusNotifiers).filter(value => value !== id);
                if (hidden) {
                    configuration.showAllItems = false;
                }
                configuration.writeConfig();
            }
            finished();
        });
    }
}
