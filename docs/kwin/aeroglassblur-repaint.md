# AeroGlassBlur repaint compatibility

## Symptom and diagnosis

Moving ChatGPT (an XWayland window) behind the taskbar or an always-on-top Aero
window produces transient trails inside the glass. The trails disappear when
movement stops. The same drag behind KDE's standard Blur does not exhibit them.
AeroGlassBlur remains a requirement; standard Blur was a diagnostic comparison,
not a replacement.

On KWin 6.6, `WorkspaceScene::collectDamage()` collects damage through scene
items after `prePaintWindow()`. The older blur implementation's updates to
`WindowPrePaintData::devicePaint` do not register this background dependency.
KDE Blur instead owns a `BackgroundEffectItem` for each blurred window. It tells
the scene the blur bounds and how far the blur kernel needs repainting below
opaque regions.

`patches/aeroshell-kwin-components/0001-register-background-damage.patch` ports
that registration into the Wayland AeroGlassBlur implementation. It:

- owns one background-effect scene item in each window's blur data;
- updates its window-local bounds and kernel expansion when blur regions,
  geometry or configuration change;
- releases it with the window's data, including exclusions and effect unload;
- removes obsolete manual damage bookkeeping, retaining Firefox translucency
  handling and the effect-chain forwarding.

The Aero shaders, colourization, reflections, kernel parameters, and glass
artwork are unchanged. The X11 companion implementation is not patched.

