/* SPDX-License-Identifier: LGPL-2.0-or-later */
import QtQuick
import QtQml.Models

DelegateModel {
    id: orderedModel
    required property TrayOrdering ordering
    property bool sorting: false
    onOrderingChanged: sort()
    Component.onCompleted: sort()

    function determinePosition(item) {
        let lower = 0;
        let upper = items.count;
        const order = ordering.getItemOrder(item.model.itemId);
        while (lower < upper) {
            const middle = Math.floor(lower + (upper - lower) / 2);
            if (order < ordering.getItemOrder(items.get(middle).model.itemId)) {
                upper = middle;
            } else {
                lower = middle + 1;
            }
        }
        return lower;
    }

    function sort() {
        if (sorting || !ordering || !unsortedItems) return;
        sorting = true;
        while (unsortedItems.count > 0) {
            const item = unsortedItems.get(0);
            const position = determinePosition(item);
            item.groups = "items";
            items.move(item.itemsIndex, position);
        }
        sorting = false;
    }

    items.includeByDefault: false
    groups: DelegateModelGroup {
        id: unsortedItems
        name: "unsorted"
        includeByDefault: true
        onChanged: orderedModel.sort()
    }
}
