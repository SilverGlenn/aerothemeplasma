from pathlib import Path
import os
root=Path(os.environ['SOURCE_ROOT'])
probe=Path(os.environ['TASKBAR_TEST_OUTPUT'])
import shutil
probe.mkdir(parents=True, exist_ok=True)
shutil.copytree(Path(__file__).parent/'delegate', probe/'tests', dirs_exist_ok=True)
ui=root/'plasma/plasmoids/io.gitgud.wackyideas.seventasks/contents/ui'
code=ui/'code'
s=(ui/'Task.qml').read_text()
tooltip=s[s.index('    property Item taskThumbnail:'):s.index('    // END TOOLTIP CODE')]
left='' # Sole production TapHandler is now nested in the production MouseArea.
drag=s[s.index('    ParallelAnimation {\n        id: backAnim'):s.index('    DropArea {\n        id: dropArea')]
keys=s[s.index('    function activateFromKeyboard('):s.index('    function modelIndex()')]
input_header=f'''import QtQuick
import org.kde.plasma.core as PlasmaCore
import "{code.as_uri()}/tools.js" as TaskTools
PlasmaCore.ToolTipArea {{
 id: task
 width: 60; height: 40
 property int index: 0
 property var calls: []
 property var mockPlasmoid: ({{configuration: {{showPreviews: true, groupedTaskVisualization: 1, minimizeActiveTaskOnClick: true}}, location: PlasmaCore.Types.BottomEdge}})
 property var model: ({{IsStartup:false, IsLauncher:false, IsWindow:true, IsGroupParent:false, IsMinimized:false, IsActive:false, IsDemandingAttention:false, display:"Test", decoration:"application-x-executable", WinIdList:["1"], AppPid:1, LauncherUrlWithoutIcon:"applications:test.desktop", MimeType:"application/test", MimeData:"1", index:0}})
 property Item tasksRoot: mockTasks
 property bool jumpListOpen: false
 property bool showPreviews: mockPlasmoid.configuration.showPreviews
 property alias tap: leftTapHandler
 property alias area: dragArea
 function modelIndex() {{ return tasksModel.makeModelIndex(index); }}
 function reset() {{ hideImmediately(); calls=[]; model.IsActive=false; model.IsMinimized=false; model.IsGroupParent=false; model=model; forceGroupList=false; groupChooserPinned=false; toolTipShown=false; mockPlasmoid.configuration.showPreviews=true; mockPlasmoid.configuration.groupedTaskVisualization=1; mockPlasmoid=mockPlasmoid; }}
 Item {{
  id: mockTasks
  property Item taskThumbnail: preview
  property bool toolTipOpen: false
  property bool pinnedToolTipOpen: false
  property Item dragItem: null
  property Item dragSource: null
  property Item jumpListItem: null
  property QtObject tasksModel: tasksModel
  function cancelHighlightWindows() {{ preview.isPeeking=false; }}
  function setRequestedInhibitDnd(value) {{}}
  function activateWindowView(ids) {{ task.calls.push(["view",ids]); }}
 }}
 Item {{ id: tasks; width:300; height:100 }}
 Item {{ id: taskList; property real contentX: 0; property real contentY:0 }}
 Item {{ id: containerRect; width:task.width; height:task.height }}
 Item {{ id: dragHelper }}
 property QtObject jumpList: null
 QtObject {{ id: effectWatcher; property bool registered:false }}
 QtObject {{
  id: backend
  function tryDecodeApplicationsUrl(url) {{ return url; }}
 }}
 QtObject {{
  id: tasksModel
  function makeModelIndex(i,j) {{ return j===undefined ? i : String(i)+":"+String(j); }}
  function requestActivate(i) {{ task.calls.push(["activate",i]); }}
  function requestToggleMinimized(i) {{ task.calls.push(["minimize",i]); }}
  function requestNewInstance(i) {{ task.calls.push(["new",i]); }}
  function move(i,j) {{ task.calls.push(["move",i,j]); }}
 }}
 Item {{
  id: preview
  width:180; height:84
  property QtObject parentTask
  property bool demandsAttention
  property bool minimized
  property string display
  property var icon
  property bool active
  property bool startup
  property var windows
  property var modelIndex
  property int taskIndex
  property int pidParent
  property url launcherUrl
  property bool isGroupParent
  property bool taskHovered
  property bool forceList
  property bool isPeeking:false
  function focusFirstRow() {{}}
  property bool dragDrop:false
 }}
'''
(probe/'tests').mkdir(exist_ok=True)
(probe/'tests/InputFixture.qml').write_text(input_header+(tooltip+keys+left+drag).replace('Plasmoid','mockPlasmoid')+'\n}\n')
# Keep real width bindings, list-count logic and original metric imports.
size=s[s.index('    readonly property bool hiddenStartup:'):s.index('    Behavior on implicitWidth')]
ls=(ui/'TaskList.qml').read_text()
counts=ls[ls.index('    spacing: 2'):ls.index('    readonly property int transitionDuration')]
geometry=f'''import QtQuick
import "{code.as_uri()}/layoutmetrics.js" as LayoutMetrics
import "{code.as_uri()}/Win7TaskPolicy.js" as Win7TaskPolicy
Item {{
 id: tasks
 width:320; height:40
 property bool iconsOnly:false
 property bool vertical:false
 property var plasmoid: ({{configuration: {{groupingStrategy:1,groupPopups:true}}, pluginName:"io.gitgud.wackyideas.seventasks"}})
 property var rows: []
 property alias list: taskList
 function taskInLauncherList(appId) {{ return appId === "pinned"; }}
 ListView {{
  id: taskList
  width:tasks.width; height:tasks.height
  orientation:tasks.vertical ? ListView.Vertical : ListView.Horizontal
  model: tasks.rows.length
  cacheBuffer:9999
{counts}
  delegate: Item {{
   required property int index
   property var model: tasks.rows[index]
   property string appId: model.AppId
   property Item tasksRoot: tasks
   width:implicitWidth; height:implicitHeight
{size}
  }}
 }}
}}
'''
(probe/'tests/GeometryFixture.qml').write_text(geometry)
print('Generated source-extracted fixtures:',probe/'tests')

# Real component bodies; only Plasma attached configuration is injected.
shutil.copytree(Path(__file__).parent/'previews', probe/'previews', dirs_exist_ok=True)
shutil.copytree(ui, probe/'ui', dirs_exist_ok=True)
for p in (probe/'ui').glob('*.qml'):
    text=p.read_text().replace('import org.kde.plasma.plasmoid', '// Applet configuration injected by test fixture')
    text=text.replace('Plasmoid.configuration.', 'fixtureConfiguration.')
    p.write_text(text)

(probe/'snapshots').mkdir(exist_ok=True)
for folder in ['tests', 'previews']:
    (probe/folder/'SnapshotPaths.js').write_text('var directory = ' + repr(str(probe/'snapshots')) + ';\n')
