/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import "code/ShortcutSelection.js" as ShortcutSelection

Item {
    id: controller
    visible: false

    property QtObject previewTask: null
    property int requestSerial: 0
    property bool metaPressed: metaKey.pressed
    property QtObject taskModel: null
    property string selectedWindowId: ""
    property string deferredWindowId: ""

    // This follows the global modifier state even when an application has focus.
    KeyboardIndicator.KeyState {
        id: metaKey
        objectName: "shortcutMetaKey"
        key: Qt.Key_Meta
    }

    onMetaPressedChanged: if (!metaPressed) finish()

    function cycleGroup(task) {
        if (!metaPressed || !taskModel || !task.model.IsGroupParent) {
            selectedWindowId = "";
            deferredWindowId = "";
            return false;
        }
        const windows = ShortcutSelection.windowsForTask(task, taskModel);
        if (windows.length < 2) {
            selectedWindowId = "";
            deferredWindowId = "";
            return false;
        }
        const target = ShortcutSelection.nextWindow(windows,
            previewTask === task ? selectedWindowId : "");
        showForTask(task);
        selectedWindowId = target.id;
        deferredWindowId = target.minimized ? target.id : "";
        // Minimized group members are selected in the popup only. Other
        // windows retain immediate cycling and activation.
        if (!target.minimized) taskModel.requestActivate(target.index);
        return true;
    }

    function finish() {
        const task = previewTask;
        const windowId = deferredWindowId;
        dismiss();
        if (!task || !windowId || !taskModel) return;
        const target = ShortcutSelection.windowsForTask(task, taskModel)
            .find(window => window.id === windowId);
        if (target) taskModel.requestActivate(target.index);
    }

    function dismiss() {
        ++requestSerial;
        const task = previewTask;
        previewTask = null;
        selectedWindowId = "";
        deferredWindowId = "";
        // Hover may already have transferred the shared popup to another task.
        if (task && task.taskThumbnail && task.taskThumbnail.parentTask === task) {
            task.hideImmediately();
        }
    }

    function showForTask(task) {
        if (!metaPressed) {
            dismiss();
            return;
        }
        if (previewTask && previewTask !== task) {
            dismiss();
        }
        previewTask = task;
        const serial = ++requestSerial;
        // Activation may dismiss the shared tooltip. Show it afterwards,
        // provided the key is still held and this request is still current.
        Qt.callLater(() => {
            if (serial !== requestSerial || !metaPressed || previewTask !== task
                    || !task || !task.showPreviews) {
                return;
            }
            task.updateToolTipBindings();
            task.taskThumbnail.shortcutWindowId = Qt.binding(() =>
                controller.previewTask === task ? controller.selectedWindowId : "");
            if (!task.toolTipShown) {
                task.showToolTip();
            }
        });
    }
}
