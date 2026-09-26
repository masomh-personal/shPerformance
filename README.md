# shPerformance

<div align="center">
  <img src="https://github.com/masomh-personal/shPerformance/blob/main/media/shPerformance-logo.png?raw=true" alt="shPerformance Logo" width="128">
  
  [![WoW Version](https://img.shields.io/badge/WoW-12.1.0-blue)](https://worldofwarcraft.com)
  [![Version](https://img.shields.io/badge/Version-v12--3-green)](https://github.com/masomh-personal/shPerformance/releases)
  [![License](https://img.shields.io/badge/License-GPL--3.0-yellow)](LICENSE)
  
  **Lightweight LibDataBroker addon for system monitoring in World of Warcraft**
  
  *Throttled updates, shared utilities, and no combat-data dependencies*
</div>

## Features

### **Three Independent Data Modules**

Choose any combination that fits your UI:

- **`shPerformance`** - Combined view with FPS + Memory + Latency
- **`shFps`** - Dedicated FPS monitor with network stats
- **`shLatency`** - Focused latency display with bandwidth monitoring

### **Real-Time Monitoring**

- **FPS Tracking** - Color-coded frame rate with gradient indicators
- **Memory Usage** - Per-addon memory consumption with smart sorting
- **Network Stats** - Home/World latency with IPv4/IPv6 detection
- **Bandwidth Monitoring** - Real-time incoming/outgoing traffic

### **Smart Visual Design**

- **Gradient Color System** - Green → Yellow → Red indicators for instant readability
- **Adaptive Tooltips** - Detailed information on hover with configurable update rates
- **Clean Interface** - No clutter, only essential data displayed

<div align="center">
  <img width="280" src="https://github.com/masomh-personal/shPerformance/blob/main/media/shPerformanceV2.png?raw=true" alt="shPerformance tooltip">
  <img width="280" src="https://github.com/masomh-personal/shPerformance/blob/main/media/shLatency.png?raw=true" alt="shLatency tooltip">
  <img width="280" src="https://github.com/masomh-personal/shPerformance/blob/main/media/shFps.png?raw=true" alt="shFps tooltip">
</div>

## Runtime Design

- Two shared `C_Timer` tickers drive all feeds: FPS every 1.5 seconds and network every 15 seconds by default. No per-frame `OnUpdate` scripts run.
- Color gradients, including their hex codes, are computed once during addon loading.
- Addon memory is refreshed only while the combined tooltip is open.
- Tooltips never modify the display addon's frames and stop refreshing as soon as another element takes the tooltip.
- Clicking to force garbage collection is skipped in combat.
- The addon does not read combat-sensitive unit, aura, cooldown, or combat-log data.

## Installation

### Requirements

- **World of Warcraft Retail** 12.1.0 (Interface `120100`, verified on build `69933`) or later; 12.1.5 (`120105`) is declared in the TOC
- **LibDataBroker Display Addon** (Choose one):
  - [Titan Panel](https://www.curseforge.com/wow/addons/titan-panel)
  - [Bazooka](https://www.curseforge.com/wow/addons/bazooka)
  - [ChocolateBar](https://www.curseforge.com/wow/addons/chocolatebar)
  - ElvUI 15.19 or later (built-in DataTexts; 15.25 current on 2026-08-25)
  - Or any other LDB-compatible display

### Installation Steps

1. Download the latest release from [GitHub](https://github.com/masomh-personal/shPerformance/releases) or [CurseForge](https://www.curseforge.com/wow/addons/shperformance)
2. Extract to: `World of Warcraft\_retail_\Interface\AddOns\`
3. Ensure folder is named `shPerformance`
4. Restart WoW or `/reload` if already in-game

## Configuration

### Basic Usage

After installation, add any of the three modules to your LDB display:

- Add **shPerformance** for the all-in-one view
- Add **shFps** for dedicated FPS monitoring
- Add **shLatency** for network focus

### Advanced Configuration

Edit `init.lua` to customize:

```lua
SHP.CONFIG = {
    -- Update Intervals (seconds)
    UPDATE_PERIOD_TOOLTIP = 1.5,        -- Tooltip refresh rate
    UPDATE_PERIOD_FPS_DATA_TEXT = 1.5,  -- FPS display update
    UPDATE_PERIOD_LATENCY_DATA_TEXT = 15, -- Network stats update

    -- Display Settings
    MEM_THRESHOLD = 500,                -- Show addons above this KB value
    WANT_ALPHA_SORTING = false,         -- Sort alphabetically vs by memory

    -- Performance Thresholds
    FPS_GRADIENT_THRESHOLD = 75,        -- FPS value for green (adjust for your system)
    MS_GRADIENT_THRESHOLD = 300,        -- Latency MS for red

    -- Gradient Colors (R, G, B values 0-1)
    GRADIENT_COLOR_SEQUENCE_TABLE = {
        0, 0.97, 0,      -- Green
        0.97, 0.97, 0,   -- Yellow
        0.95, 0, 0       -- Red
    },
}
```

### Tooltip Interaction

- **Click** - Force garbage collection (out of combat) and refresh the visible tooltip
- **Hover** - View detailed addon memory usage and network stats

### Diagnostics

Run `/shperformance test` (or `/shp test`) to open an on-demand dashboard. It checks gradient boundaries and colorizing, memory formatting, required APIs, LDB feeds, addon sort keys, and safe addon-memory refreshes.

### Retail 12.1 Manual Test

After updating or installing:

1. Log in or run `/reload`; confirm no Lua errors.
2. Confirm all three LDB feeds render and update.
3. Hover and click the combined feed; verify network data, memory totals, sorting, and garbage collection.
4. While hovering a feed, move onto a bag item; the item tooltip must not be overwritten by the next refresh.
5. Run `/shperformance test`; confirm every diagnostic passes.
6. Repeat tooltip checks in combat and an instance (clicking should report that garbage collection was skipped); if available, also check an active PvP match.

The addon does not call aura or unit-name APIs, so the 12.1 aura secrecy changes and the less restrictive `UnitName` behavior in active PvP matches require no runtime migration. The combat and PvP checks guard against unexpected secret-value, taint, or forbidden-frame errors from display addons.

## Technical Details

### Architecture

- **Modular Design** - Three independent LDB objects share optimized core utilities
- **Shared Tickers** - One FPS and one network ticker feed every module; each stat is sampled once per interval
- **Shared Utilities** - Common color, tooltip, memory, and network helpers
- **On-Demand Diagnostics** - The test dashboard creates no background updater

### Optimizations

- Frequently used WoW API and Lua functions are localized in each file.
- Format strings and a 101-entry gradient table (with precomputed hex colors) are cached.
- Timer-driven updates replace per-frame polling; tooltip refreshes run only while the tooltip is owned.

### File Structure

```
shPerformance/
├── init.lua              # Core initialization and configuration
├── utils.lua             # Optimized utility functions
├── shPerformance.lua     # Combined display module
├── shFps.lua            # FPS-focused module
├── shLatency.lua        # Latency-focused module
├── diagnostics.lua      # On-demand in-game checks
├── shPerformance.toc    # Addon metadata
├── scripts/check.sh     # Local structural validation
├── .githooks/pre-push   # Optional native Git hook
└── lib/                 # Required libraries
    ├── LibStub.lua
    ├── LibDataBroker-1.1.lua
    └── CallbackHandler-1.0.lua
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests on [GitHub](https://github.com/masomh-personal/shPerformance).

### Development Guidelines

1. Maintain WoW addon best practices (localize APIs, minimize globals)
2. Test in raid environments before submitting performance changes
3. Document any new configuration options
4. Follow existing code style and formatting

### Local Checks

Run `sh scripts/check.sh` before committing. The checker validates TOC entries, runtime assets, WoW 12.1 restricted API usage, and Lua syntax when `luac` or `luajit` is installed.

To enable the native pre-push hook without changing Git configuration:

```sh
cp .githooks/pre-push .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```

The hook runs the same local checker. No GitHub Actions workflow is required.

### WoW 12.1 Secret Values

shPerformance only reads frame rate, network statistics, and user-addon memory. It does not consume APIs that return secret combat values. Retail 12.1 makes aura data more restrictive and introduces forbidden aspects for aura frames, but this addon creates only ordinary frames and does not query auras or unit names. Any future unit health, power, aura, unit-name, cooldown, combat-log, `C_Secrets`, or `C_RestrictedActions` usage requires an explicit WoW 12.1 safety review.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Credits

- **Author**: mhDesigns (formerly Shaykh)
- **Special Thanks**: Tekkub, Stoutwrithe, and the WoW addon community
- **Libraries**: LibStub, LibDataBroker, CallbackHandler

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

**Latest Version: v12-3** (2026-08-25)

- Updated Retail compatibility metadata to Interface `120100` for patch 12.1.0
- Audited runtime APIs against 12.1 aura, secret-value, and frame-script changes
- Documented ElvUI 15.19+ compatibility and current 15.25 integration
- Expanded static and in-game testing guidance for Retail 12.1

---

<div align="center">
  
  **Happy Gaming!**
  
  If you find this addon helpful, please consider giving it a star on [GitHub](https://github.com/masomh-personal/shPerformance)
  
</div>
