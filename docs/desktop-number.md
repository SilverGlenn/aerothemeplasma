# Desktop Number tray widget

A minimal native Plasma 6 applet: only the current desktop number, set in
**Segoe UI Bold**, centered in the tray's normal icon slot. There is no badge,
background frame, pager grid, or scrolling behavior. **Left-click opens the
existing Aero Overview**; keyboard activation from the tray does the same.
Right-click still opens the normal tray/widget context menu.

At the current 40-logical-pixel taskbar height, the tray provides a 16-pixel-wide
icon slot. The number uses a 17-logical-pixel font there, not a 40-pixel font.
This is a one-pixel increase over the initial font size, without resizing the slot.
Native text rendering and full hinting keep the Segoe UI Bold shape crisp. A
one-logical-pixel dark keyline (`#20252b`) replaces the earlier one-sided text shadow,
matching the white-filled, outlined Windows 7-style tray artwork without adding
a badge or glow. Text color follows the Plasma theme (white with Seven Black).
A one-pixel inset on each side leaves room for the keyline when fitting multiple
digits. Qt handles high-DPI scaling. Larger icon slots can scale the text up to
32 logical pixels; narrow slots fit multi-digit numbers without clipping.

## Install and add

From the repository root:

```sh
./scripts/install-desktop-number.sh --enable
```

This installs **only this applet** under
`~/.local/share/plasma/plasmoids/io.gitgud.wackyideas.desktopnumber/` and enables
it in the existing Aero or stock Plasma system tray. It preserves unrelated tray
entries and explicitly keeps the number visible. No sudo, shell restart, or
compositor modification is required for the initial installation.

When updating an already-loaded applet, Plasma can retain old QML components in
memory even after a successful package upgrade. If a visual change does not
appear, restart just the Plasma shell to clear that cache:

```sh
systemctl --user restart plasma-plasmashell.service
```

The taskbar briefly disappears; running application windows remain open. The
number's label is offset upward by 1 logical pixel. Compared with the earlier
16px font / -2px offset, the 17px font / -1px offset keeps the rendered top edge
in place and extends the base one pixel downward. Segoe UI Bold was checked at
actual size for all five digits; the outlined glyph height increases from 13 to
14 pixels at 100% scaling, while the tray slot remains unchanged.

To install it without changing the current tray:

```sh
./scripts/install-desktop-number.sh
```

Then open **System Tray Settings → Entries**, enable **Desktop Number**, and set
it to **Always shown** if desired. It can also be added as a normal panel widget.
The package is included in `plasma/plasmoids/CMakeLists.txt` for normal theme
package installs; do not run the root installer just to add this widget.

To hide/disable it without uninstalling:

```sh
./scripts/install-desktop-number.sh --disable
```

To remove the installed applet:

```sh
kpackagetool6 --type Plasma/Applet --remove io.gitgud.wackyideas.desktopnumber
```

## Desktop state

The applet uses `org.kde.taskmanager.VirtualDesktopInfo`, the same native desktop
information API as SevenTasks. It reacts to desktop changes and changes to the
ordered desktop IDs. There are no D-Bus polling timers, shell commands, native
helper libraries, or background processes.

Activation uses Plasma's built-in asynchronous D-Bus QML API to invoke KWin's
existing `Overview` action in its `default` shortcut context. It does not launch a
shell command, load/unload effects, or create another overview. The tray's
existing activation forwarding is used, so a click invokes the action once and
the number's appearance, sizing, and pixel alignment remain unchanged.

On Wayland the current desktop is a UUID, not a number. The label resolves that
UUID's one-based position in the ordered list. This also handles X11 numeric IDs,
desktop reordering, and desktop removal. Desktops 1–5 show exactly `1`–`5`.
If more desktops are later added, their real number is displayed rather than
silently clamped to 5. During backend initialization, no incorrect fallback
number is shown. The tooltip and accessible text identify the current desktop.

Segoe UI Bold is installed on this machine. The font is not redistributed;
other installations need their own licensed copy or Qt will use a fallback.

## Validation

```sh
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner \
    -input tests/desktop-number -o -,txt
```

Tests cover all five live-bound values, Wayland UUIDs, numeric X11 IDs,
reordering/removal, an uninitialized backend, multi-digit fitting, the exact
font/weight, the outlined (not shadowed) glyph style, the corrected baseline,
a number-only visual tree, and tray versus panel sizing. Action tests verify
one correctly typed D-Bus call per activation, its explicit shortcut context,
no activation on load, and graceful D-Bus error reporting. The
installed applet has also been checked in the actual Aero tray against the
current KWin desktop, with no applet QML runtime errors.
