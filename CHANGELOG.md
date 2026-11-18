# Changelog

## 1.5.1

- Supply a lightweight textured surface, fonts, item outline, countdown fill, and icon tints for the optional Sintezza Loot roll popup skin.
- Draw smaller roll symbols within the original Blizzard button hit areas.

## 1.5.0

- Make shared slider synchronization reentrant, read back accepted values and recover after setter errors; refresh reused help triggers after caption changes. Window-option consumers can select their label role and inset.
- Fix conflicting segmented-tab anchors that could collapse tabs after resizing; refresh tabs and numeric slider values when shown.
- Add an optional cursor anchor to shared tooltips, with UI-scale handling, edge flipping and movement tracking only while visible.
- Add optional Sintezza Perf counters for CSV imports and exports.
- Short help tooltips now fit their text within bounded widths, and an empty title no longer adds blank header lines.
- Open Theme settings once per account after login, deferring until combat ends when needed. Manual opening also completes the introduction.
- Added shared surface, progress, data-mark and tooltip providers for optional consumers such as Sintezza Perf; they reuse palette refresh and existing window/help behavior without idle polling.
- Shared color controls use the Sintezza color picker with live preview, Hex, opacity, favorites and recent colors.

## 1.4.0

- Choose one of five button styles for all connected Sintezza addons. Clipped Corners is the default.
- Theme settings open in their own window. The three added scratches were removed from the shared slate texture.
- The settings window uses the standard compact header and a single-page layout with two columns.
- Unified the styling of settings sections and thin dividers across connected add-ons.
- Fixed long settings help text being clipped in tooltips.
- Diagnostics and window options use the same unframed section heading.
- Window and minimap settings sit directly on the tab background. Embedded sections use a heading with a thin rule.
- Fixed windows jumping to their maximum size while dragging the resize handle.
- Background tint and texture sliders update only their own background layers.
- Add-on minimap buttons share a left-click window toggle.
- Added Graphite, separate background tint and texture controls, and confirmed bulk changes to window scale, opacity and layer. Shared the settings launcher and list disclosure arrow.
- Updated the project logo and shared in-game icons for Theme, UI, Disenchant, Loot, and Rivals.

## 1.3.17

- Added a shared pair of high-resolution Alliance and Horde crests for Sintezza signals and faction columns.

## 1.3.16

- Fixed a startup error when a settings help button assigned its text before its font.

## 1.3.15

- Added compact themed help beside settings that need a short explanation.
- Documented window strata, window locking, and decorative animation in their settings.

## 1.3.14

- Added three fine cracks to the shared slate background.
- Added a subtle palette tint to window headers and panels.
- Smoothed the notch in the header seam and kept its size consistent when resizing.

## 1.3.13

- Added a title strip with an icon and row separators to the shared window and minimap settings.
- Adjusted the window tint, header, button shading, and appearance of slider fills.
- Applied the theme's Spectral Medium font to window-setting labels when the theme interface font is selected.
