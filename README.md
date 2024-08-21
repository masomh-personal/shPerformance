# WoW Performance Addon

<div style="text-align: center;">
<img src="https://media.forgecdn.net/attachments/946/595/shperformance.png" alt="Addon Image" width="400" style="align: center"/>
</div>

## Description

This addon requires a data broker display addon to be enabled. It allows you to customize the fonts of tooltips, which are handled via a tooltip addon. I highly recommend using TipTac, ElvUI, or similar addons for this purpose.

## Features

- **Frames per second (fps)**
- **Latency (ms)**: Displays both HOME/local and WORLD ms.
- **Addon memory usage**: Displayed in either MB or KB.
- **Sorting Options**:
  - Alphabetically
  - By descending memory usage
- **Customization Options**:
  - Update period (in seconds)
  - Memory threshold (in KB)
  - Color gradient variable (for higher usage systems)
  - Number of max addons displayed

## Goals

My objectives in creating this addon include:

- **Efficiency**: Keep the addon’s memory usage under 30 KB.
- **Visual Appeal**: Ensure that the information is easy to read and visually pleasing.
- **Real-Time Updates**: Provide real-time updates via the tooltip and data broker text.
- **Relevance**: Display only important and relevant data—no fluff or technical jargon.
- **User Control**: Allow users to choose their preferred sorting method, memory threshold, and update intervals.

## Installation

1. Download and extract the addon folder into your WoW AddOns directory.
2. Make sure you have a data broker display addon enabled.
3. Customize the settings to your preference using the LUA file provided.

## Technical Information

For more in-depth technical details and instructions on changing settings, please refer to the `shPerformance.lua` or `shMem.lua` files within the addon folder.

## Credits

Special thanks to the WoW community for their ongoing support and feedback.

---

_Happy gaming!_
