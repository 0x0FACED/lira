# Changelog

## Unreleased

- Keep document/controller identity stable across viewer rebuilds.
- Integrate native text selection, versioned page-range geometry, highlight painting/removal and navigation to saved selections.
- Preserve legacy 1-based page locators and constrain navigation to document bounds.
- Observe reader taps without competing with native double-click, drag or long-press selection; forward native deselection.
- Handle internal PDF destinations and external HTTP(S) links.
- Normalize zero-area active edge geometry so exact horizontal drags retain real native text selections; leave collapsed carets and stored fragment rectangles unchanged.
- Center saved selections without increasing the current zoom; only zoom out when required to fit the selected area.
- Add real PDFium selection, navigation and painted-highlight regression scenarios.
