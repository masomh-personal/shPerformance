# Changelog

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

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
