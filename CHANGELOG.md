# Changelog

## 0.1.1

- Fix Apple Pencil input being routed to PDF scrolling instead of the page canvas.
- Keep PencilKit's `.pencilOnly` drawing policy as the single input classifier.
- Add a repository check that prevents reintroducing the custom canvas `hitTest` override.

Physical iPadOS 26 retesting is required before this fix is considered accepted.

## 0.1.0

- Initial PDF and Apple Pencil MVP.
- Add PDF import, viewing, navigation, zoom, page-bound PencilKit overlays, drawing tools, and local per-page persistence.
