# Private taskbar fidelity first pass: validation and staging

This independent experimental fork integrates the delivered delegate and preview
lanes, not a broad Plasma port. Original component commits:
`b780d490156b7b2ab8377dcf38805542142b2500` (delegate),
`fb0a5980488ed9819d0bdd1c95d96d5af7ee73eb` (previews).
Both were inspected and cherry-picked once into `windows7-fidelity` as `4439451`
and `4586ef7`. Integration adds bounded main null/geometry/layout refresh fixes,
keyboard popup entry, compact media accessibility, full-edge template policy,
repeatable regressions and separate opt-in staging. Native `seventasks.cpp/h` are
**unchanged**. Upstream root install scripts are not preview installation tools.

## Try it in a visible standalone window

From a terminal in your current KDE desktop:

```bash
cd ~/Projects/aerothemeplasma-win7
./scripts/try-taskbar-preview.sh
```

This uses the already installed `plasmawindowed` host, not `plasmoidviewer`.
It builds and stages the independent native/QML preview under
`~/.cache/aerothemeplasma-win7-preview`, then opens a separate window. No sudo,
widget installation, panel replacement, Plasma restart, or panel-configuration
edit is performed. Close the preview window to stop it; Ctrl+C in its launching
terminal also stops it.

The visible preview connects to your desktop's real window model/session bus.
**Its buttons operate real windows**, including activation, minimize and close.
Use those actions deliberately. It tests the task-manager widget, not the full
panel with Start, notification area, clock and Show Desktop. Windowed hosting is
not identical to a bottom panel; popup anchoring and native focus still require
live review. You can resize the window into a horizontal strip.

Each run prints its private `window.*/host.log` and config/data/cache directory.
It copies only `kdeglobals` and `plasmarc` UI preferences read-only for styling;
it does not copy or alter your panel layout. HOME, display, runtime and session
bus remain normal for the visible preview. Programs launched from its task
buttons may inherit the private XDG config/data/cache paths, so prefer existing
windows for initial testing. This is not a daily-driver replacement.

Other modes:

```bash
./scripts/try-taskbar-preview.sh --prepare-only # build/stage, no window
./scripts/try-taskbar-preview.sh --headless     # private offscreen load check; Ctrl+C to stop
```

The offscreen mode uses its own HOME/runtime/session bus and does not connect to
the logged-in compositor. The real staged package has loaded in this isolated
`plasmawindowed` host without QML loading errors; this is additional package-load
evidence, not validation of real window operations, Aero or live capture.

## Reproduce without affecting the desktop

Host checked: Qt 6.10.2, Plasma 6.6.6, KF6 6.24; differs from upstream README's
newer baseline. Existing Qt6/KDE imports and `aeroshell.taskmanager` are used.
No dependency installation is performed by these commands.

```bash
# Logs, generated fixtures and images go OUTSIDE the tracked checkout.
tests/taskbar/run.sh /tmp/win7-taskbar-integration
cmake -S scripts/preview-native -B /tmp/win7-taskbar-native
cmake --build /tmp/win7-taskbar-native -j2
scripts/stage-taskbar-preview.py stage /tmp/win7-taskbar-stage \
  --native-build /tmp/win7-taskbar-native
tests/taskbar/run-native-check.sh /tmp/win7-taskbar-native /tmp/win7-taskbar-stage
python3 tests/taskbar/test-preview-staging.py /tmp/win7-taskbar-native
```

Final matrix: **17 delegate + 20 preview QtTest passes per scale**, zero failed,
zero skipped; **111 passes total** (includes suite init/cleanup), plus **38**
production helper/main/template assertions. Staging CLI: **15** assertions using
only temporary prefixes, including same-prefix, symlink-alias, nested-copy and
native-build/stage overlap rejection before any existing files are moved.
Native build succeeds; explicit KPluginFactory load
creates a **SevenTasks Plasma::Applet** and verifies five required native methods.
This is not just a renamed QML package, but also not full shell/runtime proof.

Runner expands private HOME, XDG config/data/cache/runtime (0700), offscreen
software QtQuick, PassThrough scaling and a private session bus with no standard
activation directories. Tests do not contact the logged-in bus. Task input and
geometry fixtures extract bounded production regions on every run (real
ToolTipArea and TapHandler); task/window operations are mocked. Preview fixtures
copy production QML bodies, substituting only Plasma attached configuration for
explicit fixture configuration; installed real KDE types and existing SVGs stay.
Policy tests execute the production JS and extracted main functions/full template,
not cloned arithmetic or grep-only gates. The full applet cannot be meaningfully
created as a bare QML component without Plasma's attached applet context.

