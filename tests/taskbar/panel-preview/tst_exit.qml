import QtQuick
import QtTest

TestCase {
    id: test
    name: "CenteredPanelPreviewExit"
    when: windowShown
    width: 640
    height: 100
    visible: true
    property var control: null
    Item { id: panel; width: 600; height: 40; y: 20 }
    SignalSpy { id: exits; target: test.control; signalName: "exitRequested" }

    function init() {
        panel.width = 600;
        panel.height = 40;
        const component = Qt.createComponent(Qt.resolvedUrl("../../../scripts/panel-preview/PreviewExit.qml"));
        compare(component.status, Component.Ready, component.errorString());
        control = component.createObject(panel, {restoreCommand: "printf preview-exit-smoke", panelId: 2});
        verify(control !== null);
        wait(30);
        exits.clear();
    }
    function cleanup() {
        control.destroy();
        control = null;
        wait(30);
    }
    function test_exactCenterAcrossWidths() {
        const widths = [320, 800, 1280, 1920, 3440];
        for (const width of widths) {
            panel.width = width;
            wait(5);
            verify(Math.abs(control.x + control.width / 2 - width / 2) < 0.01);
            verify(Math.abs(control.y + control.height / 2 - panel.height / 2) < 0.01);
        }
        compare(control.Accessible.name, "Exit preview");
        verify(control.z > 1000);
    }
    function test_clickInvokesRealExecutableEngineOnce() {
        mouseClick(control, control.width / 2, control.height / 2);
        tryCompare(control, "lastExitCode", 0, 3000);
        compare(control.lastOutput, "preview-exit-smoke");
        compare(exits.count, 1);
        mouseClick(control, control.width / 2, control.height / 2);
        compare(exits.count, 1);
    }
    function test_keyboardActivation() {
        control.forceActiveFocus();
        keyClick(Qt.Key_Space);
        tryCompare(control, "lastExitCode", 0, 3000);
        compare(exits.count, 1);
    }
    function test_missingCommandCannotActivate() {
        control.restoreCommand = "";
        mouseClick(control, control.width / 2, control.height / 2);
        compare(exits.count, 0);
        compare(control.busy, false);
    }
}
