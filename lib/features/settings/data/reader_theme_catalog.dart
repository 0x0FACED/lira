enum ReaderPaletteKind { day, paper, dark, evening }

class ReaderThemePalette {
  final ReaderPaletteKind kind;
  final int backgroundColor;
  final int textColor;
  final int linkColor;
  final int selectionColor;

  const ReaderThemePalette({
    required this.kind,
    required this.backgroundColor,
    required this.textColor,
    required this.linkColor,
    required this.selectionColor,
  });
}

const readerThemePalettes = [
  ReaderThemePalette(
    kind: ReaderPaletteKind.day,
    backgroundColor: 0xFFFFFFFF,
    textColor: 0xFF202124,
    linkColor: 0xFF1557B0,
    selectionColor: 0xFFCCE1FF,
  ),
  ReaderThemePalette(
    kind: ReaderPaletteKind.paper,
    backgroundColor: 0xFFFFF7ED,
    textColor: 0xFF342E28,
    linkColor: 0xFF765027,
    selectionColor: 0xFFE8D39B,
  ),
  ReaderThemePalette(
    kind: ReaderPaletteKind.dark,
    backgroundColor: 0xFF181A1B,
    textColor: 0xFFE8E6E3,
    linkColor: 0xFF9CCBFF,
    selectionColor: 0xFF465C73,
  ),
  ReaderThemePalette(
    kind: ReaderPaletteKind.evening,
    backgroundColor: 0xFF2B211B,
    textColor: 0xFFE9D8B7,
    linkColor: 0xFFE1B879,
    selectionColor: 0xFF78583B,
  ),
];
