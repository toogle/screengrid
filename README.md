# ScreenGrid

Keyboard-driven mouse clicking for macOS. Tap the left ⌘ key, type three letters, and
ScreenGrid clicks anywhere on screen — your hands never leave the keyboard. Right clicks,
double clicks, cursor nudging, and scrolling included.

## Install

1. Download the latest `ScreenGrid-x.y.z.dmg` from [Releases](../../releases), open it,
   and drag **ScreenGrid** into **Applications**.
2. Launch it. ScreenGrid lives in the menu bar — no Dock icon, no main window.
3. Grant the two permissions it asks for: **Accessibility** and **Input Monitoring**
   (System Settings → Privacy & Security). ScreenGrid enables itself the moment both are
   granted — no restart needed.

Requires macOS 26 (Tahoe) or later; the binary is universal (Apple silicon and Intel).

> Release builds are currently ad-hoc signed, not notarized, so Gatekeeper will warn on
> first launch. Right-click the app and choose **Open**, or approve it under
> System Settings → Privacy & Security → **Open Anyway**.

## Usage

### Summon the grid

**Tap the left ⌘ key** — a quick press and release (under 200 ms) with nothing else in
between. The grid overlay appears over the screen your pointer is on, including over
full-screen apps.

Only a clean tap triggers it: holding ⌘, using any shortcut (⌘C, ⌘Tab, …), or combining
it with other modifiers never shows the overlay and never interferes with the shortcut.
The right ⌘ key is ignored entirely.

### Click in three keystrokes

1. The screen is divided into a 10 × 30 grid; every rectangle shows a **two-letter code**.
   The first letter is the column (home row, `A` leftmost … `;` rightmost), the second is
   the row (`Q` top … `/` bottom). Type the code — after the first letter everything but
   that column dims.
2. The chosen cell zooms into a fine grid that mirrors your keyboard's three letter rows
   (`QWERTYUIOP` / `ASDFGHJKL;` / `ZXCVBNM,./`). **Press the key sitting over your
   target** — ScreenGrid clicks the center of that sub-region and dismisses.

For example, `G` `K` `T` clicks a spot just left of screen center. Not fussy about
precision? After the two cell letters, **Space** clicks the cell center — "close enough,
click here."

### More than a left click

- **Right click** — hold **⌃ (Control)** with any click-producing key. The synthesized
  click carries no modifier flags, so context menus open exactly as with a physical
  secondary click.
- **Double / triple click** — press the same key again within your system's double-click
  interval. The first click always fires immediately; repeats upgrade it to a true double,
  then triple click.
- **Nudge mode** — once a cell is chosen, press any **arrow key**: the grid hides and the
  arrows steer the pointer directly, 10 pt per press — or a fine 1 pt with ⇧ held, for
  pixel-precise placement that stays fine through direction changes. Holding arrows
  glides the pointer smoothly from the moment you hold — no auto-repeat delay — easing
  in to your key-repeat pace; hold a vertical and a horizontal arrow together to glide
  **diagonally** at the same speed, and switch directions mid-glide without the pointer
  ever pausing or changing pace. **Space** or **Return** clicks at the pointer, which stays
  on the grid's screen — motion stops at the edges rather than roaming onto another display.
  Press **`,`** or **`.`** to drop straight into scroll mode at the cursor; any other key
  dismisses.
- **Free mode** — press an **arrow key** right after summoning the grid, before any
  letter, to skip cell selection entirely: the pointer moves from wherever it already
  is, with exactly the same controls as nudge mode.
- **Scroll mode** — right after summoning the grid, press **`,`** to scroll down or
  **`.`** to scroll up, applied to whatever is under the pointer. Hold the key to scroll
  continuously — the glide eases in immediately, with no pause after the first hop. Press
  an **arrow key** to switch to free mode at the cursor — scroll mode and pointer nudging
  are interchangeable, so you can steer and scroll to the same spot without leaving the
  overlay.

### Dismiss and step back

- **Escape**, another **left-⌘ tap**, or any physical mouse click or scroll dismisses the
  overlay without clicking.
- **Backspace** steps back one stage instead — fine grid back to row choice, row choice
  back to the full grid. (In nudge, free, and scroll modes any key outside the mode's own
  controls dismisses, Backspace included.)

While the overlay is up, every keystroke is consumed — nothing leaks into the app you're
working in, and it keeps keyboard focus the whole time. Keys are matched by physical
position, so every keyboard layout works; the labels show the US-QWERTY positions.

### Cheat sheet

| Keys | Action |
|---|---|
| left ⌘ tap | show / dismiss the grid |
| two letters (column + row) | choose a cell |
| third letter | click that sub-region |
| Space | click the cell center |
| ⌃ + any click key | right click |
| same key again | double, then triple click |
| arrows (after cell choice) | nudge pointer 10 pt (⇧: fine 1 pt), Space/Return clicks |
| arrows (before any letter) | the same, from wherever the pointer is |
| vertical + horizontal arrows held | glide diagonally, same speed |
| `,` / `.` (before any letter) | scroll down / up |
| `,` / `.` while nudging, or arrows while scrolling | switch between scroll and pointer modes, at the cursor |
| Backspace | step back one stage |
| Escape | dismiss |

## Settings

Open **Settings…** from the menu bar icon (or ⌘, while the menu is open):

- **Launch at login.**
- **Appearance** — letter tiles on/off, letter brightness, tile border brightness,
  grid-line brightness and width, and the dark under-stroke that keeps grid lines visible
  on white backgrounds. Changes apply live — summon the overlay while dragging a slider to
  preview — and persist across launches.

ScreenGrid is always active while running; quit it from the menu bar icon to stop it.

## The menu bar icon

The icon doubles as a health indicator:

- **Grid symbol** — running normally.
- **Warning triangle** — a permission is missing or was revoked; the menu gains a
  **Permissions Required…** item that reopens the setup popover.
- **Dimmed** — a password field has secure input active, which pauses all keyboard
  monitoring system-wide. ScreenGrid resumes by itself as soon as the field loses focus.

## Accessibility

The overlay is drawn with solid dimmed fills — no blur or translucency — so it stays
legible over any wallpaper and is unaffected by the Reduce Transparency setting.
**Reduce Motion** replaces the stage-change springs with plain crossfades.

## Building from source

```sh
swift build          # requires the macOS 26 SDK (Xcode 26 or matching CLT)
swift test           # needs full Xcode — the Command Line Tools don't ship swift-testing
swift run ScreenGrid # runs as a bare menu bar executable
```

A source build needs the same two permissions as the app. App Sandbox is off by design —
event taps and HID-level event posting are incompatible with sandboxing — so distribution
is Developer ID + notarization rather than the Mac App Store. CI builds the DMG and runs
the test suite on every push and pull request.

## Acknowledgements & license

ScreenGrid was inspired by [Mouseless](https://mouseless.click/) — a polished, commercial
take on keyboard-driven mouse control that is well worth a look.

ScreenGrid is released under the [MIT License](LICENSE).