`qmllint --ignore-settings -I /usr/lib/x86_64-linux-gnu/qt6/qml` on ten affected
QML files exits 0, no syntax errors; 507 advisory warnings versus 490 for the
same files at the exported upstream base. Dynamic applet/model members and missing
static Backend information remain noisy; lint is not a clean shell gate. Known
baseline offscreen QObject/platform/SVG warnings and incubation cancellation are
not interpreted as introduced runtime failures.

## Review snapshots: what they are

`/tmp/win7-taskbar-integration/snapshots/` contains Basic-style list,
icon-fallback preview and narrow-list captures at each scale. Actual offscreen
**Screen DPR is asserted and logged as 1, 1.25, 1.5**. Capture uses asynchronous
`QQuickItem.grabToImage` (not QtTest's logical-sized grabImage, which cropped
scaled contents on this host). Native PNG sizes from the checked run:

| Capture | 100% | 125% | 150% |
| --- | --- | --- | --- |
| basic-list | 205×74 | 256×93 | 308×111 |
| icon-fallback-previews | 362×132 | 453×165 | 543×198 |
| narrow-list | 205×74 | 256×93 | 308×111 |

Fractional sizes include Qt rounding. PNGs are not PIL-resized physical-DPI
proofs; a contact sheet can place them unscaled on a labeled background for review.
These are **controlled component-layout captures**, with a solid `#41586c` harness
backing, fixture titles/models and minimized-window icon fallbacks. They are not a
live Plasma dialog, actual Windows captures, Aero Glass or live-thumbnail proof.
Examined captures show coherent compact headers, title elision and no overlapping
rows/preview shells; host icon availability differs between isolated scale sandboxes.
Actual compositor frame margins/anchoring remain unchecked. Reference images are
not bundled; no new Microsoft assets were acquired.

## Parallel preview identity and explicit loading

The staging-only CMake project has **no install rule**. It compiles existing native
sources into `plugins/plasma/applets/liblocal.win7.seventasks.preview.so`.
Staging copies the production QML/config/SVG package to
`share/plasma/plasmoids/local.win7.seventasks.preview`, derives separate metadata
(name **SevenTasks (Windows 7 private preview)**, default-disabled) while retaining
upstream authors/license. Existing stage destinations receive timestamped backups.
The upstream ID `io.gitgud.wackyideas.seventasks` is never an install destination.

Optional dedicated offscreen viewer (no panel settings/restart):

```bash
scripts/launch-taskbar-preview.sh /tmp/win7-taskbar-stage
```

This older dedicated-viewer script deliberately exits **3** on this host:
`plasmoidviewer` is unavailable. It is an offscreen validation path, not the
visible try-out command. Use `scripts/try-taskbar-preview.sh` above instead;
its installed `plasmawindowed` host has passed an isolated package-load check.
Both use explicit `XDG_DATA_DIRS`/`QT_PLUGIN_PATH`; normal Plasma must not be
assumed to discover a native module in an arbitrary user prefix. Do not
launch/restart the user's Plasma to work around normal-discovery limitations.

If later expressly approved, optional copying into an explicit user-owned prefix
is available (not run against the user's prefix during this pass):

```bash
scripts/stage-taskbar-preview.py install "$HOME/.local/win7-taskbar-preview" \
  --from-stage /tmp/win7-taskbar-stage --confirm
# Use this prefix as the argument to the isolated launcher; no auto-registration.
scripts/stage-taskbar-preview.py uninstall "$HOME/.local/win7-taskbar-preview" --confirm
```

This nonstandard prefix is intentionally not an automatic live-desktop install.
Install/uninstall require confirmation, touch only the preview ID/library, and
never change panel configuration. Stage/install reject overlapping source and
destination paths before creating backups or copying either package or library. Existing preview files are timestamp-backed-up;
uninstall keeps backups. To restore a prior preview, manually move its matching
`.backup-*` package/library back to the named paths after removing the current
preview; unrelated taskbar installation remains untouched. Before any manual live
panel addition, back up Plasma's configuration yourself under separate approval;
remove that preview widget manually before uninstalling. No script does this.

## Remaining acceptance gates

Independent correctness/fidelity reviews accepted the qualified UI/component
first pass with notes; that is not approval for live installation or parity claims.
Full panel native backend contracts, real task operations/QModelIndex wheel
behavior, external popup dismissal,
keyboard focus entry through the native popup, compositor/theme margins, touch,
Wayland capture/KWin Peek and real MPRIS remain unchecked. Accessibility is not
certified. No valid Aero visual reference exists; Basic reference cannot settle
transparency/shadows/live thumbnails or timing. These are blockers to a **parity or
live-runtime claim**, not reasons to silently broaden into an ABI/native port.
