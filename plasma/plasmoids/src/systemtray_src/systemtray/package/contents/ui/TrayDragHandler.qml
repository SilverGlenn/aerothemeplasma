/* SPDX-License-Identifier: LGPL-2.0-or-later */
import QtQuick

Item {
    id: dragSource

    required property TrayDragController controller
    required property Item imageItem
    required property string itemId
    property bool hidden: false
    property bool held: false
    property bool suppressClick: false
    property bool nativeDragRunning: false

    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.MoveAction
    Drag.proposedAction: Qt.MoveAction
    Drag.mimeData: ({ [controller.mimeType]: itemId, [controller.sessionMimeType]: itemId })
    Drag.hotSpot: Qt.point(imageItem.width / 2, imageItem.height / 2)
    Drag.onDragFinished: action => {
        dragSource.Drag.active = false;
        nativeDragRunning = false;
        held = false;
        controller.finish(action);
    }

    Component.onDestruction: {
        if (held) {
            held = false;
            dragSource.Drag.cancel();
            if (controller) {
                controller.finish(Qt.IgnoreAction);
            }
        }
    }

    DragHandler {
        id: handler
        parent: dragSource.parent
        target: null
        acceptedButtons: Qt.LeftButton
        enabled: dragSource.itemId !== ""

        onActiveChanged: {
            if (active) {
                if (!dragSource.controller.begin(dragSource.itemId, dragSource.hidden)) {
                    return;
                }
                dragSource.held = true;
                dragSource.suppressClick = true;
                const grabbed = dragSource.imageItem.grabToImage(result => {
                    if (!handler.active || !dragSource.held) {
                        return;
                    }
                    // Qt remembers the size of the previous grab; clear it
                    // before loading a new grab URL with its own dimensions.
                    dragSource.Drag.imageSourceSize = Qt.size(-1, -1);
                    dragSource.Drag.imageSource = result.url;
                    dragSource.nativeDragRunning = true;
                    dragSource.Drag.active = true;
                });
                if (!grabbed) {
                    dragSource.held = false;
                    dragSource.controller.finish(Qt.IgnoreAction);
                }
            } else if (dragSource.held && !dragSource.nativeDragRunning) {
                dragSource.held = false;
                dragSource.controller.finish(Qt.IgnoreAction);
            }
        }
    }
}
