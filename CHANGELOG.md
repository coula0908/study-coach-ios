# Changelog

## 0.1.2

- Replace PencilKit's failing overlay input recognizer with the Pencil-only
  gesture path proven by the MIT-licensed Pumice app on iPadOS 26.
- Keep PencilKit for page-local rendering and `PKDrawing` persistence.
- Preserve finger pan and pinch by rejecting non-Pencil touches before they
  compete with PDFKit.
- Configure the overlay provider before loading the PDF, enable markup mode,
  and enable PDFKit's visible page containers.
- Add repository checks and third-party attribution for the adopted input path.

Physical iPadOS 26 retesting is required before this fix is considered accepted.

## 0.1.1

- Fix Apple Pencil input being routed to PDF scrolling instead of the page canvas.
- Keep PencilKit's `.pencilOnly` drawing policy as the single input classifier.
- Add a repository check that prevents reintroducing the custom canvas `hitTest` override.

Physical iPadOS 26 testing confirmed that this change alone was insufficient:
pen, highlighter, and eraser input still reached PDFView instead of the canvas.

## 0.1.0

- Initial PDF and Apple Pencil MVP.
- Add PDF import, viewing, navigation, zoom, page-bound PencilKit overlays, drawing tools, and local per-page persistence.
