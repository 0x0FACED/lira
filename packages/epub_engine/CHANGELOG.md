# Changelog

## Unreleased

- Add interactive cylindrical paper curls in horizontal mode, including center-spine spread turns, theme-aware shadows, cancellation and reduced motion; publish progress only after a completed turn and retain native selection/oversized-page scrolling.
- Use OPF spine as the authoritative reading order; preserve front matter, documents absent from TOC, and hierarchical navigation anchors.
- Decode UTF-8/UTF-16 without silent character replacement; reject damaged required spine documents explicitly.
- Preserve exact, versioned content positions across scrolling, pagination, reflow and navigation while retaining legacy location decoding.
- Preserve text under overlapping highlights and styled page splits; fix internal links, encoded paths and Unicode hit testing.
- Own selection notifiers per mounted scope and capture scroll positions after layout.
- Remove the unused WebView renderer and its dependencies.
- Resolve images/CSS by complete document-relative URI paths; distinguish literal ZIP percent signs, spaces and duplicate basenames.
- Render inline images, SVG covers and nested local SVG resources, with hidden descendants removed and vector IDs isolated.
- Preserve nested list/quotation structure, explicit line breaks, ordered numbering and unresolved-object fallback content.
- Render and paginate table grids with row/column spans, source-order selection and persistent oversized-page scrolling.
- Apply a bounded local author CSS cascade without replacing the reader's font choice.
