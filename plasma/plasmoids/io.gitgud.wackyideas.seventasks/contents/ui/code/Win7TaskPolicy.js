/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library

// All dimensions are logical pixels. Qt applies the device scale once.
function labeledTaskWidth(availableWidth, fixedCount, labeledCount, slotCount,
                          fixedWidth, spacing, minimumWidth, maximumWidth) {
    if (labeledCount <= 0 || !isFinite(availableWidth)) {
        return minimumWidth;
    }

    // ListView retains a spacing slot even for a hidden, zero-width startup.
    const gaps = Math.max(0, slotCount - 1) * spacing;
    const width = Math.floor((availableWidth - fixedCount * fixedWidth - gaps) / labeledCount);
    return Math.min(maximumWidth, Math.max(minimumWidth, width));
}