References: KWin's matching [Blur implementation](https://invent.kde.org/plasma/kwin/-/blob/Plasma/6.6/src/plugins/blur/blur.cpp),
[damage collection](https://invent.kde.org/plasma/kwin/-/blob/Plasma/6.6/src/scene/workspacescene.cpp),
and [BackgroundEffectItem](https://invent.kde.org/plasma/kwin/-/blob/Plasma/6.6/src/scene/backgroundeffectitem.h).

## Apply and build only this effect

Use companion sources compatible with the **installed KWin version**, not the
latest branch fetched by the full project installer. KWin plugins have an exact
versioned factory interface. The full installer applies the patch before its
KWin build, but it is not the right tool for updating only this effect.

```sh
# Set these to your checkouts.
theme=/path/to/aerothemeplasma-win7
companion=/path/to/aeroshell-kwin-components

bash "$theme/scripts/apply-aeroglassblur-patch.sh" "$companion"
cmake -S "$companion" -B "$companion/build-repaint" -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/usr -DKWIN_BUILD_WAYLAND=ON -DBUILD_TESTING=OFF
cmake --build "$companion/build-repaint" --target aeroglassblur -j2
bash "$theme/tests/aeroglassblur/run.sh" "$companion"
```

The helper applies only `blur.cpp` and `blur.h`. Repeating it is harmless. It
refuses an incompatible or partially patched source tree without changing files;
it never resets or checks out a Git revision. When upstream adopts an equivalent
fix in a different form, review and retire/rebase this patch rather than forcing
it to apply.

The initial local build used KWin 6.6.6 / Qt 6.10.2 and companion commit
`97cc934`. Its existing local CMake adjustment from WaylandProtocols 1.48 to the
installed 1.47 was carried into the isolated companion worktree separately; it
is **not** part of the blur patch.

## What the tests prove

`test_scene_registration.py` compiles the actual companion `updateBlurRegion()`,
`blurRegion()`, decoration-region helpers, and blur data declaration, with real
Qt geometry and small doubles at the compositor/window/protocol boundaries.
It tests registration for content and decoration glass, geometry/strength
updates, exclusions, per-window ownership, cleanup, empty protocol regions,
forced blur and internal windows. It failed before the patch with a missing
background-effect registration and passes after it.

`test_patch_application.py` runs the actual helper in disposable repositories:
fresh and repeated application, paths with spaces, unrelated local changes,
incompatible/partially patched sources, and repository-root validation.

These tests do **not** simulate GPU rendering or prove the visual artifact is
fixed. A separate private-bus virtual KWin smoke test loaded the rebuilt binary
from an isolated plugin directory and successfully unloaded/reloaded the effect.
No live desktop configuration or installed plugin was changed for those tests.
The user's physical-display reproduction remains the final acceptance check.

## Deployment and rollback

**A same-path replacement normally takes effect after logout/login.** KWin
creates the factory with `QPluginLoader`, whose default load hints retain the
library. Merely toggling the effect can re-create the old code after replacing
the file. Do not restart/replace KWin inside a Wayland session: that can terminate
applications.

A no-logout alternative was subsequently tested in a private virtual compositor
and applied to this session: install the identical patched binary at a new,
root-owned canonical path outside plugin discovery, then atomically replace the
normal `plugins/aeroglassblur.so` entry with a symlink to that binary. Keep the
basename `aeroglassblur.so` so the effect ID and configuration stay unchanged.
Unload AeroGlassBlur, allow its 1000ms Wayland blur-manager teardown timer to
finish, then load the same effect ID. Qt resolves the new canonical path and
loads the new library rather than its cached old copy. This build uses hidden
C++ symbol visibility; that was checked before testing two library versions in
one process. Do not generalize this procedure to arbitrary plugins.

The active target on this machine is
`/usr/lib/x86_64-linux-gnu/qt6/plugins/kwin/effects/.aeroglassblur-repaint-e2dae7cbc6c6/aeroglassblur.so`.
The current KWin process kept PID 1880, and its executable memory mapping to this
new target was verified. No alias effect ID, configuration change, compositor
restart, taskbar restart or application restart was needed. The standard entry
continues to load the patched target after future logins. The atomic rollback
commands below replace the symlink itself with the original regular file.

On this machine the plugin path is
`/usr/lib/x86_64-linux-gnu/qt6/plugins/kwin/effects/plugins/aeroglassblur.so`.
Check your distribution's path before using these commands. Backups must stay
**outside** the plugin-discovery directory.

```sh
plugin=/usr/lib/x86_64-linux-gnu/qt6/plugins/kwin/effects/plugins/aeroglassblur.so
built="$companion/build-repaint/bin/aeroglassblur.so"
backup="$HOME/.local/state/aeroglassblur-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
cp --preserve=timestamps -- "$plugin" "$backup/aeroglassblur.so"
sha256sum "$plugin" "$built" > "$backup/checksums-before.txt"

# Install to another inode, then rename atomically on the same filesystem.
# Never copy over/truncate the mapped shared library in place.
sudo install -m 0755 -- "$built" "$plugin.repaint-new"
sudo mv -T -- "$plugin.repaint-new" "$plugin"
cmp -- "$built" "$plugin"
printf 'Rollback copy: %s\n' "$backup/aeroglassblur.so"
```

Then log out and back in when convenient. Leave AeroGlassBlur enabled and KDE
Blur disabled. Drag ChatGPT behind both the taskbar and an always-on-top Aero
frame, in both directions and at different speeds. Also check normal Aero
windows, resizing, menus, accent colour/reflections and idle behaviour.

If necessary, restore the exact backup using the same atomic technique, then
log out/in again:

```sh
sudo install -m 0755 -- "$backup/aeroglassblur.so" "$plugin.rollback-new"
sudo mv -T -- "$plugin.rollback-new" "$plugin"
```

Status: source regression and build verified. The patched binary was installed
atomically with administrator approval on 2026-10-19; its SHA256 is
`e2dae7cbc6c67413752116c895c5350d41045e36847897254d4a9d751c620e65`.
The original is backed up under
`~/.local/state/aeroglassblur-backups/20261019-092315/aeroglassblur.so`.
The patched binary was subsequently hot-loaded through the verified canonical-
path procedure above. The user then confirmed that the fix worked in the live
session. The original trail reproduction is resolved without logout or a
compositor restart. Broader manual menu/resize/accent checks were not individually
reported.
