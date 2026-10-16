/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import QtTest
import "../../plasma/plasmoids/io.gitgud.wackyideas.desktopnumber/contents/ui" as Widget
import "../../plasma/plasmoids/io.gitgud.wackyideas.desktopnumber/contents/ui/DesktopLogic.js" as Logic

Item {
    width: 320
    height: 120

    QtObject {
        id: desktops
        property var ids: ["uuid-a", "uuid-b", "uuid-c", "uuid-d", "uuid-e"]
        property var current: "uuid-a"
    }

    Widget.DesktopNumber {
        id: indicator
        width: 16
        height: 40
        number: Logic.numberForDesktop(desktops.ids, desktops.current)
    }

    TestCase {
        name: "DesktopNumber"
        when: windowShown

        function init() {
            desktops.ids = ["uuid-a", "uuid-b", "uuid-c", "uuid-d", "uuid-e"];
            desktops.current = "uuid-a";
            indicator.width = 16;
            indicator.height = 40;
        }

        function test_only_the_number() {
            var label = findChild(indicator, "desktopNumberLabel");
            compare(indicator.children.length, 1);
            compare(label.text, "1");
            compare(label.font.family, "Segoe UI");
            compare(label.font.weight, Font.Bold);
            compare(label.horizontalAlignment, Text.AlignHCenter);
            compare(label.verticalAlignment, Text.AlignVCenter);
            compare(label.renderType, Text.NativeRendering);
        }

        function test_crisp_icon_keyline_not_text_shadow() {
            var label = findChild(indicator, "desktopNumberLabel");
            compare(label.style, Text.Outline);
            compare(label.styleColor, "#20252b");
            compare(label.leftPadding, 1);
            compare(label.rightPadding, 1);
        }

        function test_tray_baseline_offset_preserves_slot_size() {
            var label = findChild(indicator, "desktopNumberLabel");
            compare(label.y, -1);
            compare(label.height, indicator.height);
            compare(label.width, indicator.width);
            indicator.height = 16;
            compare(label.y, -1);
            compare(label.height, 16);
        }

        function test_all_five_desktops_update_immediately() {
            for (var i = 0; i < desktops.ids.length; ++i) {
                desktops.current = desktops.ids[i];
                compare(indicator.displayText, String(i + 1));
                compare(findChild(indicator, "desktopNumberLabel").text, String(i + 1));
            }
        }

        function test_reordering_uses_position_not_uuid_or_name() {
            desktops.current = "uuid-b";
            compare(indicator.displayText, "2");
            desktops.ids = ["uuid-b", "uuid-a", "uuid-c", "uuid-d", "uuid-e"];
            compare(indicator.displayText, "1");
        }

        function test_x11_numeric_ids_are_also_positions() {
            compare(Logic.numberForDesktop([1, 2, 3, 4, 5], 4), 4);
            compare(Logic.numberForDesktop([3, 5, 7, 9, 11], 9), 4);
        }

        function test_unknown_or_starting_backend_does_not_lie() {
            desktops.current = "";
            compare(indicator.displayText, "");
            desktops.ids = [];
            compare(indicator.displayText, "");
        }

        function test_desktop_removal_updates_the_number() {
            desktops.current = "uuid-e";
            compare(indicator.displayText, "5");
            desktops.ids = ["uuid-a", "uuid-c", "uuid-d", "uuid-e"];
            compare(indicator.displayText, "4");
        }

        function test_size_matches_icon_slot_not_panel_height() {
            compare(indicator.numberPixelSize, 17);
            indicator.width = 24;
            compare(indicator.numberPixelSize, 25);
            indicator.width = 40;
            indicator.height = 16;
            compare(indicator.numberPixelSize, 17);
            indicator.width = 200;
            indicator.height = 200;
            verify(indicator.numberPixelSize <= 32);
        }

        function test_more_desktops_are_not_silently_clamped_to_five() {
            desktops.ids = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"];
            desktops.current = "j";
            compare(indicator.displayText, "10");
            waitForRendering(indicator);
            var label = findChild(indicator, "desktopNumberLabel");
            verify(label.contentWidth <= label.width);
        }
    }
}
