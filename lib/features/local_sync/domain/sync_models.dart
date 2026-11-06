/// Portable library data. Positions are opaque engine locators, never rewritten.
class SyncRecord {
  const SyncRecord({
    required this.kind,
    required this.id,
    required this.bookHash,
    required this.modifiedAt,
    required this.deviceId,
    this.deleted = false,
    required this.payload,
  });

  final String kind;
  final String id;
  final String bookHash;
  final int modifiedAt;
  final String deviceId;
  final bool deleted;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'id': id,
    'bookHash': bookHash,
    'modifiedAt': modifiedAt,
    'deviceId': deviceId,
    'deleted': deleted,
    'payload': payload,
  };

  factory SyncRecord.fromJson(Map<String, dynamic> json) {
    final kind = _string(json, 'kind', max: 16);
    if (!const {'book', 'progress', 'highlight', 'bookmark'}.contains(kind)) {
      throw const FormatException('Unknown sync record kind');
    }
    final hash = _string(json, 'bookHash', max: 64);
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw const FormatException('Invalid book fingerprint');
    }
    final id = _string(json, 'id', max: 256);
    if ((kind == 'book' || kind == 'progress') && id != hash) {
      throw const FormatException('Invalid portable record identity');
    }
    final modifiedAt = _integer(json, 'modifiedAt');
    final deviceId = _string(json, 'deviceId', max: 256);
    final deleted = json['deleted'];
    if (deleted is! bool || (kind == 'book' && deleted)) {
      throw const FormatException('Invalid sync deletion');
    }
    final raw = json['payload'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid sync payload');
    }
    final payload = <String, dynamic>{};
    if (!deleted) {
      switch (kind) {
        case 'book':
          payload['title'] = _string(raw, 'title', max: 16384, empty: true);
          payload['author'] = _string(raw, 'author', max: 16384, empty: true);
          final format = _string(raw, 'format', max: 4);
          if (format != 'epub' && format != 'pdf') {
            throw const FormatException('Unsupported synced book format');
          }
          payload['format'] = format;
          payload['createdAt'] = _integer(raw, 'createdAt');
          payload['pageCount'] = _integer(raw, 'pageCount');
          payload['fileSizeBytes'] = _integer(raw, 'fileSizeBytes');
        case 'progress':
          payload['location'] = _string(raw, 'location', empty: true);
          payload['percentage'] = _percentage(raw);
          payload['updatedAt'] = _integer(raw, 'updatedAt');
        case 'highlight':
          payload['text'] = _string(raw, 'text', empty: true);
          payload['location'] = _string(raw, 'location', empty: true);
          payload['color'] = _string(raw, 'color', max: 64);
          if (!RegExp(
            r'^#[0-9a-fA-F]{6}$',
          ).hasMatch(payload['color'] as String)) {
            throw const FormatException('Invalid annotation color');
          }
          final note = raw['note'];
          if (note != null && (note is! String || note.length > 1048576)) {
            throw const FormatException('Invalid annotation note');
          }
          payload['note'] = note;
          payload['createdAt'] = _integer(raw, 'createdAt');
        case 'bookmark':
          payload['location'] = _string(raw, 'location', empty: true);
          payload['percentage'] = _percentage(raw);
          payload['createdAt'] = _integer(raw, 'createdAt');
      }
    }
    return SyncRecord(
      kind: kind,
      id: id,
      bookHash: hash,
      modifiedAt: modifiedAt,
      deviceId: deviceId,
      deleted: deleted,
      payload: payload,
    );
  }

  /// A total ordering also makes deliberately equal revisions deterministic.
  int compareRevision(SyncRecord other) {
    var result = modifiedAt.compareTo(other.modifiedAt);
    if (result == 0) result = deviceId.compareTo(other.deviceId);
    if (result == 0)
      result = (deleted ? 1 : 0).compareTo(other.deleted ? 1 : 0);
    if (result == 0)
      result = _payloadKey(payload).compareTo(_payloadKey(other.payload));
    return result;
  }
}

class SyncSnapshot {
  const SyncSnapshot({required this.records});
  final List<SyncRecord> records;

  Map<String, dynamic> toJson() => {
    'records': records.map((record) => record.toJson()).toList(),
  };

  factory SyncSnapshot.fromJson(Map<String, dynamic> json) {
    final records = json['records'];
    if (records is! List || records.length > 100000) {
      throw const FormatException('Invalid sync snapshot');
    }
    return SyncSnapshot(
      records: records.map((value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Invalid sync record');
        }
        return SyncRecord.fromJson(value);
      }).toList(),
    );
  }
}

class SyncMergeResult {
  const SyncMergeResult({
    this.booksReceived = 0,
    this.highlightsChanged = 0,
    this.bookmarksChanged = 0,
    this.progressChanged = 0,
  });

  final int booksReceived;
  final int highlightsChanged;
  final int bookmarksChanged;
  final int progressChanged;
  int get totalChanges =>
      booksReceived + highlightsChanged + bookmarksChanged + progressChanged;

  Map<String, dynamic> toJson() => {
    'booksReceived': booksReceived,
    'highlightsChanged': highlightsChanged,
    'bookmarksChanged': bookmarksChanged,
    'progressChanged': progressChanged,
  };

  factory SyncMergeResult.fromJson(Map<String, dynamic> json) =>
      SyncMergeResult(
        booksReceived: _integer(json, 'booksReceived'),
        highlightsChanged: _integer(json, 'highlightsChanged'),
        bookmarksChanged: _integer(json, 'bookmarksChanged'),
        progressChanged: _integer(json, 'progressChanged'),
      );
}

String _string(
  Map<String, dynamic> json,
  String key, {
  int max = 1048576,
  bool empty = false,
}) {
  final value = json[key];
  if (value is! String || (!empty && value.isEmpty) || value.length > max) {
    throw FormatException('Invalid $key');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0 || value > 9007199254740991) {
    throw FormatException('Invalid $key');
  }
  return value;
}

double _percentage(Map<String, dynamic> json) {
  final value = json['percentage'];
  if (value is! num || !value.isFinite || value < 0 || value > 100) {
    throw const FormatException('Invalid percentage');
  }
  return value.toDouble();
}

String _payloadKey(Map<String, dynamic> payload) {
  final keys = payload.keys.toList()..sort();
  return keys.map((key) => '$key:${payload[key]}').join('\u0000');
}
