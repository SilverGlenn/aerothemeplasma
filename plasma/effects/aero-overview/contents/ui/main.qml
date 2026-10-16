/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQml
import "native" as AeroNative

AeroNative.OverviewOverride {
    Component.onCompleted: install(Qt.resolvedUrl("Main.qml"))
}
