/* SPDX-License-Identifier: LGPL-2.0-or-later */
import QtQuick

DropArea {
    required property TrayDragController controller
    property bool hidden: false
    property string targetItemId: ""

    keys: [controller.mimeType]
    onEntered: event => { event.accepted = controller.accepts(event); }
    onDropped: event => { controller.drop(event, hidden, targetItemId); }
}
