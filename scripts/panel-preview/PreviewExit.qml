import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

FocusScope {
    id: control
    objectName: "win7-panel-preview-exit"
    property string restoreCommand: ""
    property int panelId: -1
    property bool busy: false
    property int lastExitCode: -999
    property string lastOutput: ""
    signal exitRequested()

    anchors.centerIn: parent
    anchors.alignWhenCentered: false
    width: caption.implicitWidth + 20
    height: Math.max(18, Math.min(28, parent ? parent.height - 4 : 28))
    z: 1000000
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Exit preview"
    Accessible.description: "Restore the panel and taskbar version that was installed before this preview"
    Accessible.onPressAction: activate()

    function activate() {
        if (busy || restoreCommand.length === 0) return;
        busy = true;
        exitRequested();
        executor.connectSource(restoreCommand);
    }
    function reportGeometry() {
        if (!parent || parent.width <= 0 || parent.height <= 0 || !visible || !restoreCommand) return;
        console.info("WIN7_PANEL_EXIT_READY " + JSON.stringify({
            panelId: panelId, panelWidth: parent.width, panelHeight: parent.height,
            x: x, y: y, width: width, height: height, text: caption.text,
            centered: Math.abs(x + width / 2 - parent.width / 2) < 0.5
                && Math.abs(y + height / 2 - parent.height / 2) < 0.5
        }));
    }
    Component.onCompleted: Qt.callLater(reportGeometry)
    onXChanged: Qt.callLater(reportGeometry)
    onYChanged: Qt.callLater(reportGeometry)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            event.accepted = true;
            activate();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: mouse.pressed ? "#e016202a" : mouse.containsMouse ? "#d0354656" : "#b0212d39"
        radius: 2
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? "#ffffff" : "#b0d7e5ef"
        opacity: control.busy ? 0.65 : 1
    }
    Text {
        id: caption
        anchors.centerIn: parent
        text: "Exit preview"
        color: "white"
        font.pixelSize: 13
        font.bold: true
        font.underline: mouse.containsMouse
    }
    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: "Exit preview"
        subText: "Restore the currently installed panel"
        MouseArea {
            id: mouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            preventStealing: true
            onClicked: {
                control.forceActiveFocus();
                control.activate();
            }
        }
    }
    Plasma5Support.DataSource {
        id: executor
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            control.lastExitCode = Number(data["exit code"]);
            control.lastOutput = String(data["stdout"] || "");
            disconnectSource(sourceName);
            if (control.lastExitCode !== 0) {
                control.busy = false;
                console.warn("Panel preview restore command failed; use the terminal restore command.");
            }
        }
    }
}
