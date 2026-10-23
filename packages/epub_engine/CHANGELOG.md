# Changelog

## Unreleased

- Use OPF spine as the authoritative reading order; preserve front matter, documents absent from TOC, and hierarchical navigation anchors.
- Decode UTF-8/UTF-16 without silent character replacement; reject damaged required spine documents explicitly.
- Preserve exact, versioned content positions across scrolling, pagination, reflow and navigation while retaining legacy location decoding.
- Preserve text under overlapping highlights and styled page splits; fix internal links, encoded paths and Unicode hit testing.
- Own selection notifiers per mounted scope and capture scroll positions after layout.
- Remove the unused WebView renderer and its dependencies.
