// SPDX-License-Identifier: GPL-2.0-or-later

function verticalSnap(up) {
    var window = workspace.activeWindow;
    if (!window || window.dock || window.desktopWindow || window.fullScreen
            || window.minimized || window.move || window.resize) {
        return;
    }

    // Tile is the requested state, so a second press works even before a
    // Wayland client acknowledges its new frame size. Full-height side tiles
    // touch both edges but must still become quarters on the first Up/Down.
    var geometry = window.tile ? window.tile.relativeGeometry : null;
    var atEdge = geometry && geometry.height < 1
        && (up ? Math.abs(geometry.y) < 0.0001
            : Math.abs(geometry.y + geometry.height - 1) < 0.0001);

    if (!up && window.maximizeMode > 0) {
        // Let KWin restore its saved geometry before considering bottom tiling.
        window.setMaximize(false, false);
    } else if (up && (atEdge || window.maximizeMode === 3)) {
        if (window.maximizable) {
            window.setMaximize(true, true);
        }
    } else if (!up && atEdge) {
        if (window.minimizable) {
            window.minimized = true;
        }
    } else if (up) {
        workspace.slotWindowQuickTileTop();
    } else {
        workspace.slotWindowQuickTileBottom();
    }
}

// The installer transfers the existing bindings from KWin's native actions.
// Empty defaults also let the package be enabled without stealing shortcuts.
registerShortcut("Aero Vertical Snap Up", "Aero: tile up, then maximize", "",
    function () { verticalSnap(true); });
registerShortcut("Aero Vertical Snap Down", "Aero: tile down, then minimize", "",
    function () { verticalSnap(false); });
