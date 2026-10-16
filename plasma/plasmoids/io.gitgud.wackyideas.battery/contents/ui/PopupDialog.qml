/*
    SPDX-FileCopyrightText: 2011 Viranch Mehta <viranch.mehta@gmail.com>
    SPDX-FileCopyrightText: 2013-2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QtControls
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmaExtras.Representation {
    id: dialog
    objectName: "powerFlyout"
    implicitWidth: 15 * Kirigami.Units.iconSizes.small

    property alias model: batteryRepeater.model
    property bool pluggedIn
    property int chargeStopThreshold
    property int remainingTime
    property bool profilesInstalled
    property string activeProfile
    property string activeProfileError
    property var profiles: []
    property bool isTlpInstalled
    property bool containsBrokenBatteries
    property string inhibitionReason
    property string degradationReason
    required property var profileHolds
    property bool brightnessAvailable: false
    property bool powerOptionsAvailable: true

    signal activateProfileRequested(string profile)
    signal brightnessRequested()
    signal powerOptionsRequested()

    KeyNavigation.down: powerProfileSelector.firstProfileRadio || brightnessLink
    KeyNavigation.up: powerOptionsLink
    KeyNavigation.tab: KeyNavigation.down
    KeyNavigation.backtab: powerOptionsLink

    contentItem: QtControls.ScrollView {
        id: scrollView
        implicitWidth: dialog.implicitWidth
        implicitHeight: contentColumn.implicitHeight
        contentHeight: contentColumn.implicitHeight
        contentWidth: availableWidth
        clip: true

        function positionViewAtItem(item: Item): void {
            if (contentHeight <= height) {
                return;
            }
            const rect = contentColumn.mapFromItem(item, 0, 0, item.width, item.height);
            if (rect.y < contentItem.contentY) {
                contentItem.contentY = rect.y;
            } else if (rect.y + rect.height > contentItem.contentY + height) {
                contentItem.contentY = rect.y + rect.height - height;
            }
        }

        ColumnLayout {
            id: contentColumn
            spacing: 0
            width: scrollView.availableWidth

            ListView {
                id: batteryRepeater
                interactive: false
                focus: false
                spacing: 0
                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight
                acceptedButtons: Qt.NoButton
                boundsBehavior: Flickable.StopAtBounds

                delegate: BatteryItem {
                    width: batteryRepeater.width
                    activeFocusOnTab: false
                    batteryPercent: Percent
                    batteryCapacity: Capacity
                    batteryEnergy: Energy
                    batteryPluggedIn: PluggedIn
                    batteryIsPowerSupply: IsPowerSupply
                    batteryChargeState: ChargeState
                    batteryPrettyName: PrettyName
                    batteryType: Type
                    remainingTime: dialog.remainingTime
                    pluggedIn: dialog.pluggedIn
                    chargeStopThreshold: dialog.chargeStopThreshold
                }
            }

            Separator {
                Layout.preferredHeight: 1
                Layout.fillWidth: true
                visible: batteryRepeater.count > 0
            }

            PowerProfileItem {
                id: powerProfileSelector
                objectName: "powerProfileSelector"
                Layout.fillWidth: true
                profilesInstalled: dialog.profilesInstalled
                profilesAvailable: dialog.profiles.length > 0
                profiles: dialog.profiles
                activeProfile: dialog.activeProfile
                activeProfileError: dialog.activeProfileError
                inhibitionReason: dialog.inhibitionReason
                degradationReason: dialog.degradationReason
                profileHolds: dialog.profileHolds
                previousFocusItem: powerOptionsLink
                nextFocusItem: brightnessLink
                isTlpInstalled: dialog.isTlpInstalled
                onActivateProfileRequested: profile => dialog.activateProfileRequested(profile)
                onActiveFocusChanged: if (activeFocus) scrollView.positionViewAtItem(this)
            }

            InhibitionHint {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                visible: dialog.containsBrokenBatteries
                iconSource: "info"
                text: i18n("There is a problem with your battery, so your computer might shut down suddenly.")
            }
        }
    }

    // Own both links so they share the same pale-blue footer, like Windows 7.
    // This is not a PlasmoidHeading: the tray must not detach or merge it.
    footer: QtControls.Control {
        objectName: "powerFooter"
        padding: 8
        implicitHeight: implicitContentHeight + topPadding + bottomPadding
        background: Rectangle {
            color: "#f1f5fb"
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: "#ccd9ea"
            }
        }
        contentItem: ColumnLayout {
            spacing: 0
            PowerFooterLink {
                id: brightnessLink
                objectName: "adjustBrightnessLink"
                Layout.fillWidth: true
                text: i18n("Adjust screen brightness")
                enabled: dialog.brightnessAvailable
                KeyNavigation.up: powerProfileSelector.lastProfileRadio || powerOptionsLink
                KeyNavigation.backtab: KeyNavigation.up
                KeyNavigation.down: powerOptionsLink
                KeyNavigation.tab: powerOptionsLink
                onClicked: dialog.brightnessRequested()
            }
            PowerFooterLink {
                id: powerOptionsLink
                objectName: "morePowerOptionsLink"
                Layout.fillWidth: true
                text: i18n("More power options")
                enabled: dialog.powerOptionsAvailable
                KeyNavigation.up: brightnessLink
                KeyNavigation.backtab: brightnessLink
                KeyNavigation.down: powerProfileSelector.firstProfileRadio || brightnessLink
                KeyNavigation.tab: KeyNavigation.down
                onClicked: dialog.powerOptionsRequested()
            }
        }
    }
}
