/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import "DesktopLogic.js" as DesktopLogic

PlasmoidItem {
    id: root

    readonly property int desktopNumber: DesktopLogic.numberForDesktop(
        desktopInfo.desktopIds, desktopInfo.currentDesktop)

    Layout.minimumWidth: Kirigami.Units.iconSizes.small
    Layout.minimumHeight: Kirigami.Units.iconSizes.small
    Layout.preferredWidth: Kirigami.Units.iconSizes.small
    Layout.preferredHeight: Kirigami.Units.iconSizes.small

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.status: desktopNumber > 0
        ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
    preferredRepresentation: fullRepresentation
    // The tray forwards left-click and keyboard activation here. Avoid a second
    // MouseArea, which would bypass that forwarding or toggle Overview twice.
    Plasmoid.onActivated: overviewAction.trigger()
    toolTipMainText: desktopNumber > 0
        ? i18n("Desktop %1", desktopNumber) : i18n("Current desktop")
    toolTipSubText: i18n("Open Overview")

    OverviewAction {
        id: overviewAction
    }

    TaskManager.VirtualDesktopInfo {
        id: desktopInfo
    }

    // Always use the number, including inside a 16px tray slot; no icon fallback.
    fullRepresentation: DesktopNumber {
        number: root.desktopNumber
    }
}
