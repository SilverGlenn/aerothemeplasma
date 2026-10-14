import QtQuick
import QtQml.Models
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami

import "code/Win7PreviewMetrics.js" as PreviewMetrics

Item {
    id: groupThumbnails

    property QtObject root

    function focusFirstRow() {
        thumbnailList.currentIndex = 0;
        thumbnailList.positionViewAtBeginning();
        if (!thumbnailList.currentItem) return false;
        thumbnailList.currentItem.forceActiveFocus(Qt.TabFocusReason);
        return true;
    }

    readonly property real padding: Kirigami.Units.smallSpacing * 2
    readonly property real gutter: Kirigami.Units.smallSpacing / 2
    readonly property real previewWidth: PreviewMetrics.boundedSize(PreviewMetrics.previewWidth + padding * 2, root.availableWidth)
    readonly property bool isList: root.forceList || PreviewMetrics.needsList(thumbnailModel.count, previewWidth, gutter, root.availableWidth)
    readonly property bool containsDrag: root.containsDrag
    readonly property real thumbnailHeight: thumbnailList.maxThumbnailHeight

    implicitWidth: PreviewMetrics.boundedSize(isList ? thumbnailList.maxThumbnailWidth : PreviewMetrics.horizontalExtent(thumbnailModel.count, previewWidth, gutter), root.availableWidth)
    implicitHeight: PreviewMetrics.boundedSize(isList ? thumbnailList.contentHeight : thumbnailList.maxThumbnailHeight, root.availableHeight)

    DelegateModel {
        id: thumbnailModel
        model: tasksModel
        rootIndex: tasksModel.makeModelIndex(root.taskIndex)
        delegate: WindowThumbnail {
            isGroupDelegate: true
            root: groupThumbnails.root
        }
    }
    DelegateModel {
        id: listModel
        model: tasksModel
        rootIndex: tasksModel.makeModelIndex(root.taskIndex)
        delegate: WindowListDelegate {
            root: groupThumbnails.root
        }
    }

    QQC2.ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
        QQC2.ScrollBar.vertical.policy: groupThumbnails.isList ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
        rightPadding: QQC2.ScrollBar.vertical.visible ? QQC2.ScrollBar.vertical.width : 0

        ListView {
            id: thumbnailList
            property real maxThumbnailWidth: groupThumbnails.previewWidth
            property real maxThumbnailHeight: PreviewMetrics.previewHeight + groupThumbnails.padding * 2 + 20 + groupThumbnails.gutter

            function updateMaxSize() {
                updateDelayTimer.restart();
            }

            function measureItems() {
                var maxWidth = groupThumbnails.previewWidth;
                var maxHeight = 0;
                for (var i = 0; i < count; ++i) {
                    var item = itemAtIndex(i);
                    if (item) {
                        maxWidth = Math.max(maxWidth, item.implicitWidth);
                        maxHeight = Math.max(maxHeight, item.implicitHeight);
                    }
                }
                groupThumbnails.root.tryFocusFirstRow();
                maxThumbnailWidth = Math.min(maxWidth, groupThumbnails.root.availableWidth);
                maxThumbnailHeight = Math.min(maxHeight || (PreviewMetrics.previewHeight + groupThumbnails.padding * 2 + 20 + groupThumbnails.gutter), groupThumbnails.root.availableHeight);
            }

            // Overflow rows remain reachable by wheel, scrollbar, touch and keyboard.
            interactive: groupThumbnails.isList
            spacing: groupThumbnails.gutter
            orientation: groupThumbnails.isList ? ListView.Vertical : ListView.Horizontal
            model: groupThumbnails.isList ? listModel : thumbnailModel
            clip: true
            keyNavigationEnabled: true
            boundsBehavior: Flickable.StopAtBounds

            onCountChanged: updateMaxSize()
            onModelChanged: updateMaxSize()
            Component.onCompleted: updateMaxSize()

            Timer {
                id: updateDelayTimer
                interval: 15
                onTriggered: thumbnailList.measureItems()
            }
        }
    }
}
