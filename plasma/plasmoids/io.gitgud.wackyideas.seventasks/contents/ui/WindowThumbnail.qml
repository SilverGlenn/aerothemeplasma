pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import "code/Win7PreviewMetrics.js" as PreviewMetrics

import Qt5Compat.GraphicalEffects

import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager
import org.kde.kwindowsystem

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

MouseArea {
    id: thumbnailRoot

    property QtObject root

    property bool isGroupDelegate: false
    readonly property var captionAlignment: {
        if(Plasmoid.configuration.thmbnlCaptionAlignment == 0) return Text.AlignLeft
        if(Plasmoid.configuration.thmbnlCaptionAlignment == 1) return Text.AlignHCenter
        if(Plasmoid.configuration.thmbnlCaptionAlignment == 2) return Text.AlignRight
    }

    readonly property var display: isGroupDelegate ? model.display : root.display
    readonly property var icon: isGroupDelegate ? model.decoration : root.icon
    readonly property var active: isGroupDelegate ? model.IsActive : root.active
    readonly property var modelIndex: isGroupDelegate ? (tasksModel.makeModelIndex(root.taskIndex, index)) : root.modelIndex
    readonly property var windows: isGroupDelegate ? model.WinIdList : root.windows
    readonly property var captureWindowId: windows && windows.length ? windows[0] : undefined
    readonly property bool shortcutSelected: !!root.shortcutWindowId
        && String(captureWindowId) === root.shortcutWindowId
    readonly property var minimized: isGroupDelegate ? model.IsMinimized : root.minimized
    readonly property var demandsAttention: isGroupDelegate ? model.IsDemandingAttention : root.demandsAttention

    readonly property real padding: Kirigami.Units.smallSpacing * 2
    readonly property real margins: padding * 2
    readonly property real headerHeight: Math.max(20, txt.implicitHeight)
    readonly property real toolbarHeight: mprisControls.active ? mprisControls.implicitHeight : 0
    readonly property real maxPreviewWidth: Math.max(1, Math.min(PreviewMetrics.previewWidth, root.availableWidth - margins))
    readonly property real maxPreviewHeight: Math.max(1, Math.min(PreviewMetrics.previewHeight, root.availableHeight - margins - headerHeight - content.spacing - toolbarHeight))
    property real thumbnailHeight: maxPreviewHeight

    implicitWidth: PreviewMetrics.boundedSize(PreviewMetrics.previewWidth + margins, root.availableWidth)
    // Capture readiness and aspect ratio must not move the popup. Letterbox
    // each stream inside a stable slot, including while it reconnects.
    implicitHeight: Math.min(root.availableHeight, maxPreviewHeight + margins + headerHeight + content.spacing + toolbarHeight)

    onImplicitHeightChanged: if (isGroupDelegate && ListView.view) ListView.view.updateMaxSize()
    onWindowsChanged: {
        windowPeek.stop();
        root.endPeek(thumbnailRoot);
        thumbnailHeight = maxPreviewHeight;
    }
    onMinimizedChanged: if (minimized) root.endPeek(thumbnailRoot)

    width: implicitWidth
    height: isGroupDelegate && ListView.view ? ListView.view.maxThumbnailHeight : implicitHeight

    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: display
    Accessible.onPressAction: activateTask()

    function activateTask() {
        windowPeek.stop();
        root.cancelPeek();
        tasksModel.requestActivate(modelIndex);
        root.dismiss();
    }

    Keys.onReturnPressed: activateTask()
    Keys.onEnterPressed: activateTask()
    Keys.onSpacePressed: activateTask()
    Keys.onDeletePressed: closeTask()
    Keys.onEscapePressed: root.dismiss()
    onActiveFocusChanged: if (activeFocus && isGroupDelegate && ListView.view) ListView.view.positionViewAtIndex(index, ListView.Contain)

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

    function closeTask() {
        windowPeek.stop();
        root.cancelPeek();
        tasksModel.requestClose(modelIndex);
        if (!isGroupDelegate) root.dismiss();
    }
    DropArea {
        signal urlsDropped(var urls)

        anchors.fill: parent

        onPositionChanged: activationTimer.restart();
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

            onTriggered: if (root.containsDrag && root.popupVisible) tasksModel.requestActivate(modelIndex);
        }

        visible: isGroupDelegate
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
        anchors.bottomMargin: thumbnailRoot.padding + thumbnailRoot.toolbarHeight

        spacing: Kirigami.Units.smallSpacing/2

        RowLayout {
            id: header

            Layout.fillWidth: true
            Layout.minimumHeight: thumbnailRoot.headerHeight
            Layout.maximumHeight: thumbnailRoot.headerHeight

            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.preferredHeight: 16
                Layout.preferredWidth: 16

                source: icon
            }

            Text {
                id: txt
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

        Item {
            id: thumbnail

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: thumbnailRoot.maxPreviewHeight

            Loader {
                id: thumbnailLoader

                anchors.centerIn: parent

                width: thumbnailRoot.maxPreviewWidth
                height: thumbnailRoot.maxPreviewHeight

                active: true
                asynchronous: true
                sourceComponent: minimized ? appIcon : (KWindowSystem.isPlatformWayland ? (root.popupVisible ? waylandThumbnail : undefined) : x11Thumbnail)

                onLoaded: {
                    if(sourceComponent !== x11Thumbnail) thumbnailRoot.thumbnailHeight = thumbnailLoader.height;
                    if(isGroupDelegate && ListView.view !== null) ListView.view.updateMaxSize()
                }

                Component {
                    id: x11Thumbnail

                    PlasmaCore.WindowThumbnail {
                        winId: thumbnailRoot.captureWindowId

                        onPaintedSizeChanged: thumbnailRoot.thumbnailHeight = paintedHeight > 0 ? Math.min(paintedHeight, thumbnailRoot.maxPreviewHeight) : thumbnailRoot.maxPreviewHeight;

                        Rectangle {
                            anchors.centerIn: parent

                            width: parent.paintedWidth+2
                            height: parent.paintedHeight+2
                            color: "transparent"
                            border.width: 1
                            border.color: "black"

                            opacity: 0.5
                        }
                    }
                }

                Component {
                    id: waylandThumbnail

                    PipeWire.PipeWireSourceItem {
                        id: wl_pw_src
                        nodeId: waylandItem.nodeId

                        TaskManager.ScreencastingRequest {
                            id: waylandItem
                            uuid: thumbnailRoot.captureWindowId
                        }

                        onStreamSizeChanged: outlineRect.updateSize()
                        onReadyChanged: outlineRect.updateSize()
                        Connections {
                            target: thumbnailRoot
                            function onMaxPreviewWidthChanged() { outlineRect.updateSize(); }
                            function onMaxPreviewHeightChanged() { outlineRect.updateSize(); }
                        }
                        Rectangle {
                            id: outlineRect
                            anchors.centerIn: parent

                            function updateSize() {
                                if (!wl_pw_src.ready) {
                                    width = 0;
                                    height = 0;
                                } else {
                                    var size = PreviewMetrics.fitPreview(wl_pw_src.streamSize.width, wl_pw_src.streamSize.height, thumbnailRoot.maxPreviewWidth, thumbnailRoot.maxPreviewHeight);
                                    width = size.width + 2;
                                    height = size.height + 2;
                                }
                            }
                            onHeightChanged: {
                                thumbnailRoot.thumbnailHeight = ((outlineRect.height-2) > 0) ? outlineRect.height-2 : thumbnailRoot.maxPreviewHeight
                            }

                            color: "black"
                            border.width: 1
                            border.color: "black"

                            opacity: 0.5
                            z: -1
                        }
                    }
                }

                // Used when there's no thumbnail available.
                Component {
                    id: appIcon

                    Item {
                        Rectangle {
                            anchors.fill: parent

                            gradient: Gradient {
                                GradientStop { position: 0; color: "#ffffff" }
                                GradientStop { position: 1; color: "#cccccc" }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1

                                color: "transparent"

                                border.width: 1
                                border.color: "black"
                                radius: 1
                            }
                        }

                        Kirigami.Icon {
                            anchors.centerIn: parent

                            width: Kirigami.Units.iconSizes.small
                            height: Kirigami.Units.iconSizes.small

                            source: icon
                        }
                    }
                }

                Connections { // Recreate capture only when the actual window changes.
                    target: thumbnailRoot
                    function onCaptureWindowIdChanged() {
                        thumbnailLoader.active = false;
                        thumbnailLoader.active = true;
                    }
                }
            }

            Loader {
                id: shadowLoader

                anchors.fill: thumbnailLoader

                active: true
                asynchronous: true

                sourceComponent: DropShadow {
                    id: realShadow

                    horizontalOffset: 1
                    // Fix for shadow not appearing properly at the bottom
                    // when appIcon is the sourceComponent.
                    verticalOffset: thumbnailLoader.sourceComponent == appIcon ? 2 : 1

                    radius: 1
                    samples: 1
                    color: "#70000000"
                    source: thumbnailLoader.item
                }
            }
        }
    }

    Loader {
        id: mprisControls

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - thumbnailRoot.margins
        height: implicitHeight

        readonly property QtObject root: thumbnailRoot.root

        active: root.playerData !== null && root.playerData !== undefined
        asynchronous: false
        source: "PlayerController.qml"

        HoverHandler {
            onHoveredChanged: if (hovered) {
                windowPeek.stop();
                thumbnailRoot.root.endPeek(thumbnailRoot);
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
        if (isGroupDelegate && ListView.view) ListView.view.updateMaxSize();
    }
}
