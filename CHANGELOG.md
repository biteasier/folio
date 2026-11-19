# Changelog

All notable changes to Folio. Versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-19

First public release.

### Added
- Native macOS Markdown viewer for Apple silicon, built with AppKit and WebKit.
- GitHub Flavored Markdown through cmark-gfm: tables, task lists, strikethrough, autolinks,
  footnotes, raw HTML and GitHub alerts (`> [!NOTE]` and friends).
- Syntax highlighting, KaTeX math (`$…$`, `$$…$$`, ```` ```math ````) and Mermaid diagrams,
  each loaded only when a document needs it.
- YAML front matter, heading anchors, copy buttons on code blocks.
- Live reload that keeps your place, including editors that save by replacing the file.
- Contents sidebar, Markdown source view, find, zoom, print and PDF export.
- Light and dark mode, tabs, Open Recent, window restore.
- Lives in the menu bar instead of the Dock, and quits when its last window closes.

[1.0.0]: https://github.com/biteasier/folio/releases/tag/v1.0.0
