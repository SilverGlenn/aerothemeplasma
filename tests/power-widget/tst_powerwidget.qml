/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import QtQuick.Controls
import QtTest
import org.kde.plasma.private.battery
import "../../plasma/plasmoids/io.gitgud.wackyideas.battery/contents/ui" as Aero

Item {
    width: 360
    height: 420

    function format(text, values) {
        for (var i=0; i<values.length; ++i) text = text.replace("%" + (i+1), values[i]);
        return text;
    }
    function i18n(text) { return format(text, Array.prototype.slice.call(arguments,1)); }
    function i18nc(context,text) { return format(text, Array.prototype.slice.call(arguments,2)); }
    function i18np(one,many,count) { return format(count===1 ? one : many, Array.prototype.slice.call(arguments,2)); }
    function xi18n(text) { return format(text, Array.prototype.slice.call(arguments,1)); }

    ListModel { id: batteries }
    Aero.PopupDialog {
        id: flyout
        x: 20
        y: 20
        width: 240
        height: implicitHeight
        model: batteries
        profilesInstalled: true
        profiles: ["power-saver","balanced","performance"]
        activeProfile: "balanced"
        profileHolds: []
        brightnessAvailable: true
        pluggedIn: true
    }
    Aero.BatteryItem {
        id: sampleBattery
        visible: false
        width: 240
        batteryPercent: 79
        batteryCapacity: 90
        batteryPluggedIn: true
        batteryIsPowerSupply: true
        batteryType: "Battery"
        pluggedIn: true
    }
    QtObject {
        id: brightnessApplet
        property string pluginName: "org.kde.plasma.brightness"
        signal activated()
    }
    QtObject {
        id: unrelatedApplet
        property string pluginName: "org.kde.plasma.volume"
        signal activated()
    }
    Aero.PowerBrightnessAction {
        id: brightnessAction
        applets: [unrelatedApplet, brightnessApplet]
    }
    SignalSpy { id: profileSpy; target: flyout; signalName: "activateProfileRequested" }
    SignalSpy { id: brightnessSpy; target: flyout; signalName: "brightnessRequested" }
    SignalSpy { id: optionsSpy; target: flyout; signalName: "powerOptionsRequested" }
    SignalSpy { id: activatedSpy; target: brightnessApplet; signalName: "activated" }
    SignalSpy { id: unrelatedSpy; target: unrelatedApplet; signalName: "activated" }

    TestCase {
        name: "AeroPowerWidget"
        when: windowShown
        function initTestCase() {
            batteries.append({Percent:100, Capacity:90, Energy:50, PluggedIn:true,
                IsPowerSupply:true, ChargeState:BatteryControlModel.FullyCharged,
                PrettyName:"Laptop battery", Type:"Battery"});
        }
        function init() {
            flyout.profiles = ["power-saver","balanced","performance"];
            flyout.activeProfile = "balanced";
            flyout.inhibitionReason = "";
            flyout.brightnessAvailable = true;
            brightnessAction.applets = [unrelatedApplet,brightnessApplet];
            sampleBattery.batteryChargeState = BatteryControlModel.NoCharge;
            sampleBattery.batteryPluggedIn = true;
            sampleBattery.batteryIsPowerSupply = true;
            sampleBattery.batteryPercent = 79;
            sampleBattery.remainingTime = 0;
            sampleBattery.pluggedIn = true;
            profileSpy.clear(); brightnessSpy.clear(); optionsSpy.clear();
            activatedSpy.clear(); unrelatedSpy.clear();
        }
        function label() { return findChild(sampleBattery,"batteryStatusLabel"); }
        function test_main_entry_point_compiles() {
            var component=Qt.createComponent(Qt.resolvedUrl("../../plasma/plasmoids/io.gitgud.wackyideas.battery/contents/ui/main.qml"));
            compare(component.status,Component.Ready,component.errorString());
            component.destroy();
        }
        function test_status_then_parenthesized_percentage() {
            sampleBattery.batteryChargeState = BatteryControlModel.FullyCharged;
            sampleBattery.batteryPercent = 100;
            compare(label().text,"Fully charged (100%)");
            sampleBattery.batteryChargeState = BatteryControlModel.Charging;
            compare(label().text,"Charging (100%)");
            sampleBattery.batteryChargeState = BatteryControlModel.NoCharge;
            sampleBattery.batteryPercent = 79;
            compare(label().text,"Plugged in, not charging (79%)");
        }
        function test_on_battery_and_peripheral_statuses() {
            sampleBattery.pluggedIn = false;
            sampleBattery.batteryChargeState = BatteryControlModel.Discharging;
            compare(label().text,"On battery (79%)");
            sampleBattery.remainingTime = 3600000;
            verify(label().text.endsWith("remaining (79%)"));
            sampleBattery.batteryChargeState = BatteryControlModel.NoCharge;
            sampleBattery.batteryIsPowerSupply = false;
            compare(label().text,"Available (79%)");
            sampleBattery.batteryPluggedIn = false;
            compare(label().text,"Not present");
        }
        function test_insufficient_ac_power_status_is_not_misleading() {
            sampleBattery.batteryChargeState=BatteryControlModel.Discharging;
            sampleBattery.pluggedIn=true;
            compare(label().text,"Plugged in, discharging (79%)");
        }
        function test_radio_indicators_align_with_heading() {
            var heading=findChild(flyout,"powerPlanHeading");
            var left=heading.mapToItem(flyout,0,0).x;
            var names=["powerSaverRadio","balancedRadio","performanceRadio"];
            for(var i=0;i<names.length;++i) {
                var radio=findChild(flyout,names[i]);
                fuzzyCompare(radio.indicator.mapToItem(flyout,0,0).x,left,0.5);
            }
        }
        function test_profile_selection_preserves_backend_ids() {
            var saver=findChild(flyout,"powerSaverRadio");
            mouseClick(saver);
            compare(profileSpy.count,1);
            compare(profileSpy.signalArguments[0][0],"power-saver");
            flyout.activeProfile="performance";
            compare(findChild(flyout,"performanceRadio").checked,true);
            compare(findChild(flyout,"performanceRadio").text,"High performance");
        }
        function test_unsupported_or_inhibited_profiles_are_not_selectable() {
            flyout.profiles=["power-saver","balanced"];
            compare(findChild(flyout,"performanceRadio").visible,false);
            flyout.profiles=["power-saver","balanced","performance"];
            flyout.inhibitionReason="lap-detected";
            compare(findChild(flyout,"performanceRadio").enabled,false);
        }
        function test_footer_order_and_actions() {
            var brightness=findChild(flyout,"adjustBrightnessLink");
            var options=findChild(flyout,"morePowerOptionsLink");
            verify(brightness.mapToItem(flyout,0,0).y < options.mapToItem(flyout,0,0).y);
            compare(brightness.text,"Adjust screen brightness");
            compare(options.text,"More power options");
            mouseClick(brightness); compare(brightnessSpy.count,1);
            mouseClick(options); compare(optionsSpy.count,1);
        }
        function test_keyboard_focus_flows_through_profiles_and_footer() {
            var saver=findChild(flyout,"powerSaverRadio");
            saver.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Tab); verify(findChild(flyout,"balancedRadio").activeFocus);
            keyClick(Qt.Key_Tab); verify(findChild(flyout,"performanceRadio").activeFocus);
            keyClick(Qt.Key_Tab); verify(findChild(flyout,"adjustBrightnessLink").activeFocus);
            keyClick(Qt.Key_Tab); verify(findChild(flyout,"morePowerOptionsLink").activeFocus);
            keyClick(Qt.Key_Tab); verify(saver.activeFocus);
        }
        function test_unavailable_brightness_does_not_launch() {
            brightnessAction.applets=[unrelatedApplet];
            compare(brightnessAction.available,false);
            compare(brightnessAction.activate(),false);
            compare(unrelatedSpy.count,0);
            flyout.brightnessAvailable=false;
            mouseClick(findChild(flyout,"adjustBrightnessLink"));
            compare(brightnessSpy.count,0);
        }
        function test_brightness_activates_only_existing_brightness_widget() {
            compare(brightnessAction.available,true);
            compare(brightnessAction.activate(),true);
            compare(activatedSpy.count,1);
            compare(unrelatedSpy.count,0);
        }
        function test_no_manual_block_control_in_visual_tree() {
            function walk(item) {
                if (item.text !== undefined) verify(String(item.text).indexOf("Manually block")===-1);
                for(var i=0;i<item.children.length;++i) walk(item.children[i]);
            }
            walk(flyout);
            verify(flyout.implicitHeight>0 && flyout.implicitHeight<320);
        }
    }
}
