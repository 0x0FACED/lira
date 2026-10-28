import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html;
import 'package:xml/xml.dart';

import '../domain/discover_item.dart';
import '../domain/discover_source.dart';

Uri canonicalDiscoverUrl(Uri uri) {
  if (!{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw FormatException('Material URL must be an HTTP(S) URL', uri);
  }
  final parameters = <String, List<String>>{};
  final keys = uri.queryParametersAll.keys.toList()..sort();
  for (final key in keys) {
    if (key.toLowerCase().startsWith('utm_') ||
        {'fbclid', 'gclid', 'mc_cid', 'mc_eid'}.contains(key.toLowerCase())) {
      continue;
    }
    parameters[key] = uri.queryParametersAll[key]!;
  }
  var path = uri.normalizePath().path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return Uri(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
    port: uri.hasPort ? uri.port : null,
    path: path.isEmpty ? '/' : path,
    queryParameters: parameters.isEmpty ? null : parameters,
  );
}

String discoverMaterialId(Uri uri) =>
    'discover_${sha256.convert(utf8.encode(canonicalDiscoverUrl(uri).toString()))}';

String _text(String value) => (html.parseFragment(value).text ?? '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _child(XmlElement node, String name) => node.childElements
    .where((element) => element.name.local == name)
    .map((element) => element.innerText)
    .join(' ')
    .trim();

DateTime? _date(String value) {
  if (value.isEmpty) return null;
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso.toUtc();
  try {
    return HttpDate.parse(value).toUtc();
  } on HttpException {
    // RSS permits numeric timezone offsets, which HttpDate does not accept.
    final match = RegExp(
      r'(?:\w{3},\s*)?(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s+([+-])(\d{2})(\d{2})',
    ).firstMatch(value);
    if (match == null) return null;
    final month = _months.indexWhere(
      (month) => month.startsWith(match.group(2)!.toLowerCase()),
    );
    if (month < 0) return null;
    final date = DateTime.utc(
      int.parse(match.group(3)!),
      month + 1,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6) ?? '0'),
    );
    final offset = Duration(
      hours: int.parse(match.group(8)!),
      minutes: int.parse(match.group(9)!),
    );
    return match.group(7) == '+' ? date.subtract(offset) : date.add(offset);
  }
}

const _months = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

