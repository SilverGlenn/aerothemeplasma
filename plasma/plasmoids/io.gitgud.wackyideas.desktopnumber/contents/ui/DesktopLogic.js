// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// Wayland uses UUIDs, X11 uses numeric IDs. Neither is a display position:
// resolve against the ordered IDs so renaming/reordering desktops stays correct.
function numberForDesktop(ids, currentId) {
    const index = ids.indexOf(currentId);
    return index < 0 ? 0 : index + 1;
}
