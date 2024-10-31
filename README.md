# WoW Performance Addon

## Description

This addon requires a data broker display addon to be enabled. It allows you to customize the fonts of tooltips, which are handled via a tooltip addon. I highly recommend using TipTac, ElvUI, or similar add-ons for this purpose.

<div align="center">
  <img width="300" src="https://github.com/masomh-personal/shPerformance/blob/main/media/shPerformance.png?raw=true">
  <img width="300" src="https://github.com/masomh-personal/shPerformance/blob/main/media/shPerformance.png?raw=true">
  <img width="300" src="https://github.com/masomh-personal/shPerformance/blob/main/media/shPerformance.png?raw=true">
</div>

## Features (Data Texts for LDB compatible add-ons)

- **shPerformance**: Frames per second (fps) + memory/latency
- **shLatency**: Network stats including home and world latency/lag (ms)
- **shFps**: FPS + Network stats including home and world latency/lag (ms)
- **Addon memory usage**: Displayed in either MB or KB.
- **Sorting**: By descending memory usage (and gradient colored)
- **ADVANCED - Customization Options (can be changed in `init.lua`)**:
  - Update period (in seconds)
  - Memory threshold (in KB)
  - Color gradient variable (for higher usage systems)
  - Number of max add-ons displayed
  - Alpha sorting

## Goals

- **Efficiency**: Keep the addon’s CPU usage to a minimum and only update when needed.
- **Visual Appeal**: Ensure the information is easily read and visually pleasing.
- **Real-Time Updates**: Provide real-time updates via the tooltip and data broker text.
- **Relevance**: Display only essential and relevant data—no fluff or technical jargon.
- **User Control**: Allow users to choose their preferred sorting method, memory threshold, and update intervals (advanced).

## Technical Information

For more in-depth technical details and instructions on changing settings, please refer to the `init.lua`

## Credits

Special thanks to the WoW community for their ongoing support and feedback.

---

_Happy gaming!_
