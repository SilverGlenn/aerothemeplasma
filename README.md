# AeroThemePlasma: Windows 7 Fidelity

An independent fork of [AeroThemePlasma](https://github.com/aeroshell-desktop/aerothemeplasma),
maintained by [SilverGlenn](https://github.com/SilverGlenn), focused on bringing
Windows 7's taskbar behavior and Aero styling to KDE Plasma 6.

The original desktop theme, artwork, widgets, and native components come from
**WackyIdeas and the AeroShell contributors**. This fork builds on their work
with taskbar, system-tray, volume, power, and desktop-overview changes. Development
takes place on the [`windows7-fidelity`](https://github.com/SilverGlenn/aerothemeplasma/tree/windows7-fidelity)
branch.

## What this version changes

- **SevenTasks:** corrected button geometry and activation, compact grouped-window
  previews, bounded scrolling, keyboard access, and more predictable Peek behavior.
  The panel template uses a full-width, non-floating Windows 7-style layout.
- **System tray:** drag icons between the panel and hidden-icon drawer, reorder
  either view, and retain placement across restarts. Dragging works between the
  separate panel and drawer windows; the drawer grows as a square grid.
- **Volume controls:** keep slider positions stable during asynchronous or stale
  audio-device updates, synchronize mute state through fresh PulseAudio reads,
  and handle KDE playback-volume shortcuts.
- **Power flyout:** Windows 7-style battery status, power-plan labels and radio
  buttons, plus links to screen brightness and power options.
- **Desktop Number:** a tray-sized current-desktop number in Segoe UI Bold.
  Clicking it opens KWin's existing Overview.
- **Aero Overview:** Aero-style command buttons and search controls around KWin's
  existing desktop and window previews.
- **Preview tools:** a standalone taskbar window and a separate temporary panel
  preview with an exit control and recovery support.

The fidelity work follows observed Windows 7 behavior, then the Windows 7-era
UX Guide, while retaining useful KDE functions. Desktop Number and Overview are
Aero-style adaptations for Linux workspaces. The implementation and evidence
are documented in the [taskbar reference](docs/windows7-taskbar-reference.md)
and [UX checklist](docs/taskbar-uxguide-checklist.md).

## Getting started

Clone this fork's development branch:

```bash
git clone --branch windows7-fidelity https://github.com/SilverGlenn/aerothemeplasma.git aerothemeplasma-win7
cd aerothemeplasma-win7
```

### Try the taskbar in a separate window

From a terminal in an existing KDE Plasma desktop session:

```bash
./scripts/try-taskbar-preview.sh
```

The launcher builds and stages a separate SevenTasks package, then opens it with
the installed `plasmawindowed` host. It keeps preview settings separate and leaves
the existing panel in place. Its buttons operate on real desktop windows,
including activation, minimize, and close. Close the preview window to stop it.

Build and stage without opening a window with `--prepare-only`. See the
[preview and validation guide](docs/taskbar-fidelity.md) for dependencies,
headless checks, staging, and the separate temporary real-panel preview workflow.

### Add Desktop Number

Install and enable just the desktop-number widget in the current tray:

```bash
./scripts/install-desktop-number.sh --enable
```

It is also listed as **Desktop Number** in System Tray Settings after
installation. Segoe UI Bold must be supplied separately; Qt uses a fallback
when it is unavailable. See [setup, removal, and tests](docs/desktop-number.md).

### Apply the Aero Overview skin

The overview extension currently requires **KWin 6.6.6** and matching development
headers. It checks the build-time and running versions before applying the skin.

```bash
cd plasma/effects/aero-overview
./install.sh
```

Run `./uninstall.sh` from the same directory to restore the stock Overview.
See the [overview guide](plasma/effects/aero-overview/README.md) for requirements,
scope, and validation.

The volume, power, and system-tray changes are included in their widget sources;
they do not yet have a dedicated installation helper. The retained
[upstream installation guide](INSTALL.md) describes the full AeroThemePlasma
setup. Use the component-specific paths above for this fork's additions and the
dedicated staging tools for previews.

## Compatibility and validation

The fork's recorded validation environment is **x86_64, Plasma/KWin 6.6.6,
KDE Frameworks 6.24, and Qt 6.10.2**. This is the environment used for the fork's
checks, rather than a guarantee for every Plasma 6 release. The Overview native
extension is explicitly pinned to KWin 6.6.6 and needs review and rebuilding for
another release.

Taskbar component tests cover 100%, 125%, and 150% scaling. Desktop-number,
volume, power, and overview controls have QML regressions; the tray tests exercise
native cross-window drags and persisted configuration. Tray placement has also
been checked in a live Wayland session across a Plasma restart.

The recorded Windows reference uses Basic graphics. Exact Aero Glass,
live-thumbnail, shadow, and Peek parity remains unverified, and a windowed
taskbar preview does not validate every full-panel interaction. See the
[validation guide](docs/taskbar-fidelity.md) and
[tray regression notes](tests/systemtray/README.md) for the tested scope and
remaining checks.

## Development

Development for this version takes place in
[SilverGlenn/aerothemeplasma](https://github.com/SilverGlenn/aerothemeplasma).
When describing a fork-specific problem, include reproduction steps,
Plasma/Qt/KWin versions, session type, scaling, and relevant logs.

The original [contribution policy](CONTRIBUTING.md),
[translation guide](TRANSLATING.md), and [technical documentation](DOCUMENTATION.md)
are retained. The contribution policy governs submissions to the upstream
AeroShell project; this fork is maintained separately.

## Upstream credit and acknowledgments

**AeroThemePlasma was created by [WackyIdeas](https://gitgud.io/wackyideas) and
developed with the AeroShell community.** Their work provides the foundation of
this fork. The original [GitGud project](https://gitgud.io/aeroshell/atp/aerothemeplasma),
[GitHub mirror](https://github.com/aeroshell-desktop/aerothemeplasma), and
[AeroShell components](https://github.com/aeroshell-desktop/) remain credited.
You can support the original project's author through
[Ko-fi](https://ko-fi.com/M4M2NJ9PJ).

The acknowledgments below preserve the original project's contributor and
related-project mentions. KDE contributors are also credited for Plasma, KWin,
Kirigami, and the original Overview implementation; their source notices remain
in the relevant files.

### Code and themes used by upstream

- Intika's [Digital Clock Lite](https://store.kde.org/p/1225135/) plasmoid.
- [Adhe](https://store.kde.org/p/1386465/), [oKcerG](https://github.com/oKcerG/QuickBehaviors),
  and [SnoutBug](https://store.kde.org/p/1720532) for making SevenStart possible.
- Zren's [Win7 Show Desktop](https://store.kde.org/p/2151247) plasmoid.
- [Mirko Gennari](https://store.kde.org/p/998614), DrGordBord, and
  [bionegative](https://www.pling.com/p/998823) for making SevenBlack possible.
- DrGordBord's [Windows 7 Kvantum](https://store.kde.org/p/1679903) theme.
- [taj-ny](https://github.com/taj-ny)'s
  [kwin-effects-forceblur](https://github.com/taj-ny/kwin-effects-forceblur).

### Upstream contributors

- [Souris-2d07](https://gitgud.io/souris): cursor theme, original Plymouth theme,
  SDDM theme, KWin decoration theme, most KWin C++ effects, and other KWin features
  and scripts.
- [That Linux Dude Dominic Hayes](https://github.com/dominichayesferen): lock
  screen UI and icon theme.
- [catpswin56](https://gitgud.io/catpswin56/): SevenTasks, Sound Mixer, Gadgets
  menu, Polkit UAC skin, and many other contributions.
- [QuinceTart10](https://github.com/QuinceTart10) and
  [Gamer95875](https://github.com/Gamer95875): sound themes.
- [kfh83](https://github.com/kfh83),
  [TorutheRedFox](https://github.com/TorutheRedFox), and
  [ALTaleX](https://github.com/ALTaleX531/dwm_colorization_calculator/blob/main/main.py):
  collaboration on accurate Aero glass blur and colorization.
- [AngelBruni](https://github.com/angelbruni): SVG textures, especially the
  DigitalClockLite Seven clock.
- [ricewind012](https://github.com/ricewind012/): the .bashrc Microsoft Windows header.
- [furkrn](https://gitgud.io/furkrn): creation and maintenance of the
  [Plymouth theme](https://github.com/furkrn/PlymouthVista).
- [IcyGuidance](https://gitgud.io/IcyGuidance): SevenTasks notification badges.

Special thanks to [MondySpartan](https://www.deviantart.com/mondyspartan/art/Windows-10-Year-2010-Edition-1016859431)
for inspiring the notification design, and to everyone who contributed, tested,
or provided suggestions to the original project.

### Related projects acknowledged by upstream

- [Geckium](https://github.com/angelbruni/Geckium) by AngelBruni.
- [Aero UserChrome](https://gitgud.io/souris/aero-userchrome) by Souris.
- [VistaThemePlasma](https://gitgud.io/aeroshell/vtp/vistathemeplasma/),
  [LonghornThemePlasma](https://gitgud.io/catpswin56/longhornthemeplasma),
  [VB1ThemePlasma](https://gitgud.io/catpswin56/vista-beta-plasma),
  [Harmony](https://gitgud.io/catpswin56/harmony),
  [SMOD Themes](https://gitgud.io/catpswin56/smod-themes), and
  [X6Shell](https://gitgud.io/x6shell) by catpswin56.
- [Ice2K.sys](https://toiletflusher.neocities.org/ice2k/) by 0penrc.
- [AeroThemePlasma-Nix](https://github.com/nyakase/aerothemeplasma-nix/) by
  [nyakase](https://github.com/nyakase).
- [Linux Explorer](https://github.com/actuallyaridan/linux-explorer),
  [Control Panel](https://github.com/actuallyaridan/linux-control),
  [Device Manager](https://github.com/actuallyaridan/linux-devmgmt), and
  [Windows 7 Minesweeper](https://github.com/actuallyaridan/linux-minesweeper)
  by ActuallyAridan.
- [TuxManager](https://github.com/benapetr/TuxManager) by benapetr.
- [Gadgets](https://gitgud.io/catpswin56/win-gadgets) and
  [execbin](https://gitgud.io/catpswin56/execbin) by catpswin56.
- [LinVer](https://gitgud.io/wackyideas/linver) by WackyIdeas.
- [Aero Dolphin](https://gitgud.io/atmk/dolphin-aero),
  [Aero GwenView](https://gitgud.io/atmk/gwenview-aero),
  [Aero KolourPaint](https://invent.kde.org/albert-tomanek/kolourpaint/-/tree/saribbon-aero),
  [Aero App Store](https://gitgud.io/atmk/app-store/-/tree/flatpak?ref_type=heads),
  and [libAeroQt](https://gitgud.io/atmk/libaero-qt) by Albert Tomanek.
- [SARibbon](https://github.com/czyt1988/SARibbon), the ribbon-control library
  styled by libAeroQt.

## License and trademarks

See [LICENSE](LICENSE) for the repository's GNU Affero General Public License
version 3. Individual components retain their own license and copyright notices,
including the GPL-2.0-or-later KWin Overview sources.

Microsoft® Windows™ is a registered trademark of Microsoft Corporation.
Microsoft retains ownership of its Windows resources. Windows names are used
for reference to the visual style; this project is independent of Microsoft.
