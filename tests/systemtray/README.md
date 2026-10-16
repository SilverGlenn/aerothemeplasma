# System tray drag and drop regressions

Run with Qt 6 Quick and QuickTest, KDE Config, and KDE ItemModels packages:

```sh
cmake -S tests/systemtray -B /tmp/aero-systemtray-drag-tests
cmake --build /tmp/aero-systemtray-drag-tests -j2
ctest --test-dir /tmp/aero-systemtray-drag-tests --output-on-failure
```

The tests send native MIME drag events to separate panel and drawer
QQuickWindows, exercise the production drag handler, and check visibility
settings, targeted drops, cancellation, and click handling. The ordering tests
use the production ordered delegate models and KDE's actual KConfigPropertyMap
with the tray's XML schema. They reload settings from disk and recreate both
views with reversed application registration order to check persistent placement.
They run offscreen
and do not install the widget or access the desktop's session bus. Compositor
drag cursors and popup placement still need a live Plasma session check.

Live Wayland verification on 2026-10-16 used three temporary StatusNotifier
icons. Panel-to-drawer and drawer-to-panel drags succeeded, a drawer icon moved
to the first position, and both the saved settings and rendered positions
survived a real Plasma restart. The test icons and temporary screen-control
session were removed afterwards.

The live check exposed a Qt Wayland crash when reading a same-process drag's
MIME payload. Tray drags now validate an instance-specific, per-drag MIME format
without reading the payload. Regressions cover payload-free enter/drop handling
and rejection of stale or foreign drag sessions.
