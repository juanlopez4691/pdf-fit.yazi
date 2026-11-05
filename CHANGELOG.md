# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-11-05

### Added

- Page-fit PDF preview: each page is rasterized at the widest size that still shows the whole page, derived from the page's aspect ratio and the terminal's cell size (`rt.term.cell_size()`), instead of Yazi's built-in fixed 150 DPI
- Page cache keyed by file, page and pane geometry, so only a resize re-renders
- `J`/`K` page navigation
- Pages are written to a temporary name and renamed, so a preview can never read a half-written JPEG

[0.1.0]: https://github.com/juanlopez4691/pdf-fit.yazi/releases/tag/v0.1.0
