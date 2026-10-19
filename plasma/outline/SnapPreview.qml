/*
    SPDX-FileCopyrightText: 2024 Souris
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/
import QtQuick
import QtQuick.Shapes

Item {
    id: preview

    property bool active: false
    property bool animationEnabled: true
    property int animationDuration: 200
    property rect targetGeometry: Qt.rect(0, 0, 0, 0)
    property rect visualParentGeometry: Qt.rect(0, 0, 0, 0)
    property rect reflectionGeometry: Qt.rect(0, 0, 1920, 1080)
    property url reflectionSource

    // Global coordinates stay independent of the backing window's origin.
    property rect frameGeometry: Qt.rect(0, 0, 0, 0)
    property rect viewport: Qt.rect(0, 0, 1, 1)
    readonly property bool animating: transition.running
    readonly property int framePadding: 8
    readonly property int shadowPadding: 24
    property bool ready: false

    function sameRect(a, b) {
        return a !== undefined && a !== null && a.x === b.x && a.y === b.y
            && a.width === b.width && a.height === b.height;
    }

    function paddedFrame(rect) {
        return Qt.rect(rect.x + framePadding, rect.y + framePadding,
                       Math.max(1, rect.width - framePadding * 2),
                       Math.max(1, rect.height - framePadding * 2));
    }

    function setViewport(from, to) {
        const left = Math.floor(Math.min(from.x, to.x) - shadowPadding);
        const top = Math.floor(Math.min(from.y, to.y) - shadowPadding);
        const right = Math.ceil(Math.max(from.x + from.width, to.x + to.width) + shadowPadding);
        const bottom = Math.ceil(Math.max(from.y + from.height, to.y + to.height) + shadowPadding);
        viewport = Qt.rect(left, top, right - left, bottom - top);
    }

    function moveToTarget(initial) {
        const destination = paddedFrame(targetGeometry);
        // KWin can emit show/activeChanged repeatedly for the same target.
        if (!initial && sameRect(transition.to, destination)) {
            return;
        }
        transition.stop();
        let start = frameGeometry;
        if (initial) {
            const parent = visualParentGeometry;
            start = parent.width > 0 && parent.height > 0
                ? paddedFrame(Qt.rect(parent.x + parent.width / 2 - 20, parent.y, 40, 40))
                : destination;
        }
        setViewport(start, destination);
        frameGeometry = start;
        transition.from = start;
        transition.to = destination;
        if (animationEnabled && animationDuration > 0 && !sameRect(start, destination)) {
            transition.start();
        } else {
            frameGeometry = destination;
        }
    }

    onActiveChanged: {
        if (!ready) return;
        if (active) {
            moveToTarget(true);
        } else {
            transition.stop();
        }
    }
    onTargetGeometryChanged: if (ready && active) moveToTarget(false)
    Component.onCompleted: {
        ready = true;
        if (active) moveToTarget(true);
    }

    // A single rect animation preserves fractional coordinates and retargets
    // from the currently displayed frame without four independent Behaviors.
    PropertyAnimation {
        id: transition
        target: preview
        property: "frameGeometry"
        duration: preview.animationDuration
        easing.type: Easing.OutCubic
    }

    Image {
        id: reflection
        objectName: "snapReflection"
        source: preview.reflectionSource
        visible: false
        // Keep the original image texture; never decode a desktop-sized copy.
        smooth: true
    }

    Item {
        id: frame
        objectName: "snapFrame"
        x: preview.frameGeometry.x - preview.viewport.x
        y: preview.frameGeometry.y - preview.viewport.y
        width: preview.frameGeometry.width
        height: preview.frameGeometry.height

        // Sample the static reflection directly into a rounded path. Unlike
        // OpacityMask, this needs no full-window source or mask render targets.
        Shape {
            id: glass
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: "transparent"
                fillItem: reflection
                // Shape fills use texture pixels, not the Image item's size.
                // Scale the native texture to the desktop before translating.
                fillTransform: Qt.matrix4x4(
                    preview.reflectionGeometry.width / Math.max(1, reflection.sourceSize.width), 0, 0,
                    preview.reflectionGeometry.x - preview.frameGeometry.x,
                    0, preview.reflectionGeometry.height / Math.max(1, reflection.sourceSize.height), 0,
                    preview.reflectionGeometry.y - preview.frameGeometry.y,
                    0, 0, 1, 0,
                    0, 0, 0, 1)
                PathRectangle {
                    width: frame.width
                    height: frame.height
                    radius: Math.min(7, frame.width / 2, frame.height / 2)
                }
            }
        }

        // The original SVG contains bitmap slices. Reuse them directly so a
        // resize only updates scene-graph vertices, never SVG rasterizations.
        BorderImage {
            x: -14
            y: -14
            width: parent.width + 34
            height: parent.height + 34
            source: "res/shadow.png"
            border { left: 30; right: 29; top: 31; bottom: 37 }
        }
        BorderImage {
            anchors.fill: parent
            source: "res/frame.png"
            border { left: 9; right: 9; top: 9; bottom: 9 }
        }
    }
}
