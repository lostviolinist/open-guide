# OpenGuide drawing protocol v1

An explanation is one UTF-8 JSON object, maximum 256 KB. It contains `version: 1`, a nonempty `title` (up to 120 characters), and 1–12 `steps`.

Each step contains a unique nonempty `id` (up to 80 characters), nonempty `narration` (up to 1,200 characters), and `marks` (0–20). Marks replace the previous step's marks. The host begins narration when the marks appear and advances when speech completes. With speech disabled, a bounded reading delay replaces speech.

Each mark has `id`, `kind`, and `color` (`mint`, `amber`, or `blue`):

- `highlight`: requires a `rect`.
- `label`: requires a `rect` and nonempty `text` (up to 160 characters).
- `arrow`: requires distinct `from` and `to` points.

A point is `{ "x": 0.5, "y": 0.4 }`. A rect is `{ "x": 0.1, "y": 0.2, "width": 0.6, "height": 0.3 }`. Coordinates are normalized to the provided screenshot, with origin at its top-left. All points and complete rectangles must fit inside [0, 1]; rectangle dimensions must be positive. Coordinates are independent of pixel density.

Only the last step may contain `interaction`: `kind` (`hover` or `click`), `target` (rect), `label` (1–160 characters), and `dwellMilliseconds` (300–3000). Dwell applies to hover. A click requires a new physical mouse-down inside the target. The host does not synthesize input. Waits time out after 90 seconds.

After an interaction, the host discards screen marks, recaptures the same region, and requests a new document. No queued drawing commands from the old document run after that boundary.

```json
{
  "version": 1,
  "title": "Find the preview",
  "steps": [{
    "id": "preview",
    "narration": "Hover over Preview to reveal the details.",
    "marks": [{
      "id": "preview-box",
      "kind": "highlight",
      "color": "amber",
      "rect": {"x": 0.3, "y": 0.68, "width": 0.4, "height": 0.16}
    }],
    "interaction": {
      "kind": "hover",
      "target": {"x": 0.3, "y": 0.68, "width": 0.4, "height": 0.16},
      "label": "Hover over Preview",
      "dwellMilliseconds": 700
    }
  }]
}
```

The provider's tool schema is in `ModelProvider.swift`. The authoritative host validator is `GuideDocument.validate()`. The protocol is independently written and does not load any HeyClicky drawing source.
