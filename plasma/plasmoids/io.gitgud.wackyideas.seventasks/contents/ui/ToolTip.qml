import QtQuick

import org.kde.kirigami as Kirigami

import org.kde.plasma.private.mpris as Mpris

Item {
    id: tooltip

    readonly property Mpris.PlayerContainer playerData: mpris2Source.playerForLauncherUrl(launcherUrl, pidParent)

    property QtObject parentTask
    onParentTaskChanged: {
        cancelPeek();
        keyboardFocusRequested = false;
        loaderItem.active = parentTask !== null;
    }
    property string display: "undefined"
    property var icon: "undefined"
    property bool active: false
    property bool minimized: false
    property bool startup: false
    property var windows
    property bool taskHovered: false
    property var modelIndex
    property var taskIndex
    property bool isGroupParent: false
    property bool forceList: false
    readonly property bool popupVisible: parentTask ? parentTask.previewVisible : false
    property bool dragDrop: false
    property bool keyboardFocusRequested: false

    function focusFirstRow() {
        keyboardFocusRequested = true;
        tryFocusFirstRow();
    }
    function tryFocusFirstRow() {
        if (!keyboardFocusRequested || !popupVisible || !loaderItem.item) return;
        if (isGroupParent) {
            if (!loaderItem.item.focusFirstRow()) return;
        } else {
            loaderItem.item.forceActiveFocus(Qt.TabFocusReason);
        }
        keyboardFocusRequested = false;
    }

    property bool isPeeking: false
    property Item peekOwner: null

    // Leave room for the popup's theme frame, in logical theme units.
    readonly property real availableWidth: Math.max(1, tasks.availableScreenRect.width - Kirigami.Units.smallSpacing * 4)
    readonly property real availableHeight: Math.max(1, tasks.availableScreenRect.height - Kirigami.Units.smallSpacing * 4)

    function beginPeek(owner, windowIds) {
        if (!popupVisible || !windowIds || windowIds.length === 0) return;
        peekOwner = owner;
        tasks.windowsHovered(windowIds, true);
        isPeeking = true;
    }

    function endPeek(owner) {
        if (peekOwner === owner) cancelPeek();
    }

    function cancelPeek() {
        if (isPeeking) tasks.cancelHighlightWindows();
        peekOwner = null;
        isPeeking = false;
    }

    function dismiss() {
        cancelPeek();
        containsDrag = false;
        if (parentTask) parentTask.hideImmediately();
    }

    onWindowsChanged: cancelPeek()
    onTaskIndexChanged: cancelPeek()
    onIsGroupParentChanged: cancelPeek()
    onVisibleChanged: if (!visible) cancelPeek()
    Component.onDestruction: cancelPeek()

    onPopupVisibleChanged: if (!popupVisible) {
        cancelPeek();
        containsDrag = false;
        keyboardFocusRequested = false;
    }

    Keys.onEscapePressed: event => {
        dismiss();
        event.accepted = true;
    }

    // needed for mpris
    property int pidParent
    property url launcherUrl

    property bool containsDrag: false

    property bool demandsAttention

    implicitWidth: loaderItem.implicitWidth
    implicitHeight: loaderItem.implicitHeight

    Loader {
        id: loaderItem

        width: tooltip.width
        height: tooltip.height
        active: false
        // Build the small layout before the dialog takes its initial size.
        // Live window capture remains asynchronous inside WindowThumbnail.
        asynchronous: false
        onLoaded: tooltip.tryFocusFirstRow()
        sourceComponent: isGroupParent ? groupThumbnails : windowThumbnail

        Binding {
            target: tooltip
            property: "implicitWidth"
            value: loaderItem.implicitWidth
            restoreMode: Binding.RestoreBinding
        }
        Binding {
            target: tooltip
            property: "implicitHeight"
            value: loaderItem.implicitHeight
            restoreMode: Binding.RestoreBinding
        }

        Component {
            id: groupThumbnails

            GroupThumbnails { root: tooltip; parent: loaderItem }
        }
        Component {
            id: windowThumbnail

            WindowThumbnail { root: tooltip; parent: loaderItem }
        }
    }
}
