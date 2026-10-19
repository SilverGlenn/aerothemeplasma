/*
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2017 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Souris
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/
import QtCore
import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami

Window {
    id: window
    flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
    color: "transparent"
    title: "aeroshell-windowframe-special"
    visible: outline.active

    // Allocate once per transition, bounded by its start and destination.
    // Negative monitor origins work without rendering the entire desktop.
    x: preview.viewport.x
    y: preview.viewport.y
    width: preview.viewport.width
    height: preview.viewport.height

    readonly property rect desktopGeometry: {
        const screens = Qt.application.screens;
        if (screens.length === 0) return Qt.rect(0, 0, 1, 1);
        let left = screens[0].virtualX;
        let top = screens[0].virtualY;
        let right = left + screens[0].width;
        let bottom = top + screens[0].height;
        for (let i = 1; i < screens.length; ++i) {
            const screen = screens[i];
            left = Math.min(left, screen.virtualX);
            top = Math.min(top, screen.virtualY);
            right = Math.max(right, screen.virtualX + screen.width);
            bottom = Math.max(bottom, screen.virtualY + screen.height);
        }
        return Qt.rect(left, top, right - left, bottom - top);
    }

    SnapPreview {
        id: preview
        anchors.fill: parent
        active: outline.active
        targetGeometry: outline.geometry
        visualParentGeometry: outline.visualParentGeometry
        reflectionGeometry: window.desktopGeometry
        reflectionSource: StandardPaths.locate(StandardPaths.GenericDataLocation, "smod/kwin/reflections.png")
        animationDuration: Kirigami.Units.longDuration
    }
}
