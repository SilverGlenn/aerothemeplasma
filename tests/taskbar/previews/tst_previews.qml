import QtQuick
import QtTest
import QtQuick.Window
import "SnapshotPaths.js" as Snapshots
import org.kde.plasma.private.mpris as Mpris
import "../ui" as UI
import "../ui/code/Win7PreviewMetrics.js" as Metrics

TestCase {
    id: test
    name: "Win7Previews"
    when: windowShown
    width: 800; height: 600
    visible: true
    property var fixtureConfiguration: ({thmbnlCaptionAlignment: 0, showMuteBtn: false})
    function i18n(text, arg) { return text.replace("%1", arg || ""); }
    QtObject {
        id: tasks
        property rect availableScreenRect: Qt.rect(0, 0, 800, 560)
        property bool toolTipOpen: true
        property bool iconsOnly: true
        property int hoverCalls: 0
        property int cancelCalls: 0
        function windowsHovered(ids, hover) { if (hover) ++hoverCalls; }
        function cancelHighlightWindows() { ++cancelCalls; }
    }
    ListModel {
        id: tasksModel
        property int activated: -1
        property int closed: -1
        function makeModelIndex(parentIndex, childIndex) { return childIndex === undefined ? parentIndex : childIndex; }
        function requestActivate(index) { activated = index; }
        function requestClose(index) { closed = index; }
        function requestOpenUrls(index, urls) {}
    }
    QtObject { id: mpris2Source; function playerForLauncherUrl(url, pid) { return null; } }
    QtObject {
        id: parentTask
        property bool previewVisible: true
        property bool hasAudioStream: false
        property bool muted: false
        property real attentionAnimOpacity: 1
        property int dismissed: 0
        function hideImmediately() { ++dismissed; previewVisible = false; tasks.toolTipOpen = false; }
    }
    property int mediaCalls: 0
    property var mediaPlayer: ({playbackStatus: Mpris.PlaybackStatus.Playing, canGoPrevious: true, canGoNext: true, canPause: true, canPlay: true, Previous: function() { ++test.mediaCalls; }, Next: function() { ++test.mediaCalls; }, Pause: function() { ++test.mediaCalls; }, Play: function() { ++test.mediaCalls; }})
    QtObject {
        id: mediaRoot
        property QtObject parentTask: test.fixtureParentTask
        property var playerData: test.mediaPlayer
        property string display: "Media window"
        property string icon: "application-x-executable"
        property bool active: false
        property bool minimized: true
        property bool demandsAttention: false
        property bool isPeeking: false
        property bool containsDrag: false
        property bool popupVisible: test.fixtureParentTask.previewVisible
        property var windows: ["media"]
        property string shortcutWindowId: ""
        property var modelIndex: 9
        property real availableWidth: 784
        property real availableHeight: 544
        function endPeek(owner) {}
        function cancelPeek() {}
        function dismiss() { test.mediaDismissed++; }
    }
    property int mediaDismissed: 0
    Component { id: mediaComponent; UI.WindowThumbnail { root: mediaRoot } }
    Component { id: tooltipComponent; UI.ToolTip { width: implicitWidth; height: implicitHeight } }
    property QtObject fixtureParentTask: parentTask
    property var tip: null
    Rectangle {
        id: snapshotSurface
        width: test.tip ? test.tip.width : 1
        height: test.tip ? test.tip.height : 1
        color: "#41586c" // Controlled backing, not a Plasma dialog or Aero frame.
    }
    function saveSnapshot(name) {
        var done=false;
        verify(snapshotSurface.grabToImage(function(result) {
            verify(result.saveToFile(Snapshots.directory+"/"+name+"-"+Screen.devicePixelRatio+".png"));
            done=true;
        }));
        tryVerify(function(){return done;});
    }
    function init() {
        tasks.availableScreenRect = Qt.rect(0, 0, 800, 560);
        tasks.toolTipOpen = true; parentTask.previewVisible = true; tasks.iconsOnly = true;
        tasks.hoverCalls = 0; tasks.cancelCalls = 0;
        tasksModel.activated = -1; tasksModel.closed = -1;
        parentTask.dismissed = 0;
        tasksModel.clear();
        tip = tooltipComponent.createObject(snapshotSurface, {parentTask: parentTask, display: "Preview title", icon: "application-x-executable", active: false, minimized: true, windows: ["one"], taskIndex: 0, modelIndex: 7});
        verify(tip !== null);
        wait(100);
    }
    function cleanup() { if(tip) tip.destroy(); tip = null; wait(50); }
    function descend(item, predicate) {
        if (predicate(item)) return item;
        if(item.children) for(var i=0;i<item.children.length;++i) { var result = descend(item.children[i], predicate); if(result) return result; }
        return null;
    }
    function thumbnail() { return descend(tip, function(item) { return item.closeTask !== undefined; }); }
    function closeButton(row) { return descend(row, function(item) { return item.Accessible && item.Accessible.name === "Close " + row.display; }); }
    function test_actualScreenScale() {
        compare(Screen.devicePixelRatio, Snapshots.expectedDpr);
        console.info("Actual offscreen Screen DPR:", Screen.devicePixelRatio);
    }
    function test_metrics() {
        compare(Metrics.horizontalExtent(0, 180, 2), 0);
        compare(Metrics.horizontalExtent(4, 180, 2), 726);
        compare(Metrics.needsList(4,180,2,726), false);
        compare(Metrics.needsList(4,180,2,725), true);
        compare(Metrics.fitPreview(1600,900,164,94).width, 164);
        compare(Metrics.fitPreview(900,1600,164,94).height, 94);
        compare(Metrics.fitPreview(0,0,164,94).height, 94);
    }
    function test_headerAndClose() {
        var row = thumbnail(); verify(row);
        var close = closeButton(row); verify(close);
        compare(close.width, 20); compare(close.height, 20);
        var before = tip.implicitHeight;
        tasks.iconsOnly = false; wait(50);
        compare(tip.implicitHeight, before);
        verify(close.visible); verify(close.x + close.width <= row.width);
        mouseClick(close, 10, 10);
        compare(tasksModel.closed, 7); compare(tasksModel.activated, -1); compare(parentTask.dismissed, 1);
    }
    function test_keyboard() {
        var row = thumbnail(); var close = closeButton(row);
        close.forceActiveFocus(); keyClick(Qt.Key_Space);
        compare(tasksModel.closed, 7); compare(tasksModel.activated, -1);
        tasks.toolTipOpen = true;
        row.forceActiveFocus(); keyClick(Qt.Key_Return);
        compare(tasksModel.activated, 7);
    }
    function test_peekOwnerAndDismiss() {
        var owner1 = thumbnail(); var owner2 = test;
        tip.beginPeek(owner1, ["one"]); compare(tasks.hoverCalls, 1);
        tip.beginPeek(owner2, ["two"]); compare(tasks.hoverCalls, 2);
        tip.endPeek(owner1); compare(tasks.cancelCalls, 0); verify(tip.isPeeking);
        parentTask.previewVisible = false; compare(tasks.cancelCalls, 1); compare(tip.isPeeking, false);
        parentTask.previewVisible = true; tip.beginPeek(owner1, ["one"]);
        owner1.forceActiveFocus(); keyClick(Qt.Key_Escape);
        compare(tasks.cancelCalls, 2); compare(parentTask.dismissed, 1);
    }
    function test_workAreaClamp() {
        tasks.availableScreenRect = Qt.rect(0,0,140,160); wait(50);
        verify(tip.width <= 124); verify(tip.height <= 144);
        var row=thumbnail(); var close=closeButton(row);
        verify(close.mapToItem(tip,close.width,close.height).x <= tip.width);
        verify(close.mapToItem(tip,close.width,close.height).y <= tip.height);
    }
    function addWindows(count) {
        for(var i=0;i<count;++i) tasksModel.append({display: "Window " + i + " with a long title", decoration: "application-x-executable", IsActive: false, IsMinimized: true, IsDemandingAttention: false, WinIdList: ["window" + i]});
    }
    function test_groupOverflow() {
        addWindows(30);
        tip.isGroupParent = true; wait(300);
        verify(tip.implicitWidth <= tip.availableWidth);
        verify(tip.implicitHeight <= tip.availableHeight);
        var group=descend(tip,function(item){return item.isList !== undefined;}); verify(group); verify(group.isList);
        var list=descend(group,function(item){return item.measureItems !== undefined;}); verify(list);
        verify(list.interactive); verify(list.contentHeight > list.height);
        list.positionViewAtIndex(29,ListView.End); wait(200);
        var row=list.itemAtIndex(29); verify(row); verify(row.width <= list.width);
        var close=closeButton(row); verify(close);
        mouseClick(close,10,10);
        compare(tasksModel.closed,29); compare(tasksModel.activated,-1); compare(parentTask.dismissed,0);
    }
    function test_groupCountAndGutter() {
        addWindows(2); tip.isGroupParent=true; wait(300);
        var group=descend(tip,function(item){return item.isList !== undefined;}); verify(group); compare(group.isList,false);
        var list=descend(group,function(item){return item.measureItems !== undefined;}); verify(list);
        var first=list.itemAtIndex(0), second=list.itemAtIndex(1); verify(first); verify(second);
        verify(second.x >= first.x + first.width); compare(second.x-first.x-first.width,group.gutter);
        tasksModel.remove(1); wait(100); compare(list.count,1); verify(tip.width > 0);
    }
    function test_shortcutSelectionHighlightsMatchingWindow() {
        // Native task roles supply window-ID arrays. ListModel turns nested
        // arrays into ListModels, so use the root's real array for this check.
        var row=thumbnail(); verify(row);
        tip.shortcutWindowId="one";
        compare(row.shortcutSelected,true);
        var frame=descend(row,function(item){return String(item.prefix)==="active";});
        verify(frame); compare(frame.visible,true);
        var height=tip.height, width=tip.width;
        tip.shortcutWindowId="other-window";
        compare(row.shortcutSelected,false);
        compare(frame.visible,false);
        compare(tip.height,height); compare(tip.width,width);
    }
    function test_listHoverPeekTimingAndCloseCancellation() {
        addWindows(8); tasksModel.setProperty(0,"IsMinimized",false);
        tip.isGroupParent=true; wait(200);
        var list=descend(tip,function(item){return item.measureItems !== undefined;});
        var row=list.itemAtIndex(0); verify(row);
        mouseMove(row, 4, row.height / 2);
        wait(400); compare(tasks.hoverCalls,0);
        wait(450); compare(tasks.hoverCalls,1); verify(tip.isPeeking);
        var close=closeButton(row); mouseMove(close,10,10); wait(30);
        compare(tip.isPeeking,false); compare(tasks.cancelCalls,1);
        parentTask.previewVisible=false; wait(850); compare(tasks.hoverCalls,1);
    }
    function test_listKeyboardScrollAndClose() {
        addWindows(30); tip.isGroupParent=true; wait(200);
        var list=descend(tip,function(item){return item.measureItems !== undefined;});
        list.positionViewAtIndex(29,ListView.End); wait(100);
        var row=list.itemAtIndex(29); verify(row);
        var close=closeButton(row); close.forceActiveFocus();
        wait(50); verify(row.y >= list.contentY); verify(row.y+row.height <= list.contentY+list.height);
        keyClick(Qt.Key_Return); compare(tasksModel.closed,29); compare(tasksModel.activated,-1); compare(parentTask.dismissed,0);
        row.forceActiveFocus(); keyClick(Qt.Key_Return); compare(tasksModel.activated,29); compare(parentTask.dismissed,1);
    }
    function test_liveWorkAreaAndPresentationChange() {
        addWindows(4); tip.isGroupParent=true; wait(200);
        var group=descend(tip,function(item){return item.isList !== undefined;}); compare(group.isList,false);
        tasks.availableScreenRect=Qt.rect(0,0,640,480); wait(200);
        compare(group.isList,true); verify(tip.width<=624); verify(tip.height<=464);
        tasks.availableScreenRect=Qt.rect(0,0,1024,728); wait(200);
        compare(group.isList,false); verify(tip.width<=1008); verify(tip.height<=712);
        tasksModel.clear(); wait(100); verify(tip.width>0); verify(tip.height>0);
        addWindows(1); wait(150); verify(tip.width>0); verify(tip.height>0);
    }

    function test_listArrowNavigation() {
        addWindows(30); tip.isGroupParent=true; wait(200);
        var list=descend(tip,function(item){return item.measureItems !== undefined;});
        var first=list.itemAtIndex(0); first.forceActiveFocus();
        list.currentIndex=0; keyClick(Qt.Key_Down); wait(50);
        compare(list.currentIndex,1);
        verify(list.currentItem.activeFocus);
        keyClick(Qt.Key_Return); compare(tasksModel.activated,1);
    }

    function test_nativeMediaToolbarRetained() {
        var row=mediaComponent.createObject(test); verify(row); wait(150);
        verify(row.toolbarHeight >= 24);
        verify(row.implicitHeight <= mediaRoot.availableHeight);
        var play=descend(row,function(item){return item.mediaIcon === "pause";}); verify(play);
        mediaCalls=0; mediaDismissed=0;
        mouseClick(play,play.width/2,play.height/2);
        compare(mediaCalls,1); compare(tasksModel.activated,-1); compare(mediaDismissed,0);
        row.destroy(); wait(50);
    }

    function test_mediaKeyboardAccessibility() {
        var row=mediaComponent.createObject(test); wait(150);
        var play=descend(row,function(item){return item.accessibleName === "Pause";}); verify(play);
        mediaCalls=0; mediaDismissed=0;
        play.forceActiveFocus(); keyClick(Qt.Key_Space);
        compare(mediaCalls,1); compare(mediaDismissed,0); compare(tasksModel.activated,-1);
        mediaPlayer=Object.assign({},mediaPlayer,{canPause:false,canPlay:false}); wait(30);
        verify(!play.enabled); play.activate(); compare(mediaCalls,1);
        mediaPlayer=Object.assign({},mediaPlayer,{canPause:true,canPlay:true});
        row.destroy(); wait(50);
    }
    function test_keyboardFocusEntryNotHover() {
        addWindows(2); tip.isGroupParent=true; tip.forceList=true; wait(200);
        var list=descend(tip,function(item){return item.measureItems !== undefined;});
        verify(!list.currentItem.activeFocus);
        tip.focusFirstRow(); tryCompare(list.currentItem,"activeFocus",true);
        keyClick(Qt.Key_Return); compare(tasksModel.activated,0);
    }
    function test_reviewSnapshots() {
        addWindows(2); tip.isGroupParent=true; tip.forceList=true; wait(350);
        saveSnapshot("basic-list");
        tip.forceList=false; wait(350);
        saveSnapshot("icon-fallback-previews");
        tasks.availableScreenRect=Qt.rect(0,0,320,200); tip.forceList=true; wait(350);
        saveSnapshot("narrow-list");
    }

    QtObject { id: otherOwner; property real attentionAnimOpacity: 1; property bool previewVisible: true; function hideImmediately() { previewVisible=false; } }
    function test_forceListWithoutHoverPreviews() {
        tasks.iconsOnly=false; addWindows(2); tip.isGroupParent=true; tip.forceList=true; wait(200);
        var group=descend(tip,function(item){return item.isList !== undefined;}); verify(group.isList);
        var list=descend(tip,function(item){return item.measureItems !== undefined;});
        var row=list.itemAtIndex(0); verify(row); verify(row.activateTask !== undefined);
        row.forceActiveFocus(); keyClick(Qt.Key_Return); compare(tasksModel.activated,0); compare(parentTask.dismissed,1);
    }
    Component { id: transientOwner; QtObject { property real attentionAnimOpacity: 1; property bool previewVisible: true } }
    function test_ownerLocalLifetime() {
        var row=thumbnail(); tip.beginPeek(row,["one"]); verify(tip.isPeeking);
        otherOwner.previewVisible=true; tip.parentTask=otherOwner;
        compare(tasks.cancelCalls,1); compare(tip.isPeeking,false);
        tip.beginPeek(row,["two"]); verify(tip.isPeeking);
        parentTask.previewVisible=false; tasks.toolTipOpen=false;
        verify(tip.popupVisible); verify(tip.isPeeking); compare(tasks.cancelCalls,1);
        otherOwner.previewVisible=false; compare(tasks.cancelCalls,2); compare(tip.isPeeking,false);
        otherOwner.previewVisible=true; tip.beginPeek(row,["two"]);
        tip.parentTask=null; compare(tasks.cancelCalls,3); compare(tip.popupVisible,false);
        var owner=transientOwner.createObject(test); tip.parentTask=owner; wait(150);
        row=thumbnail(); verify(row); tip.beginPeek(row,["three"]);
        owner.destroy(); wait(50); compare(tasks.cancelCalls,4); compare(tip.popupVisible,false);
    }

}
