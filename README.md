# WoW Performance Addon

## Description

This addon requires a data broker display addon to be enabled. It allows you to customize the fonts of tooltips, which are handled via a tooltip addon. I highly recommend using TipTac, ElvUI, or similar addons for this purpose.

<div align="center">
  <img width="400" src="https://github.com/masomh-personal/shPerformance/blob/main/media/shPerformance.png?raw=true">
</div>

## Features (Data Texts for LDB compatible addons)

- **shPerformance**: Frames per second (fps) / memory / latency
- **shLatency**: Network stats including home and world latency / lag (ms)
- **Addon memory usage**: Displayed in either MB or KB.
- **Sorting**: By descending memory usage (and gradient colored)
- **ADVANCED - Customization Options (can be changed in `init.lua`)**:
  - Update period (in seconds)
  - Memory threshold (in KB)
  - Color gradient variable (for higher usage systems)
  - Number of max addons displayed
  - Alpha sorting

## Goals

- **Efficiency**: Keep the addon’s CPU usage to an absolute minimum and only update when needed.
- **Visual Appeal**: Ensure that the information is easy to read and visually pleasing.
- **Real-Time Updates**: Provide real-time updates via the tooltip and data broker text.
- **Relevance**: Display only important and relevant data—no fluff or technical jargon.
- **User Control**: Allow users to choose their preferred sorting method, memory threshold, and update intervals (advanced).

## Technical Information

For more in-depth technical details and instructions on changing settings, please refer to the `init.lua`

## Credits

Special thanks to the WoW community for their ongoing support and feedback.

---

_Happy gaming!_
