/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import QtQuick.Controls as Controls

Controls.Button {
    id: control
    implicitHeight: Math.max(20, implicitContentHeight + 4)
    implicitWidth: implicitContentWidth
    padding: 0
    hoverEnabled: true
    activeFocusOnTab: true
    background: null
    Accessible.role: Accessible.Link
    Accessible.name: text

    contentItem: Text {
        text: control.text
        textFormat: Text.PlainText
        font.family: control.font.family
        font.pointSize: control.font.pointSize
        font.weight: control.font.weight
        font.underline: control.hovered || control.visualFocus
        color: control.enabled ? "#0066cc" : "#738295"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
}
