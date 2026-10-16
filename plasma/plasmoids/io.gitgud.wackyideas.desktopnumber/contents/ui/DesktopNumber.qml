/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property int number: 0
    readonly property string displayText: number > 0 ? String(number) : ""
    // Size against the icon slot, not the taskbar height. The extra logical
    // pixel makes the hinted digit one pixel taller at the normal 16px slot.
    readonly property int numberPixelSize: Math.max(1,
        Math.floor(Math.min(width + 1, height + 1, Kirigami.Units.iconSizes.medium)))

    implicitWidth: Kirigami.Units.iconSizes.small
    implicitHeight: Kirigami.Units.iconSizes.small

    Accessible.role: Accessible.StaticText
    Accessible.name: number > 0 ? qsTr("Desktop %1").arg(number) : qsTr("Current desktop")

    Text {
        objectName: "desktopNumberLabel"
        anchors.fill: parent
        // Compared with the original -2 offset at 16px: the top stays put,
        // while the 17px hinted glyph extends its base one pixel lower.
        anchors.topMargin: -1
        anchors.bottomMargin: 1
        text: root.displayText
        textFormat: Text.PlainText
        color: Kirigami.Theme.textColor
        font.family: "Segoe UI"
        font.weight: Font.Bold
        font.pixelSize: root.numberPixelSize
        font.hintingPreference: Font.PreferFullHinting
        fontSizeMode: Text.Fit
        minimumPixelSize: Math.min(8, font.pixelSize)
        // Leave space for the keyline even when fitting multi-digit numbers.
        leftPadding: 1
        rightPadding: 1
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
        // A crisp one-pixel keyline matches the outlined Win7 tray artwork.
        // No drop shadow, glow, badge, or surrounding frame.
        style: Text.Outline
        styleColor: "#20252b"
        Accessible.ignored: true
    }
}
