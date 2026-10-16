/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import QtQuick.Controls
import QtTest
import "../contents/ui" as Aero

Item {
    width: 640
    height: 240

    Aero.AeroSearchField {
        id: search
        x: 20
        y: 20
        width: 320
    }
    Aero.AeroButton {
        id: button
        x: 20
        y: 80
        text: "New desktop"
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
    }

    SignalSpy {
        id: clickSpy
        target: button
        signalName: "clicked"
    }
    SignalSpy {
        id: textSpy
        target: search
        signalName: "textChanged"
    }

    TestCase {
        name: "AeroOverviewControls"
        when: windowShown

        function init() {
            button.enabled = true;
            search.readOnly = false;
            search.clear();
            search.focus = false;
            clickSpy.clear();
            textSpy.clear();
        }

        function test_dimensions_and_cue() {
            verify(button.implicitWidth >= 100 && button.implicitWidth < 180);
            verify(button.implicitHeight >= 26 && button.implicitHeight < 40);
            verify(search.implicitHeight >= 26 && search.implicitHeight < 40);
            compare(search.placeholderText, "Search windows and apps");
            compare(search.background.color, "#ffffff");
            compare(findChild(search, "searchGlyph").visible, true);
            compare(findChild(search, "clearSearch").visible, false);
        }

        function test_instant_search_and_clear() {
            search.forceActiveFocus();
            keyClick(Qt.Key_K);
            keyClick(Qt.Key_O);
            keyClick(Qt.Key_N);
            compare(search.text.toLowerCase(), "kon");
            compare(textSpy.count, 3);
            var clear = findChild(search, "clearSearch");
            compare(clear.visible, true);
            compare(findChild(search, "searchGlyph").visible, false);
            mouseClick(clear);
            compare(search.text, "");
            compare(search.activeFocus, true);
            compare(findChild(search, "searchGlyph").visible, true);
        }

        function test_refocus_selects_previous_query() {
            search.text = "Konsole";
            button.forceActiveFocus();
            search.forceActiveFocus();
            compare(search.selectedText, "Konsole");
        }

        function test_search_shortcuts() {
            search.text = "Konsole";
            button.forceActiveFocus();
            keyClick(Qt.Key_E, Qt.ControlModifier);
            compare(search.activeFocus, true);
            compare(search.selectedText, "Konsole");
            button.forceActiveFocus();
            keyClick(Qt.Key_F, Qt.ControlModifier);
            compare(search.activeFocus, true);
            compare(search.selectedText, "Konsole");
        }

        function test_mouse_button_activation() {
            mouseClick(button);
            compare(clickSpy.count, 1);
        }

        function test_keyboard_button_activation() {
            button.forceActiveFocus(Qt.TabFocusReason);
            verify(button.visualFocus);
            keyClick(Qt.Key_Return);
            compare(clickSpy.count, 1);
            keyClick(Qt.Key_Space);
            compare(clickSpy.count, 2);
        }

        function test_disabled_button_does_not_activate() {
            button.enabled = false;
            mouseClick(button);
            compare(clickSpy.count, 0);
        }

        function test_readonly_search_cannot_clear() {
            search.text = "Konsole";
            search.readOnly = true;
            compare(findChild(search, "clearSearch").enabled, false);
            mouseClick(findChild(search, "clearSearch"));
            compare(search.text, "Konsole");
        }
    }
}
