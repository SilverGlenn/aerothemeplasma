import QtQuick
import QtQuick.Layouts

import "code/Win7PreviewMetrics.js" as PreviewMetrics

import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

import org.kde.plasma.plasmoid

MouseArea {
    id: thumbnailRoot

    property QtObject root

    property var captionAlignment: {
        if(Plasmoid.configuration.thmbnlCaptionAlignment == 0) return Text.AlignLeft
        if(Plasmoid.configuration.thmbnlCaptionAlignment == 1) return Text.AlignHCenter
        if(Plasmoid.configuration.thmbnlCaptionAlignment == 2) return Text.AlignRight
    }

    property var display: model.display
    property var icon: model.decoration
    property var active: model.IsActive
    property var modelIndex: tasksModel.makeModelIndex(root.taskIndex, index)
    property var windows: model.WinIdList
    readonly property bool shortcutSelected: !!root.shortcutWindowId
        && windows && windows.length > 0 && String(windows[0]) === root.shortcutWindowId
    property var minimized: model.IsMinimized
    readonly property bool demandsAttention: model.IsDemandingAttention

    readonly property real padding: Kirigami.Units.smallSpacing * 2
    implicitWidth: PreviewMetrics.boundedSize(captionIcon.width + captionTitle.implicitWidth + 20 + header.spacing * 2 + padding * 2, root.availableWidth)
    implicitHeight: Math.max(20, captionTitle.implicitHeight) + padding * 2
    onImplicitWidthChanged: if (ListView.view) ListView.view.updateMaxSize()
    width: ListView.view ? ListView.view.width : implicitWidth
    height: implicitHeight

    function closeTask() {
        windowPeek.stop();
        root.cancelPeek();
        tasksModel.requestClose(modelIndex);
    }
    function activateTask() {
        windowPeek.stop();
        root.cancelPeek();
        tasksModel.requestActivate(modelIndex);
        root.dismiss();
    }

    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: display
    Accessible.onPressAction: activateTask()
    Keys.onReturnPressed: activateTask()
    Keys.onEnterPressed: activateTask()
    Keys.onSpacePressed: activateTask()
    Keys.onDeletePressed: closeTask()
    Keys.onEscapePressed: root.dismiss()
    onActiveFocusChanged: if (activeFocus && ListView.view) ListView.view.positionViewAtIndex(index, ListView.Contain)
    onWindowsChanged: {
        windowPeek.stop();
        root.endPeek(thumbnailRoot);
    }
    onMinimizedChanged: if (minimized) root.endPeek(thumbnailRoot)

    Item {
        id: frames

        anchors.fill: parent

        KSvg.FrameSvgItem {
            id: attentionTexture

            anchors.fill: parent

            imagePath: Qt.resolvedUrl("svgs/menuitem.svg")
            prefix: "attention"

            visible: demandsAttention
            opacity: root.parentTask ? root.parentTask.attentionAnimOpacity : 0
        }

        KSvg.FrameSvgItem {
            id: activeTexture

            anchors.fill: parent

            imagePath: Qt.resolvedUrl("svgs/menuitem.svg")
            prefix: "active"

            visible: root.shortcutWindowId ? shortcutSelected : active
        }

        KSvg.FrameSvgItem {
            id: hoverTexture

            anchors.fill: parent

            imagePath: Qt.resolvedUrl("svgs/menuitem.svg")
            prefix: {
                if(contentMa.containsPress) return "pressed";
                else return "hover";
            }

            opacity: contentMa.containsMouse || closeMa.containsMouse || thumbnailRoot.activeFocus || closeMa.activeFocus

            Behavior on opacity {
                NumberAnimation { duration: 250 }
            }
        }
    }

    DropArea {
        signal urlsDropped(var urls)

        anchors.fill: parent

        onPositionChanged: {
            activationTimer.restart();
        }

        onEntered: {
            root.containsDrag = true;
            activationTimer.restart();
        }

        onExited: {
            activationTimer.stop();
            root.containsDrag = false;
        }

        onDropped: event => {
            activationTimer.stop();
            root.containsDrag = false;
            if (event.hasUrls) {
                urlsDropped(event.urls);
                return;
            }
        }

        onUrlsDropped: (urls) => {
            tasksModel.requestOpenUrls(modelIndex, urls);
            root.containsDrag = false;
        }

        Timer {
            id: activationTimer

            interval: PreviewMetrics.dragActivationDelay
            repeat: false

            onTriggered: {
                if (root.containsDrag && root.popupVisible) tasksModel.requestActivate(modelIndex);
            }
        }
    }

    MouseArea {
        id: contentMa

        anchors.fill: parent

        hoverEnabled: true
        propagateComposedEvents: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onContainsMouseChanged: {
            if (containsMouse) windowPeek.restart();
            else {
                windowPeek.stop();
                root.endPeek(thumbnailRoot);
            }
        }
        onClicked: (mouse) => {
            if(mouse.button == Qt.LeftButton) {
                activateTask();
            }
            if(mouse.button == Qt.MiddleButton) {
                thumbnailRoot.closeTask();
            }
        }
    }

    Timer {
        id: windowPeek

        interval: root.isPeeking ? 1 : PreviewMetrics.peekDelay
        repeat: false
        onTriggered: {
            if (!minimized && contentMa.containsMouse && root.popupVisible) root.beginPeek(thumbnailRoot, windows);
        }
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: thumbnailRoot.padding

        spacing: Kirigami.Units.smallSpacing/2

        RowLayout {
            id: header

            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
            Layout.fillHeight: true

            Kirigami.Icon {
                id: captionIcon

                Layout.preferredHeight: 16
                Layout.preferredWidth: 16

                source: icon
            }

            Text {
                id: captionTitle

                Layout.fillWidth: true
                Layout.fillHeight: true

                verticalAlignment: Text.AlignVCenter
                text: display
                color: "white"
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                style: Text.Outline
                styleColor: "#02ffffff"
                horizontalAlignment: captionAlignment
                rightPadding: 0
            }

            MouseArea {
                id: closeMa
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                propagateComposedEvents: false
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: i18n("Close %1", thumbnailRoot.display)
                Accessible.onPressAction: thumbnailRoot.closeTask()
                onClicked: thumbnailRoot.closeTask()
                Keys.onReturnPressed: thumbnailRoot.closeTask()
                Keys.onEnterPressed: thumbnailRoot.closeTask()
                Keys.onSpacePressed: thumbnailRoot.closeTask()
                Keys.onEscapePressed: root.dismiss()
                onActiveFocusChanged: if (activeFocus) {
                    windowPeek.stop();
                    root.endPeek(thumbnailRoot);
                    if (ListView.view) ListView.view.positionViewAtIndex(index, ListView.Contain);
                }
                onContainsMouseChanged: if (containsMouse) {
                    windowPeek.stop();
                    root.endPeek(thumbnailRoot);
                }

                KSvg.FrameSvgItem {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    imagePath: Qt.resolvedUrl("svgs/button-close.svg")
                    prefix: closeMa.containsMouse || closeMa.activeFocus ? (closeMa.containsPress ? "pressed" : "hover") : "normal"
                    opacity: contentMa.containsMouse || closeMa.containsMouse || thumbnailRoot.activeFocus || closeMa.activeFocus ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }
            }
        }
    }

    Connections {
        target: thumbnailRoot.root
        function onParentTaskChanged() {
            windowPeek.stop();
            activationTimer.stop();
        }
        function onPopupVisibleChanged() {
            if (!thumbnailRoot.root.popupVisible) {
                windowPeek.stop();
                activationTimer.stop();
            }
        }
    }
    Component.onDestruction: {
        root.endPeek(thumbnailRoot);
        if (ListView.view) ListView.view.updateMaxSize();
    }
}