List<DiscoverItem> parseDiscoverMetadata(String raw, DiscoverSource source) {
  final document = XmlDocument.parse(raw);
  final root = document.rootElement.name.local;
  if (source.kind == DiscoverSourceKind.rfc) {
    if (root != 'rfc-index') {
      throw const FormatException('The RFC endpoint did not return its index');
    }
    final items = <DiscoverItem>[];
    for (final entry in document.rootElement.childElements) {
      if (entry.name.local != 'rfc-entry') continue;
      final number = int.tryParse(
        _child(entry, 'doc-id').replaceFirst('RFC', ''),
      );
      final title = _child(entry, 'title');
      if (number == null || title.isEmpty || title == 'Not Issued') continue;
      final date = entry.childElements
          .where((element) => element.name.local == 'date')
          .firstOrNull;
      final year = date == null ? null : int.tryParse(_child(date, 'year'));
      final month = date == null
          ? -1
          : _months.indexOf(_child(date, 'month').toLowerCase());
      final url = Uri.https('www.rfc-editor.org', '/rfc/rfc$number.html');
      items.add(
        DiscoverItem(
          id: discoverMaterialId(url),
          sourceId: source.id,
          title: 'RFC $number: $title',
          url: url,
          author: entry.childElements
              .where((element) => element.name.local == 'author')
              .map((author) => _child(author, 'name'))
              .where((name) => name.isNotEmpty)
              .join(', '),
          summary: _child(
            entry,
            'abstract',
          ).replaceAll(RegExp(r'\s+'), ' ').trim(),
          publishedAt: year == null
              ? null
              : DateTime.utc(year, month < 0 ? 1 : month + 1),
          status: _child(entry, 'current-status'),
          documentNumber: number,
        ),
      );
    }
    if (items.isEmpty)
      throw const FormatException('The RFC index contains no documents');
    items.sort((a, b) => b.documentNumber!.compareTo(a.documentNumber!));
    return items;
  }
  if (source.kind != DiscoverSourceKind.rss ||
      !{'rss', 'feed', 'RDF'}.contains(root)) {
    throw const FormatException(
      'The source did not return an RSS or Atom feed',
    );
  }
  final base = Uri.parse(source.feedUrl ?? source.homeUrl);
  final items = <String, DiscoverItem>{};
  for (final entry in document.descendants.whereType<XmlElement>()) {
    if (entry.name.local != 'item' && entry.name.local != 'entry') continue;
    final title = _text(_child(entry, 'title'));
    final links = entry.childElements.where(
      (element) => element.name.local == 'link',
    );
    final link = links
        .where(
          (element) =>
              element.getAttribute('rel') == null ||
              element.getAttribute('rel') == 'alternate',
        )
        .firstOrNull;
    final rawUrl = link?.getAttribute('href') ?? link?.innerText.trim() ?? '';
    if (title.isEmpty || rawUrl.isEmpty) continue;
    Uri url;
    try {
      url = canonicalDiscoverUrl(base.resolve(rawUrl));
    } on FormatException {
      continue;
    }
    final description = _child(entry, 'description');
    final summary = description.isEmpty
        ? _child(entry, 'summary')
        : description;
    final content = _child(entry, 'encoded');
    Uri? image;
    for (final node in entry.descendants.whereType<XmlElement>()) {
      if ({'thumbnail', 'content', 'enclosure'}.contains(node.name.local)) {
        final type = node.getAttribute('type') ?? '';
        final candidate = node.getAttribute('url');
        if (candidate != null &&
            (type.startsWith('image/') ||
                node.getAttribute('medium') == 'image' ||
                node.name.local == 'thumbnail')) {
          image = _imageUrl(base, candidate);
          if (image != null) break;
        }
      }
    }
    image ??= _imageUrl(
      base,
      html
          .parseFragment('$summary $content')
          .querySelector('img')
          ?.attributes['src'],
    );
    var author = _child(entry, 'creator');
    if (author.isEmpty) author = _child(entry, 'author');
    items.putIfAbsent(
      url.toString(),
      () => DiscoverItem(
        id: discoverMaterialId(url),
        sourceId: source.id,
        title: title,
        url: url,
        author: _text(author),
        summary: _text(summary),
        imageUrl: image,
        publishedAt: _date(
          _child(entry, 'pubDate').isNotEmpty
              ? _child(entry, 'pubDate')
              : _child(entry, 'published').isNotEmpty
              ? _child(entry, 'published')
              : _child(entry, 'updated'),
        ),
      ),
    );
  }
  if (items.isEmpty)
    throw const FormatException('The feed contains no readable items');
  final result = items.values.toList();
  result.sort(
    (a, b) =>
        (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)),
  );
  return result;
}

Uri? _imageUrl(Uri base, String? candidate) {
  if (candidate == null || candidate.trim().isEmpty) return null;
  final uri = base.resolve(candidate);
  return {'http', 'https'}.contains(uri.scheme) && uri.host.isNotEmpty
      ? uri
      : null;
}

List<DiscoverItem> searchDiscoverMetadata(
  List<DiscoverItem> items,
  String query,
) {
  final normalized = query.toLowerCase().trim();
  if (normalized.isEmpty) return const [];
  final number = RegExp(r'^(?:rfc\s*[-#]?\s*)?(\d+)$').firstMatch(normalized);
  if (number != null && items.any((item) => item.documentNumber != null)) {
    final target = int.parse(number.group(1)!);
    return items.where((item) => item.documentNumber == target).toList();
  }
  final terms = normalized.split(RegExp(r'\s+'));
  return items.where((item) {
    final text =
        '${item.title} ${item.summary} ${item.author} ${item.status ?? ''}'
            .toLowerCase();
    return terms.every(text.contains);
  }).toList();
}
