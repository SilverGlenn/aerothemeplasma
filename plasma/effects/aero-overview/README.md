# Aero desktop overview

A user-local Windows 7-style skin for **KWin 6.6.6's existing Overview**. It does
not replace KWin, change window management, or modify system theme files.

## Design

- A pale blue Aero command strip separates commands from live previews.
- **New desktop** is a normal-height, text-labeled command button, not another
  desktop-sized tile with a giant green plus. No ellipsis: creation is immediate.
- Supplemental search is at the upper right. Its white edit surface, inset
  border, 16 px magnifying glass, and clear affordance follow Explorer-era search.
  The magnifying glass is not clickable because results update while typing.
- The cue **Search windows and apps** describes the existing window-filter plus
  KRunner behavior instead of implying a generic file-only search.
- The search has a screen-reader name and search-edit role. Ctrl+E follows the
  Windows guide; Ctrl+F is retained for KDE users. Refocusing selects the query.
- Buttons distinguish normal, hover, pressed, disabled, and keyboard-focus states.
  New desktop retains mouse, Enter, Space, and window-drop activation. Delete/F2
  and the original window/desktop navigation remain in the upstream QML.
- Desktop removal remains a small contextual control, with an accessible name;
  it is also revealed when its desktop has keyboard focus.
- The upstream vertical desktop rail can now actually scroll vertically.

### Where literal Windows 7 imitation would be inappropriate

Windows 7 had no native workspace overview. This is an **Aero-consistent
adaptation**, not a claim of historical authenticity. Keep the live desktop rail,
window previews, gesture transitions, dragging, and instant search: they are
useful direct manipulation, not clutter to remove for period accuracy. Do not
wrap the full-screen workspace switcher in a fake Explorer window, add a ribbon,
or add dialog-style OK/Cancel/Apply buttons. Switching is immediate, and Escape
already leaves the view.

Search is supplemental here, so it is at the upper right. If this becomes mainly
an application launcher rather than a desktop/window picker, a centered primary
search field would be the better alternative. Existing KRunner ranking, matching,
and result behavior are deliberately preserved rather than changed to imitate
the old Windows search backend.

The palette targets this installation's light Aero theme, not a universal
high-contrast or dark theme. Native KWin motion and preview rendering remain
unchanged.

References:

- https://learn.microsoft.com/en-us/windows/win32/uxguide/how-to-design-desktop-ux
- https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-buttons
- https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-search-boxes

## Implementation and scope

KWin embeds Overview's QML in its executable; a file in the theme directory
cannot override it. A small local QML extension points the loaded built-in
Overview at these QML files using its existing `QuickSceneEffect::setSource`
API. The native helper does not implement its own effect or input handling.

`upstream/` contains the exact GPL-2.0-or-later KDE KWin v6.6.6 QML originals;
`contents/ui/` contains the adapted view, two small controls, and original SVG
search/clear glyphs. KDE copyright notices are retained.

The helper only changes an idle Overview, compiles the view before changing its
source, and leaves stock Overview alone on QML compilation failure. It checks
both the build-time and running KWin version and will refuse to apply after a
KWin upgrade until reviewed and rebuilt against that release. KWin's C++ API is
not ABI-stable; do not bypass this version check.

## Install / restore

Requires the matching `kwin-dev`, Qt6 development tools, CMake, and Ninja (already
available on this machine). From this directory:

```sh
./install.sh
```

Files are installed under `~/.local/share/kwin/scripts/aerooverview/`. The only
configuration entry added is `[Plugins] aerooverviewEnabled=true` in `kwinrc`.
The script applies immediately and is rediscovered at subsequent logins. No
sudo, compositor replacement, logout, or global theme changes are needed.

To disable and immediately restore the stock overview:

```sh
./uninstall.sh
```

The disabled local files are retained so they can be inspected or re-enabled.
The separate `desktopchangeosdEnabled=false` preference is not touched.

## Validation

```sh
cmake -S . -B build -G Ninja
cmake --build build
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests -o -,txt
```

Tests cover control sizing/cues, mouse activation, Enter/Space activation,
disabled controls, instant text changes, clear/refocus behavior, select-all on
focus, both search shortcuts, and read-only state. Also tested using the live
KWin Overview and a Spectacle capture, with no view QML runtime errors.

For live preview, this machine's global accelerator requires the explicit
`default` context:

```sh
qdbus6 org.kde.KWin /component/kwin \
  org.kde.kglobalaccel.Component.invokeShortcut Overview default
```

This is the user's existing Meta+Tab action. `/Effects.toggleEffect` toggles
whether an effect is *loaded* and must not be used to open the overview.
