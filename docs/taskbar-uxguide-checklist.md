# Windows 7-era taskbar UX checklist

Priority: [observed taskbar](windows7-taskbar-reference.md) → Win7-era Microsoft
UX Guide → honest KDE adaptation. Generic UX rules do not override the actual
Windows taskbar or authorize Fluent/cards/ribbon styling.

| Area | Implementation and checked evidence | Still unverified |
| --- | --- | --- |
| Button targeting/alignment | Task production geometry bindings and TaskList count logic exercised at 140/240/320/800 logical widths. 60+2 regular / 44+2 small pitch retained; zero-startup role transition and launcher/labeled allocation tested. Template script executed at 800/1024/1200/3840 widths: full edge, 40 high. | Real panel containment margins, overflow surfaces, vertical/reverse/RTL and touch/stylus. |
| Primary activation | One nested TapHandler; real input events test single dispatch, active minimize, outside release and drag cancellation. Policy tests minimized restore/activation and group fallback. | Full shell task-model side effects and double-click semantics. |
| Group selection | First click pins/preserves, second dismisses; disabled previews/unavailable Window View force actionable list. Real row/close input tests ensure close does not activate a sibling. | Actual native QModelIndex window selection, compositor popup anchoring/outside dismissal. |
| Hover redundancy/lifetime | Signal-backed owner-local popup visibility; Peek cancels on hide, Escape, selection, retarget/destruction. Stale owners/global mirrors cannot cancel current owner. Initial 800ms timer tested. | Live KWin reveal, Wayland streams, exact Windows Aero delay. |
| Keyboard and focus | Explicit keyboard-open requests first-row focus after asynchronous creation; hover does not request it. Rows support activation, close, Escape, arrows/scroll into view. Media supports Return/Enter/Space, accessible names and existing hover SVG focus feedback. | Screen-reader certification, live popup focus acceptance, full Tab path, high contrast. |
| Contextual media toolbar | Existing compact toolbar and real Previous/Play/Pause/Next/Mute operations retained, capability gating preserved. Component tests mock service functions but click/key paths execute production controls without activating/dismissing window. | Real player capability changes and per-window identity. |
| Status and progress | Useful native progress remains. Numeric notification badges are explicitly opt-in, default false; audio mute extension remains off by default. | Live service overlays, accessibility of all upstream status surfaces. |
| Screen space / DPI | Isolated Qt6 tests at actual Screen DPR 1/1.25/1.5; bounded list at 140×160 and 320-wide work areas; 30-window scrolling/last-row close. Review captures use production components with controlled backing. | Real 800×600/1024×768/1200×900 compositor session, theme borders/shadows, multilingual/fonts. |
| Safe integration | Separate native plugin + QML identity; no global install, no native behavior/ABI edit. Private HOME/XDG/D-Bus; no standard D-Bus activation directories. Stage/install are explicit, parallel and backed up. | Normal Plasma discovery/loading of a user-prefix plugin. Dedicated viewer unavailable on checked host. |

Sources: [Taskbar](https://learn.microsoft.com/en-us/windows/win32/uxguide/winenv-taskbar),
[Mouse](https://learn.microsoft.com/en-us/windows/win32/uxguide/inter-mouse),
[Keyboard](https://learn.microsoft.com/en-us/windows/win32/uxguide/inter-keyboard),
[Tooltips](https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-tooltips-and-infotips),
[Menus](https://learn.microsoft.com/en-us/windows/win32/uxguide/cmd-menus),
[UX checklist](https://learn.microsoft.com/en-us/windows/win32/uxguide/top-violations).

This is a first-pass checked source/component checklist, not Windows parity or
accessibility certification. [Exact reproduction](taskbar-fidelity.md).
