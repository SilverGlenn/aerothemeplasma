/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Controls.TextField {
    id: field

    implicitWidth: 320
    implicitHeight: Math.max(26, contentHeight + topPadding + bottomPadding)
    leftPadding: 7
    rightPadding: 29
    topPadding: 4
    bottomPadding: 4
    font: Kirigami.Theme.defaultFont
    color: "#1b1b1b"
    placeholderText: qsTr("Search windows and apps")
    placeholderTextColor: "#626b75"
    selectionColor: "#3399ff"
    selectedTextColor: "#ffffff"
    verticalAlignment: TextInput.AlignVCenter
    selectByMouse: true
    hoverEnabled: true
    activeFocusOnTab: true
    Accessible.name: placeholderText
    Accessible.searchEdit: true
    inputMethodHints: Qt.ImhNoPredictiveText

    Shortcut {
        sequences: ["Ctrl+E", StandardKey.Find]
        enabled: field.visible && field.enabled && !field.readOnly
        onActivated: {
            field.forceActiveFocus(Qt.ShortcutFocusReason);
            field.selectAll();
        }
    }

    onActiveFocusChanged: {
        if (activeFocus) {
            selectAll();
        }
    }

    background: Rectangle {
        color: field.enabled && !field.readOnly ? "#ffffff" : "#f1f3f5"
        radius: 2
        border.color: field.activeFocus ? "#3c7fb1"
            : field.hovered ? "#6b9dc3" : "#7f9db9"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            radius: 1
            border.color: field.activeFocus ? "#b8def5" : "#edf1f5"
        }
    }

    Image {
        objectName: "searchGlyph"
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        source: "icons/search.svg"
        visible: field.length === 0
        // Instant search: this glyph is deliberately not a button.
    }

    Controls.ToolButton {
        id: clearButton
        objectName: "clearSearch"
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: field.height - 4
        visible: field.length > 0
        enabled: !field.readOnly
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.name: qsTr("Clear search")

        contentItem: Image {
            source: "icons/clear.svg"
            sourceSize: Qt.size(16, 16)
            fillMode: Image.Pad
        }
        background: Rectangle {
            color: clearButton.down ? "#c4def2" : "#e7f3fc"
            border.color: "#7da2c4"
            radius: 2
            visible: clearButton.hovered || clearButton.visualFocus || clearButton.down
        }

        Controls.ToolTip.text: qsTr("Clear search")
        Controls.ToolTip.visible: hovered
        Controls.ToolTip.delay: Kirigami.Units.toolTipDelay

        onClicked: {
            field.clear();
            field.forceActiveFocus(Qt.MouseFocusReason);
        }
    }
}
