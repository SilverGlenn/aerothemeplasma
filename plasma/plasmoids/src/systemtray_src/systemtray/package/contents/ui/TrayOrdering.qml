/* SPDX-License-Identifier: LGPL-2.0-or-later */
import QtQuick

QtObject {
    required property var configuration

    function readOrder() {
        try {
            const order = JSON.parse(configuration.itemOrdering || "{}");
            if (order && typeof order === "object" && !Array.isArray(order)) {
                return order;
            }
        } catch (error) {
            // An invalid saved value must not prevent the tray from loading.
        }
        return {};
    }

    function getItemOrder(id) {
        const order = readOrder();
        return typeof order[id] === "number" ? order[id] : -1;
    }

    function itemIds(model) {
        const ids = [];
        for (let i = 0; i < model.items.count; ++i) {
            ids.push(model.items.get(i).model.itemId);
        }
        return ids;
    }

    function saveIds(ids) {
        // Each icon belongs to one view. Keep the other view's saved positions
        // (and temporarily absent applications) when saving this view's order.
        const order = readOrder();
        for (let i = 0; i < ids.length; ++i) {
            if (ids[i]) order[ids[i]] = i;
        }
        configuration.itemOrdering = JSON.stringify(order);
        configuration.writeConfig();
    }

    function move(model, itemId, targetItemId) {
        const ids = itemIds(model);
        const from = ids.indexOf(itemId);
        const target = ids.indexOf(targetItemId);
        if (from !== -1) {
            const to = target === -1 ? ids.length - 1 : target;
            if (from === to) return;
            model.items.move(from, to);
            saveIds(itemIds(model));
        } else {
            // Save the destination before changing visibility, so the new
            // delegate is inserted at the requested position on its first frame.
            ids.splice(target === -1 ? ids.length : target, 0, itemId);
            saveIds(ids);
        }
    }
}
