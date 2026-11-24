// Catalog subjects are not a genre taxonomy. Only recognize explicit labels
// and genre components of catalog classification headings.
const _genres = <(String, String, List<String>)>[
  ('Fiction', 'Художественная литература', ['fiction']),
  ('Science fiction', 'Научная фантастика', ['science fiction', 'sci-fi']),
  ('Fantasy', 'Фэнтези', ['fantasy', 'fantasy fiction', 'fantasy literature']),
  (
    'Mystery',
    'Детектив',
    [
      'mystery',
      'mystery fiction',
      'detective fiction',
      'detective and mystery stories',
      'mystery and detective',
    ],
  ),
  ('Thriller', 'Триллер', ['thriller', 'thrillers', 'suspense fiction']),
  (
    'Romance',
    'Любовный роман',
    ['romance fiction', 'romance novels', 'love stories'],
  ),
  (
    'Historical fiction',
    'Историческая проза',
    ['historical fiction', 'historical novels'],
  ),
  ('Horror', 'Ужасы', ['horror', 'horror fiction', 'horror tales']),
  (
    'Adventure',
    'Приключения',
    ['adventure fiction', 'adventure stories', 'action and adventure'],
  ),
  ('Nonfiction', 'Нон-фикшн', ['nonfiction', 'non-fiction']),
  ('Biography', 'Биография', ['biography', 'biographies']),
  (
    'Memoir',
    'Мемуары',
    ['memoir', 'memoirs', 'personal memoirs', 'autobiography'],
  ),
  ('Poetry', 'Поэзия', ['poetry', 'poems']),
  ('Drama', 'Драматургия', ['dramatic literature']),
  (
    'Children’s literature',
    'Детская литература',
    ['juvenile fiction', "children's literature", "children's fiction"],
  ),
  (
    'Young adult',
    'Подростковая литература',
    ['young adult fiction', 'young adult literature'],
  ),
  (
    'Comics',
    'Комиксы',
    [
      'comics',
      'comic books',
      'comic books, strips, etc',
      'graphic novels',
      'manga',
    ],
  ),
  ('Short stories', 'Рассказы', ['short stories', 'short story collections']),
];

String _key(String label) => label
    .trim()
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r'\s+'), ' ');

final _knownGenres = {
  for (var i = 0; i < _genres.length; i++) ...{
    _key(_genres[i].$1): i,
    _key(_genres[i].$2): i,
    for (final alias in _genres[i].$3) _key(alias): i,
  },
};

List<String> openLibraryGenres(
  Iterable<String> subjects, {
  required bool russian,
}) {
  final found = <int>{};
  for (final subject in subjects) {
    final key = _key(subject);
    final direct = _knownGenres[key];
    if (direct != null) {
      found.add(direct);
      continue;
    }
    // E.g. "Fiction, science fiction, general"; not an arbitrary topical tag.
    if (key.startsWith('fiction, ')) {
      for (final part in key.split(',').skip(1)) {
        final genre = _knownGenres[part.trim()];
        if (genre != null) found.add(genre);
      }
    }
  }
  if (found.any((genre) => genre >= 1 && genre <= 8)) found.remove(0);
  return [
    for (var i = 0; i < _genres.length; i++)
      if (found.contains(i)) russian ? _genres[i].$2 : _genres[i].$1,
  ];
}

List<String> mergeOpenLibraryGenres(
  List<String> existing,
  Iterable<String> additions,
) {
  Object identity(String label) {
    final key = _key(label);
    return _knownGenres[key] ?? key;
  }

  final seen = existing.map(identity).toSet();
  return [
    ...existing,
    for (final label in additions)
      if (seen.add(identity(label))) label,
  ];
}
