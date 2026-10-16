/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Controls.Button {
    id: control

    implicitWidth: Math.max(100, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(26, implicitContentHeight + topPadding + bottomPadding)
    leftPadding: 12
    rightPadding: 12
    topPadding: 4
    bottomPadding: 4
    hoverEnabled: true
    activeFocusOnTab: true
    font: Kirigami.Theme.defaultFont

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? "#1b1b1b" : "#777777"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }

    background: Rectangle {
        radius: 3
        border.width: 1
        border.color: !control.enabled ? "#b4b4b4"
            : control.down ? "#2c628b"
            : control.activeFocus || control.hovered ? "#3c7fb1" : "#7f8c99"
        gradient: Gradient {
            GradientStop {
                position: 0
                color: !control.enabled ? "#f4f4f4" : control.down ? "#d0e7f5"
                    : control.hovered ? "#f1faff" : "#fafcfe"
            }
            GradientStop {
                position: 0.48
                color: !control.enabled ? "#eeeeee" : control.down ? "#b5d6eb"
                    : control.hovered ? "#dceffc" : "#ecf0f5"
            }
            GradientStop {
                position: 0.49
                color: !control.enabled ? "#e9e9e9" : control.down ? "#a5cbe3"
                    : control.hovered ? "#cce6f8" : "#e2e8ef"
            }
            GradientStop {
                position: 1
                color: !control.enabled ? "#e9e9e9" : control.down ? "#c6e3f5"
                    : control.hovered ? "#e1f3ff" : "#edf2f7"
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 2
            color: "transparent"
            border.color: control.activeFocus ? "#8bd0f5" : "#ffffff"
            opacity: control.down ? 0.55 : 0.9
        }

        // A distinct inset focus rectangle, not just a hover-color change.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 1
            color: "transparent"
            border.color: "#4b6f8e"
            visible: control.visualFocus
        }
    }

    Accessible.name: text
}
