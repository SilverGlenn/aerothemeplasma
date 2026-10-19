// SPDX-License-Identifier: GPL-2.0-or-later

function copyRect(rect) {
    return {x: rect.x, y: rect.y, width: rect.width, height: rect.height};
}

function watchWindow(window) {
    var session = null;
    window.interactiveMoveResizeStarted.connect(function () {
        if (!window.resize || window.dock || window.desktopWindow || window.fullScreen) {
            return;
        }
        var frame = copyRect(window.frameGeometry);
        var client = window.clientGeometry;
        // Pin the output for this gesture. A dragged corner crossing to another
        // output must not switch to that output's unrelated panel boundary.
        session = {
            initial: frame,
            accepted: copyRect(frame),
            area: copyRect(workspace.clientArea(KWin.MaximizeArea, window)),
            screen: copyRect(workspace.clientArea(KWin.ScreenArea, window)),
            minWidth: window.minSize.width + frame.width - client.width,
            minHeight: window.minSize.height + frame.height - client.height
        };
    });

    window.interactiveMoveResizeStepped.connect(function (geometry) {
        if (!session || !window.resize) {
            return;
        }
        var next = copyRect(geometry);
        var initial = session.initial;
        var area = session.area;
        var screen = session.screen;
        var right = next.x + next.width;
        var bottom = next.y + next.height;

        // Only constrain edges with reserved panel space, and only the edges
        // being dragged. Do not move the opposite border or constrain moves.
        if (area.x > screen.x && next.x !== initial.x && next.x < area.x) {
            next.x = area.x;
            next.width = right - next.x;
        }
        if (area.y > screen.y && next.y !== initial.y && next.y < area.y) {
            next.y = area.y;
            next.height = bottom - next.y;
        }
        if (area.x + area.width < screen.x + screen.width
                && right !== initial.x + initial.width && right > area.x + area.width) {
            next.width = area.x + area.width - next.x;
        }
        if (area.y + area.height < screen.y + screen.height
                && bottom !== initial.y + initial.height && bottom > area.y + area.height) {
            next.height = area.y + area.height - next.y;
        }
        // If the fixed border leaves too little room for the application's
        // minimum size, retain the previous accepted size on that axis.
        if (next.width < Math.max(1, session.minWidth)) {
            next.x = session.accepted.x;
            next.width = session.accepted.width;
        }
        if (next.height < Math.max(1, session.minHeight)) {
            next.y = session.accepted.y;
            next.height = session.accepted.height;
        }
        session.accepted = copyRect(next);
        // Use the requested step geometry, not frameGeometry: Wayland clients
        // can still be displaying the previous size while acknowledging it.
        if (next.x !== geometry.x || next.y !== geometry.y
                || next.width !== geometry.width || next.height !== geometry.height) {
            window.frameGeometry = next;
        }
    });

    window.interactiveMoveResizeFinished.connect(function () {
        // KWin restores the starting geometry before this signal on Escape.
        session = null;
    });
}

workspace.windowAdded.connect(watchWindow);
workspace.windowList().forEach(watchWindow);
