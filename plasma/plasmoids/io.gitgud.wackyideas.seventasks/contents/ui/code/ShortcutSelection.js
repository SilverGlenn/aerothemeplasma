/* SPDX-License-Identifier: GPL-2.0-or-later */
.pragma library
.import org.kde.taskmanager as TaskManager

// Resolve IDs against the current model each time; row indices can change
// while the shortcut is held when windows close or a group becomes one window.
function windowsForTask(task, model) {
    const roles = TaskManager.AbstractTasksModel;
    const result = [];
    const parent = task.modelIndex();
    const count = task.model.IsGroupParent ? model.rowCount(parent) : 1;
    for (let i = 0; i < count; ++i) {
        const index = task.model.IsGroupParent ? model.makeModelIndex(task.index, i) : parent;
        const ids = model.data(index, roles.WinIdList);
        if (!ids || !ids.length) continue;
        result.push({index: index, id: String(ids[0]),
            minimized: model.data(index, roles.IsMinimized),
            active: model.data(index, roles.IsActive),
            stacking: model.data(index, roles.StackingOrder)});
    }
    return result;
}

function nextWindow(windows, selectedId) {
    if (!windows.length) return null;
    let lastUsed = windows[0];
    let active = -1;
    for (let i = 0; i < windows.length; ++i) {
        if (selectedId && windows[i].id === selectedId) {
            return windows[(i + 1) % windows.length];
        }
        if (windows[i].active) active = i;
        if (isFinite(windows[i].stacking)
                && (!isFinite(lastUsed.stacking) || windows[i].stacking > lastUsed.stacking)) {
            lastUsed = windows[i];
        }
    }
    return active >= 0 ? windows[(active + 1) % windows.length] : lastUsed;
}
