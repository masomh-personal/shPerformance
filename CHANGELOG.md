# Changelog

## [Unreleased]

### Fixed

- Query user-addon memory by name and exclude secure Blizzard addons.
- Correct total addon memory and the exact 1024 KB formatting boundary.
- Initialize color gradients before broker updates.
- Correct alphabetical sorting, tooltip fallback anchoring, and click behavior.

### Added

- Add `/shperformance test` and `/shp test` diagnostics dashboard.
- Add local structural validation and an optional native pre-push hook.

### Changed

- Remove unused code and the duplicate TGA logo.
- Exclude documentation screenshots from packaged Git archives.
- Align documentation with GPL-3.0 and remove unsupported benchmark claims.

---

## [v12-1] - 2026-06-25

### Updated

- **WoW 12.0.7 Support** - Updated TOC to interface version **120007** for WoW 12.0.7
- **Documentation refresh** - Updated README version references and compatibility notes for WoW 12.0.7

### Changed

- **Simplified network IP labels** - Tooltip labels now use `GetNetIpTypes()` directly instead of gating IP type display behind the `useIPv6` CVar
- **Reduced duplicate tooltip boilerplate** - Shared LDB tooltip handlers now live in `utils.lua`
- **Refreshed embedded CallbackHandler** - Updated bundled `CallbackHandler-1.0` from minor 3 to minor 8

### Fixed

- **Fixed memory unit conversion** - Memory values now use a consistent 1024 KB to 1 MB conversion
- **Removed unused helpers and format strings** - Cleaned up dead utility functions and stale pre-cached format strings
- **Corrected misleading comments** - Updated memory threshold and latency refresh comments to match actual behavior

---

## [3.1.0] - 2026-01-23

### Updated

- **WoW Midnight Support** - Updated TOC to interface version **120000** for WoW 12.0 Midnight
- **Added Category metadata** - New `## Category: Data Broker` for improved addon list organization in WoW 11.1.0+

### Fixed

- **Fixed misleading variable name** in `shFps.lua` - Renamed `elapsedLatencyController` to `elapsedFpsController`
- **Fixed typo** in section comments - Changed "uppdate" to "update" in `shFps.lua` and `shLatency.lua`
- **Removed unused localization** - Cleaned up unused `C_CVar` variable in `utils.lua`

---

## [3.0.0] - 2024-12-03

### MAJOR PERFORMANCE OPTIMIZATIONS

#### Critical Fixes

- **Fixed memory leak** in tooltip OnUpdate handlers that was creating new closures on every hover
- **Reduced allocations** during tooltip display
- **Reduced repeated work** during normal operation

#### Performance Enhancements

- **Localized frequently used WoW API and Lua functions**
- **Pre-cached all format strings** to eliminate runtime string building
- **Optimized gradient table** with direct color lookups
- **Improved memory formatting** with clearer branching and cached formats

#### Code Quality

- **Reusable tooltip handlers** prevent closure creation and garbage collection pressure
- **Direct table lookups** replace complex calculations in hot paths
- **Efficient function calls** using localized references throughout

### Compatibility

- Updated TOC to interface version **110207** for WoW patch 11.2.7

### Notes

- All three LDB modules (shPerformance, shFps, shLatency) remain independently selectable
- Original update frequencies preserved (1.5s for tooltips/FPS)
- No functional changes - 100% feature parity with previous version
- Addon is now production-ready for 40-person raids with stable memory usage

## [TWW: 2.0.5]

### UPDATE

- Updated TOC and version for 11.2.0

## [TWW: 2.0.4]

### UPDATE

- Updated TOC and version for 11.1.7

## [TWW: 2.0.3]

### UPDATE

- Updated TOC and version for 11.5.0

## [TWW: 2.0.2]

### UPDATE

- Updated TOC and version for 11.1.0

## [TWW: 2.0.1]

### UPDATE

- Updated TOC and version for 11.0.7

## [TWW: 2.0.0]

### UPDATE

- Updated TOC and version for 11.0.5 patch
- Complete re-write of addon to make it more efficient and modular
- Split up into THREE data texts: shPerformance, shLatency, and shFps

### ADDED

- Create static color gradient table once upon addon loading (to increase efficiency when sorting/coloring each line in the tooltip)
- NOTE: it was dynamically creating color gradient on each update of tooltip

## [TWW: 1.0.0]

### Added

- Initial release of `shPerformance` addon.
- Displays frames per second (fps).
- Shows latency in ms (both HOME/local and WORLD).
- Displays addon memory usage in MB or KB.
- Added options to sort by alphabetically or by descending memory usage.
- Customization for update period (in seconds) and memory threshold (in KB).
- Option to adjust color gradient and limit the number of addons displayed.
- Real-time updates via tooltip and data broker text.

### NOTES

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). Versions follow the addon's published release labels.
