/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.1
import QtQml.Models
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasmoid 2.0
import org.kde.kitemmodels 1.0 as KItemModels
import org.kde.kirigami 2.20 as Kirigami
import "items"
import org.kde.plasma.extras 2.0 as PlasmaExtras

ScrollView {
    id: hiddenTasksView

    property alias hiddenItemsCount: hiddenTasks.count
    property alias cellWidth: hiddenTasks.cellWidth
    property alias cellHeight: hiddenTasks.cellHeight
    property alias layout: hiddenTasks

    // Reserve a square icon area, growing both dimensions at 10, 17, 26, ...
    readonly property int gridSize: Math.max(3, Math.ceil(Math.sqrt(hiddenItemsCount)))

    width: gridSize * hiddenTasks.cellWidth + leftPadding + rightPadding

    padding: Kirigami.Units.mediumSpacing
    implicitHeight: gridSize * hiddenTasks.cellHeight + topPadding + bottomPadding
    leftPadding: padding
    rightPadding: padding
    bottomPadding: padding
    hoverEnabled: true
    onHoveredChanged: if (!hovered) {

        hiddenTasks.currentIndex = -1;
    }
    background: null

    GridView {
        id: hiddenTasks

        cellWidth: Kirigami.Units.iconSizes.medium
        cellHeight: Kirigami.Units.iconSizes.medium

        currentIndex: -1
        //highlight: PlasmaExtras.Highlight {}
        highlightMoveDuration: 0

        pixelAligned: true

        readonly property int itemCount: model.count


        model: OrderedTrayModel {
            ordering: root.orderingManager
            model: KItemModels.KSortFilterProxyModel {
                sourceModel: Plasmoid.systemTrayModel
                filterRoleName: "effectiveStatus"
                filterRowCallback: (sourceRow, sourceParent) => {
                    let value = sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), filterRole);
                    return value === PlasmaCore.Types.PassiveStatus
                }
            }
            delegate: ItemLoader {
                id: itemloader
                property int visualIndex: DelegateModel.itemsIndex
                visible: !DelegateModel.isUnresolved
                GridView.onRemove: {
                    removeAnim.start();
                }
                //GridView.delayRemove: true
                width: hiddenTasks.cellWidth
                height: hiddenTasks.cellHeight
                minLabelHeight: 0//hiddenTasks.minLabelHeight
                SequentialAnimation {
                    id: removeAnim
                    PropertyAction { target: itemloader; property: "GridView.delayRemove"; value: true }
                    NumberAnimation { target: itemloader; property: "opacity"; to: 0; duration: 25; easing.type: Easing.InOutQuad }
                    PropertyAction { target: itemloader; property: "GridView.delayRemove"; value: false }
                }
            }
        }

        keyNavigationEnabled: true
        activeFocusOnTab: true

        KeyNavigation.up: hiddenTasksView.KeyNavigation.up

        onActiveFocusChanged: {
            if (activeFocus && currentIndex === -1) {
                currentIndex = 0
            } else if (!activeFocus && currentIndex >= 0) {
                currentIndex = -1
            }
        }
    }
}
