import QtQuick
import QtTest
import org.kde.plasma.private.mpris as Mpris
import "../ui" as UI

TestCase {
    id: test
    name: "PreviewGeometryStability"
    when: windowShown
    visible: true
    width: 800; height: 600
    property var fixtureConfiguration: ({thmbnlCaptionAlignment: 0, showMuteBtn: false})
    function i18n(text, arg) { return text.replace("%1", arg || ""); }
    QtObject {
        id: tasks
        property rect availableScreenRect: Qt.rect(0,0,800,560)
        property bool toolTipOpen: true
        property bool iconsOnly: true
        function windowsHovered(ids, hover) {}
        function cancelHighlightWindows() {}
    }
    ListModel {
        id: tasksModel
        function makeModelIndex(i,j) { return j === undefined ? i : j; }
        function requestActivate(i) {}
        function requestClose(i) {}
    }
    QtObject {
        id: owner
        property real attentionAnimOpacity: 1
        property bool previewVisible: true
        property bool hasAudioStream: false
        property bool muted: false
        function hideImmediately() {}
    }
    QtObject {
        id: previewRoot
        property QtObject parentTask: owner
        property var playerData: ({playbackStatus: Mpris.PlaybackStatus.Playing,
            canGoPrevious:true, canGoNext:true, canPlay:true, canPause:true})
        property string display: "Media window"
        property string icon: "application-x-executable"
        property bool active: false
        property bool minimized: true
        property bool demandsAttention: false
        property bool isPeeking: false
        property bool taskHovered: false
        property bool containsDrag: false
        property bool popupVisible: true
        property bool forceList: false
        property var windows: ["media"]
        property string shortcutWindowId: ""
        property var modelIndex: 0
        property int taskIndex: 0
        property real availableWidth: 784
        property real availableHeight: 544
        function endPeek(item) {}
        function cancelPeek() {}
        function dismiss() {}
        function tryFocusFirstRow() {}
    }
    Component { id: rowComponent; UI.WindowThumbnail { root: previewRoot } }
    Component { id: groupComponent; UI.GroupThumbnails { root: previewRoot; width: implicitWidth; height: implicitHeight } }
    property var row: null
    property var group: null
    function cleanup() {
        if (row) row.destroy(); row = null;
        if (group) group.destroy(); group = null;
        wait(30); tasksModel.clear();
    }
    function findCaptureLoader(item) {
        if (item.sourceComponent !== undefined && item.item !== undefined && item.width === 164 && item.height === 94) return item;
        for (var i=0;i<item.children.length;++i) {
            var found = findCaptureLoader(item.children[i]);
            if (found) return found;
        }
        return null;
    }
    function test_mediaControlsSizedBeforeFirstFrame() {
        row = rowComponent.createObject(test); verify(row);
        var firstHeight = row.implicitHeight;
        wait(200);
        compare(row.implicitHeight, firstHeight);
    }
    function test_captureReadinessCannotResizeMediaPreview() {
        row = rowComponent.createObject(test); wait(150);
        var height = row.implicitHeight;
        for (var fittedHeight of [94,48,0,80,94,32,94]) {
            row.thumbnailHeight = fittedHeight;
            wait(20);
            compare(row.implicitHeight,height);
        }
    }
    function test_sameWindowArrayDoesNotRebuildCapture() {
        row = rowComponent.createObject(test); wait(150);
        var loader = findCaptureLoader(row); verify(loader); verify(loader.item);
        var original = loader.item;
        for (var i=0; i<8; ++i) {
            previewRoot.windows = ["media"];
            wait(20);
            compare(loader.item, original);
        }
        previewRoot.windows = ["different-window"];
        wait(50);
        verify(loader.item !== original);
        previewRoot.windows = ["media"];
    }
    function test_groupMediaGeometryDoesNotOscillate() {
        for (var i=0;i<3;++i) tasksModel.append({display:"Window "+i,
            decoration:"application-x-executable", IsActive:false, IsMinimized:true,
            IsDemandingAttention:false, WinIdList:["window"+i]});
        group = groupComponent.createObject(test); wait(200);
        function findList(item) {
            if (item.itemAtIndex !== undefined && item.count === 3) return item;
            for (var j=0;j<item.children.length;++j) { var found=findList(item.children[j]); if(found)return found; }
            return null;
        }
        var list=findList(group); verify(list);
        var height=group.implicitHeight, width=group.implicitWidth;
        for (var step=0;step<8;++step) {
            for (var j=0;j<3;++j) { var item=list.itemAtIndex(j); verify(item); item.thumbnailHeight=32+(step+j)%3*30; }
            wait(25);
            compare(group.implicitHeight,height); compare(group.implicitWidth,width);
        }
    }
}
