// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, BookEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Unknown Author'),
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileUrlMeta = const VerificationMeta(
    'fileUrl',
  );
  @override
  late final GeneratedColumn<String> fileUrl = GeneratedColumn<String>(
    'file_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSavedMeta = const VerificationMeta(
    'isSaved',
  );
  @override
  late final GeneratedColumn<bool> isSaved = GeneratedColumn<bool>(
    'is_saved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_saved" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    author,
    format,
    coverUrl,
    fileUrl,
    createdAt,
    pageCount,
    fileSizeBytes,
    contentHash,
    isSaved,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('file_url')) {
      context.handle(
        _fileUrlMeta,
        fileUrl.isAcceptableOrUnknown(data['file_url']!, _fileUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('is_saved')) {
      context.handle(
        _isSavedMeta,
        isSaved.isAcceptableOrUnknown(data['is_saved']!, _isSavedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      fileUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      isSaved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_saved'],
      )!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class BookEntity extends DataClass implements Insertable<BookEntity> {
  final String id;
  final String title;
  final String author;
  final String format;
  final String? coverUrl;
  final String? fileUrl;
  final DateTime createdAt;
  final int pageCount;
  final int fileSizeBytes;
  final String? contentHash;
  final bool isSaved;
  const BookEntity({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    this.coverUrl,
    this.fileUrl,
    required this.createdAt,
    required this.pageCount,
    required this.fileSizeBytes,
    this.contentHash,
    required this.isSaved,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || fileUrl != null) {
      map['file_url'] = Variable<String>(fileUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['page_count'] = Variable<int>(pageCount);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    map['is_saved'] = Variable<bool>(isSaved);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      author: Value(author),
      format: Value(format),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      fileUrl: fileUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(fileUrl),
      createdAt: Value(createdAt),
      pageCount: Value(pageCount),
      fileSizeBytes: Value(fileSizeBytes),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      isSaved: Value(isSaved),
    );
  }

  factory BookEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookEntity(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      format: serializer.fromJson<String>(json['format']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      fileUrl: serializer.fromJson<String?>(json['fileUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      isSaved: serializer.fromJson<bool>(json['isSaved']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'format': serializer.toJson<String>(format),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'fileUrl': serializer.toJson<String?>(fileUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'pageCount': serializer.toJson<int>(pageCount),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'contentHash': serializer.toJson<String?>(contentHash),
      'isSaved': serializer.toJson<bool>(isSaved),
    };
  }

  BookEntity copyWith({
    String? id,
    String? title,
    String? author,
    String? format,
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> fileUrl = const Value.absent(),
    DateTime? createdAt,
    int? pageCount,
    int? fileSizeBytes,
    Value<String?> contentHash = const Value.absent(),
    bool? isSaved,
  }) => BookEntity(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author ?? this.author,
    format: format ?? this.format,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    fileUrl: fileUrl.present ? fileUrl.value : this.fileUrl,
    createdAt: createdAt ?? this.createdAt,
    pageCount: pageCount ?? this.pageCount,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    isSaved: isSaved ?? this.isSaved,
  );
  BookEntity copyWithCompanion(BooksCompanion data) {
    return BookEntity(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      format: data.format.present ? data.format.value : this.format,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      fileUrl: data.fileUrl.present ? data.fileUrl.value : this.fileUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      isSaved: data.isSaved.present ? data.isSaved.value : this.isSaved,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookEntity(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('fileUrl: $fileUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('pageCount: $pageCount, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('contentHash: $contentHash, ')
          ..write('isSaved: $isSaved')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    format,
    coverUrl,
    fileUrl,
    createdAt,
    pageCount,
    fileSizeBytes,
    contentHash,
    isSaved,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookEntity &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.format == this.format &&
          other.coverUrl == this.coverUrl &&
          other.fileUrl == this.fileUrl &&
          other.createdAt == this.createdAt &&
          other.pageCount == this.pageCount &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.contentHash == this.contentHash &&
          other.isSaved == this.isSaved);
}

class BooksCompanion extends UpdateCompanion<BookEntity> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> author;
  final Value<String> format;
  final Value<String?> coverUrl;
  final Value<String?> fileUrl;
  final Value<DateTime> createdAt;
  final Value<int> pageCount;
  final Value<int> fileSizeBytes;
  final Value<String?> contentHash;
  final Value<bool> isSaved;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.format = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.fileUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.isSaved = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String title,
    this.author = const Value.absent(),
    required String format,
    this.coverUrl = const Value.absent(),
    this.fileUrl = const Value.absent(),
    required DateTime createdAt,
    this.pageCount = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.isSaved = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       format = Value(format),
       createdAt = Value(createdAt);
  static Insertable<BookEntity> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? format,
    Expression<String>? coverUrl,
    Expression<String>? fileUrl,
    Expression<DateTime>? createdAt,
    Expression<int>? pageCount,
    Expression<int>? fileSizeBytes,
    Expression<String>? contentHash,
    Expression<bool>? isSaved,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (format != null) 'format': format,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (fileUrl != null) 'file_url': fileUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (pageCount != null) 'page_count': pageCount,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (contentHash != null) 'content_hash': contentHash,
      if (isSaved != null) 'is_saved': isSaved,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? author,
    Value<String>? format,
    Value<String?>? coverUrl,
    Value<String?>? fileUrl,
    Value<DateTime>? createdAt,
    Value<int>? pageCount,
    Value<int>? fileSizeBytes,
    Value<String?>? contentHash,
    Value<bool>? isSaved,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format ?? this.format,
      coverUrl: coverUrl ?? this.coverUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      createdAt: createdAt ?? this.createdAt,
      pageCount: pageCount ?? this.pageCount,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      contentHash: contentHash ?? this.contentHash,
      isSaved: isSaved ?? this.isSaved,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (fileUrl.present) {
      map['file_url'] = Variable<String>(fileUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (isSaved.present) {
      map['is_saved'] = Variable<bool>(isSaved.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('fileUrl: $fileUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('pageCount: $pageCount, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('contentHash: $contentHash, ')
          ..write('isSaved: $isSaved, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressesTable extends ReadingProgresses
    with TableInfo<$ReadingProgressesTable, ReadingProgressEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id)',
    ),
  );
  static const VerificationMeta _percentageMeta = const VerificationMeta(
    'percentage',
  );
  @override
  late final GeneratedColumn<double> percentage = GeneratedColumn<double>(
    'percentage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    percentage,
    location,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('percentage')) {
      context.handle(
        _percentageMeta,
        percentage.isAcceptableOrUnknown(data['percentage']!, _percentageMeta),
      );
    } else if (isInserting) {
      context.missing(_percentageMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  ReadingProgressEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressEntity(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      percentage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percentage'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingProgressesTable createAlias(String alias) {
    return $ReadingProgressesTable(attachedDatabase, alias);
  }
}

class ReadingProgressEntity extends DataClass
    implements Insertable<ReadingProgressEntity> {
  final String bookId;
  final double percentage;
  final String location;
  final DateTime updatedAt;
  const ReadingProgressEntity({
    required this.bookId,
    required this.percentage,
    required this.location,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['percentage'] = Variable<double>(percentage);
    map['location'] = Variable<String>(location);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingProgressesCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressesCompanion(
      bookId: Value(bookId),
      percentage: Value(percentage),
      location: Value(location),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgressEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressEntity(
      bookId: serializer.fromJson<String>(json['bookId']),
      percentage: serializer.fromJson<double>(json['percentage']),
      location: serializer.fromJson<String>(json['location']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'percentage': serializer.toJson<double>(percentage),
      'location': serializer.toJson<String>(location),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingProgressEntity copyWith({
    String? bookId,
    double? percentage,
    String? location,
    DateTime? updatedAt,
  }) => ReadingProgressEntity(
    bookId: bookId ?? this.bookId,
    percentage: percentage ?? this.percentage,
    location: location ?? this.location,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingProgressEntity copyWithCompanion(ReadingProgressesCompanion data) {
    return ReadingProgressEntity(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      percentage: data.percentage.present
          ? data.percentage.value
          : this.percentage,
      location: data.location.present ? data.location.value : this.location,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressEntity(')
          ..write('bookId: $bookId, ')
          ..write('percentage: $percentage, ')
          ..write('location: $location, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, percentage, location, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressEntity &&
          other.bookId == this.bookId &&
          other.percentage == this.percentage &&
          other.location == this.location &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressesCompanion
    extends UpdateCompanion<ReadingProgressEntity> {
  final Value<String> bookId;
  final Value<double> percentage;
  final Value<String> location;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReadingProgressesCompanion({
    this.bookId = const Value.absent(),
    this.percentage = const Value.absent(),
    this.location = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressesCompanion.insert({
    required String bookId,
    required double percentage,
    required String location,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       percentage = Value(percentage),
       location = Value(location),
       updatedAt = Value(updatedAt);
  static Insertable<ReadingProgressEntity> custom({
    Expression<String>? bookId,
    Expression<double>? percentage,
    Expression<String>? location,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (percentage != null) 'percentage': percentage,
      if (location != null) 'location': location,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressesCompanion copyWith({
    Value<String>? bookId,
    Value<double>? percentage,
    Value<String>? location,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReadingProgressesCompanion(
      bookId: bookId ?? this.bookId,
      percentage: percentage ?? this.percentage,
      location: location ?? this.location,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (percentage.present) {
      map['percentage'] = Variable<double>(percentage.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('percentage: $percentage, ')
          ..write('location: $location, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HighlightsTable extends Highlights
    with TableInfo<$HighlightsTable, HighlightEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HighlightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id)',
    ),
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#BB86FC'),
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    textContent,
    color,
    location,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'highlights';
  @override
  VerificationContext validateIntegrity(
    Insertable<HighlightEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('text_content')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(
          data['text_content']!,
          _textContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_textContentMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HighlightEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HighlightEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_content'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HighlightsTable createAlias(String alias) {
    return $HighlightsTable(attachedDatabase, alias);
  }
}

class HighlightEntity extends DataClass implements Insertable<HighlightEntity> {
  final String id;
  final String bookId;
  final String textContent;
  final String color;
  final String location;
  final String? note;
  final DateTime createdAt;
  const HighlightEntity({
    required this.id,
    required this.bookId,
    required this.textContent,
    required this.color,
    required this.location,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['text_content'] = Variable<String>(textContent);
    map['color'] = Variable<String>(color);
    map['location'] = Variable<String>(location);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HighlightsCompanion toCompanion(bool nullToAbsent) {
    return HighlightsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      textContent: Value(textContent),
      color: Value(color),
      location: Value(location),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory HighlightEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HighlightEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      textContent: serializer.fromJson<String>(json['textContent']),
      color: serializer.fromJson<String>(json['color']),
      location: serializer.fromJson<String>(json['location']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'textContent': serializer.toJson<String>(textContent),
      'color': serializer.toJson<String>(color),
      'location': serializer.toJson<String>(location),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HighlightEntity copyWith({
    String? id,
    String? bookId,
    String? textContent,
    String? color,
    String? location,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => HighlightEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    textContent: textContent ?? this.textContent,
    color: color ?? this.color,
    location: location ?? this.location,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  HighlightEntity copyWithCompanion(HighlightsCompanion data) {
    return HighlightEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      color: data.color.present ? data.color.value : this.color,
      location: data.location.present ? data.location.value : this.location,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HighlightEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('textContent: $textContent, ')
          ..write('color: $color, ')
          ..write('location: $location, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, textContent, color, location, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HighlightEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.textContent == this.textContent &&
          other.color == this.color &&
          other.location == this.location &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class HighlightsCompanion extends UpdateCompanion<HighlightEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> textContent;
  final Value<String> color;
  final Value<String> location;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const HighlightsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.textContent = const Value.absent(),
    this.color = const Value.absent(),
    this.location = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HighlightsCompanion.insert({
    required String id,
    required String bookId,
    required String textContent,
    this.color = const Value.absent(),
    required String location,
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       textContent = Value(textContent),
       location = Value(location),
       createdAt = Value(createdAt);
  static Insertable<HighlightEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? textContent,
    Expression<String>? color,
    Expression<String>? location,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (textContent != null) 'text_content': textContent,
      if (color != null) 'color': color,
      if (location != null) 'location': location,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HighlightsCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? textContent,
    Value<String>? color,
    Value<String>? location,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return HighlightsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      textContent: textContent ?? this.textContent,
      color: color ?? this.color,
      location: location ?? this.location,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HighlightsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('textContent: $textContent, ')
          ..write('color: $color, ')
          ..write('location: $location, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, BookmarkEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id)',
    ),
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _percentageMeta = const VerificationMeta(
    'percentage',
  );
  @override
  late final GeneratedColumn<double> percentage = GeneratedColumn<double>(
    'percentage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    location,
    percentage,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarkEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('percentage')) {
      context.handle(
        _percentageMeta,
        percentage.isAcceptableOrUnknown(data['percentage']!, _percentageMeta),
      );
    } else if (isInserting) {
      context.missing(_percentageMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bookId, location},
  ];
  @override
  BookmarkEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      percentage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percentage'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class BookmarkEntity extends DataClass implements Insertable<BookmarkEntity> {
  final String id;
  final String bookId;
  final String location;
  final double percentage;
  final DateTime createdAt;
  const BookmarkEntity({
    required this.id,
    required this.bookId,
    required this.location,
    required this.percentage,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['location'] = Variable<String>(location);
    map['percentage'] = Variable<double>(percentage);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      location: Value(location),
      percentage: Value(percentage),
      createdAt: Value(createdAt),
    );
  }

  factory BookmarkEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      location: serializer.fromJson<String>(json['location']),
      percentage: serializer.fromJson<double>(json['percentage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'location': serializer.toJson<String>(location),
      'percentage': serializer.toJson<double>(percentage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BookmarkEntity copyWith({
    String? id,
    String? bookId,
    String? location,
    double? percentage,
    DateTime? createdAt,
  }) => BookmarkEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    location: location ?? this.location,
    percentage: percentage ?? this.percentage,
    createdAt: createdAt ?? this.createdAt,
  );
  BookmarkEntity copyWithCompanion(BookmarksCompanion data) {
    return BookmarkEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      location: data.location.present ? data.location.value : this.location,
      percentage: data.percentage.present
          ? data.percentage.value
          : this.percentage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('location: $location, ')
          ..write('percentage: $percentage, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, location, percentage, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.location == this.location &&
          other.percentage == this.percentage &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<BookmarkEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> location;
  final Value<double> percentage;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.location = const Value.absent(),
    this.percentage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required String bookId,
    required String location,
    required double percentage,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       location = Value(location),
       percentage = Value(percentage),
       createdAt = Value(createdAt);
  static Insertable<BookmarkEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? location,
    Expression<double>? percentage,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (location != null) 'location': location,
      if (percentage != null) 'percentage': percentage,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? location,
    Value<double>? percentage,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      location: location ?? this.location,
      percentage: percentage ?? this.percentage,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (percentage.present) {
      map['percentage'] = Variable<double>(percentage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('location: $location, ')
          ..write('percentage: $percentage, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncRevisionsTable extends SyncRevisions
    with TableInfo<$SyncRevisionsTable, SyncRevisionEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<int> modifiedAt = GeneratedColumn<int>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    kind,
    entityId,
    bookId,
    modifiedAt,
    deviceId,
    deleted,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_revisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRevisionEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, entityId};
  @override
  SyncRevisionEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRevisionEntity(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $SyncRevisionsTable createAlias(String alias) {
    return $SyncRevisionsTable(attachedDatabase, alias);
  }
}

class SyncRevisionEntity extends DataClass
    implements Insertable<SyncRevisionEntity> {
  final String kind;
  final String entityId;
  final String bookId;
  final int modifiedAt;
  final String deviceId;
  final bool deleted;
  final String payload;
  const SyncRevisionEntity({
    required this.kind,
    required this.entityId,
    required this.bookId,
    required this.modifiedAt,
    required this.deviceId,
    required this.deleted,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['entity_id'] = Variable<String>(entityId);
    map['book_id'] = Variable<String>(bookId);
    map['modified_at'] = Variable<int>(modifiedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['deleted'] = Variable<bool>(deleted);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  SyncRevisionsCompanion toCompanion(bool nullToAbsent) {
    return SyncRevisionsCompanion(
      kind: Value(kind),
      entityId: Value(entityId),
      bookId: Value(bookId),
      modifiedAt: Value(modifiedAt),
      deviceId: Value(deviceId),
      deleted: Value(deleted),
      payload: Value(payload),
    );
  }

  factory SyncRevisionEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRevisionEntity(
      kind: serializer.fromJson<String>(json['kind']),
      entityId: serializer.fromJson<String>(json['entityId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      modifiedAt: serializer.fromJson<int>(json['modifiedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'entityId': serializer.toJson<String>(entityId),
      'bookId': serializer.toJson<String>(bookId),
      'modifiedAt': serializer.toJson<int>(modifiedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'deleted': serializer.toJson<bool>(deleted),
      'payload': serializer.toJson<String>(payload),
    };
  }

  SyncRevisionEntity copyWith({
    String? kind,
    String? entityId,
    String? bookId,
    int? modifiedAt,
    String? deviceId,
    bool? deleted,
    String? payload,
  }) => SyncRevisionEntity(
    kind: kind ?? this.kind,
    entityId: entityId ?? this.entityId,
    bookId: bookId ?? this.bookId,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    deviceId: deviceId ?? this.deviceId,
    deleted: deleted ?? this.deleted,
    payload: payload ?? this.payload,
  );
  SyncRevisionEntity copyWithCompanion(SyncRevisionsCompanion data) {
    return SyncRevisionEntity(
      kind: data.kind.present ? data.kind.value : this.kind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRevisionEntity(')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('bookId: $bookId, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    kind,
    entityId,
    bookId,
    modifiedAt,
    deviceId,
    deleted,
    payload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRevisionEntity &&
          other.kind == this.kind &&
          other.entityId == this.entityId &&
          other.bookId == this.bookId &&
          other.modifiedAt == this.modifiedAt &&
          other.deviceId == this.deviceId &&
          other.deleted == this.deleted &&
          other.payload == this.payload);
}

class SyncRevisionsCompanion extends UpdateCompanion<SyncRevisionEntity> {
  final Value<String> kind;
  final Value<String> entityId;
  final Value<String> bookId;
  final Value<int> modifiedAt;
  final Value<String> deviceId;
  final Value<bool> deleted;
  final Value<String> payload;
  final Value<int> rowid;
  const SyncRevisionsCompanion({
    this.kind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deleted = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRevisionsCompanion.insert({
    required String kind,
    required String entityId,
    required String bookId,
    required int modifiedAt,
    required String deviceId,
    this.deleted = const Value.absent(),
    required String payload,
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       entityId = Value(entityId),
       bookId = Value(bookId),
       modifiedAt = Value(modifiedAt),
       deviceId = Value(deviceId),
       payload = Value(payload);
  static Insertable<SyncRevisionEntity> custom({
    Expression<String>? kind,
    Expression<String>? entityId,
    Expression<String>? bookId,
    Expression<int>? modifiedAt,
    Expression<String>? deviceId,
    Expression<bool>? deleted,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (entityId != null) 'entity_id': entityId,
      if (bookId != null) 'book_id': bookId,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deleted != null) 'deleted': deleted,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRevisionsCompanion copyWith({
    Value<String>? kind,
    Value<String>? entityId,
    Value<String>? bookId,
    Value<int>? modifiedAt,
    Value<String>? deviceId,
    Value<bool>? deleted,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return SyncRevisionsCompanion(
      kind: kind ?? this.kind,
      entityId: entityId ?? this.entityId,
      bookId: bookId ?? this.bookId,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      deviceId: deviceId ?? this.deviceId,
      deleted: deleted ?? this.deleted,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<int>(modifiedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRevisionsCompanion(')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('bookId: $bookId, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deleted: $deleted, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncIdentitiesTable extends SyncIdentities
    with TableInfo<$SyncIdentitiesTable, SyncIdentityEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncIdentitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clockMeta = const VerificationMeta('clock');
  @override
  late final GeneratedColumn<int> clock = GeneratedColumn<int>(
    'clock',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, deviceId, clock];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_identities';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncIdentityEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('clock')) {
      context.handle(
        _clockMeta,
        clock.isAcceptableOrUnknown(data['clock']!, _clockMeta),
      );
    } else if (isInserting) {
      context.missing(_clockMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncIdentityEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncIdentityEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      clock: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clock'],
      )!,
    );
  }

  @override
  $SyncIdentitiesTable createAlias(String alias) {
    return $SyncIdentitiesTable(attachedDatabase, alias);
  }
}

class SyncIdentityEntity extends DataClass
    implements Insertable<SyncIdentityEntity> {
  final int id;
  final String deviceId;
  final int clock;
  const SyncIdentityEntity({
    required this.id,
    required this.deviceId,
    required this.clock,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['clock'] = Variable<int>(clock);
    return map;
  }

  SyncIdentitiesCompanion toCompanion(bool nullToAbsent) {
    return SyncIdentitiesCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      clock: Value(clock),
    );
  }

  factory SyncIdentityEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncIdentityEntity(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      clock: serializer.fromJson<int>(json['clock']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'clock': serializer.toJson<int>(clock),
    };
  }

  SyncIdentityEntity copyWith({int? id, String? deviceId, int? clock}) =>
      SyncIdentityEntity(
        id: id ?? this.id,
        deviceId: deviceId ?? this.deviceId,
        clock: clock ?? this.clock,
      );
  SyncIdentityEntity copyWithCompanion(SyncIdentitiesCompanion data) {
    return SyncIdentityEntity(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      clock: data.clock.present ? data.clock.value : this.clock,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncIdentityEntity(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('clock: $clock')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, deviceId, clock);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncIdentityEntity &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.clock == this.clock);
}

class SyncIdentitiesCompanion extends UpdateCompanion<SyncIdentityEntity> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<int> clock;
  const SyncIdentitiesCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.clock = const Value.absent(),
  });
  SyncIdentitiesCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    required int clock,
  }) : deviceId = Value(deviceId),
       clock = Value(clock);
  static Insertable<SyncIdentityEntity> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<int>? clock,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (clock != null) 'clock': clock,
    });
  }

  SyncIdentitiesCompanion copyWith({
    Value<int>? id,
    Value<String>? deviceId,
    Value<int>? clock,
  }) {
    return SyncIdentitiesCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      clock: clock ?? this.clock,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (clock.present) {
      map['clock'] = Variable<int>(clock.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncIdentitiesCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('clock: $clock')
          ..write(')'))
        .toString();
  }
}

class $SyncExcludedBooksTable extends SyncExcludedBooks
    with TableInfo<$SyncExcludedBooksTable, SyncExcludedBookEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncExcludedBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookHashMeta = const VerificationMeta(
    'bookHash',
  );
  @override
  late final GeneratedColumn<String> bookHash = GeneratedColumn<String>(
    'book_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookHash];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_excluded_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncExcludedBookEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_hash')) {
      context.handle(
        _bookHashMeta,
        bookHash.isAcceptableOrUnknown(data['book_hash']!, _bookHashMeta),
      );
    } else if (isInserting) {
      context.missing(_bookHashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookHash};
  @override
  SyncExcludedBookEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncExcludedBookEntity(
      bookHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_hash'],
      )!,
    );
  }

  @override
  $SyncExcludedBooksTable createAlias(String alias) {
    return $SyncExcludedBooksTable(attachedDatabase, alias);
  }
}

class SyncExcludedBookEntity extends DataClass
    implements Insertable<SyncExcludedBookEntity> {
  final String bookHash;
  const SyncExcludedBookEntity({required this.bookHash});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_hash'] = Variable<String>(bookHash);
    return map;
  }

  SyncExcludedBooksCompanion toCompanion(bool nullToAbsent) {
    return SyncExcludedBooksCompanion(bookHash: Value(bookHash));
  }

  factory SyncExcludedBookEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncExcludedBookEntity(
      bookHash: serializer.fromJson<String>(json['bookHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'bookHash': serializer.toJson<String>(bookHash)};
  }

  SyncExcludedBookEntity copyWith({String? bookHash}) =>
      SyncExcludedBookEntity(bookHash: bookHash ?? this.bookHash);
  SyncExcludedBookEntity copyWithCompanion(SyncExcludedBooksCompanion data) {
    return SyncExcludedBookEntity(
      bookHash: data.bookHash.present ? data.bookHash.value : this.bookHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncExcludedBookEntity(')
          ..write('bookHash: $bookHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => bookHash.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncExcludedBookEntity && other.bookHash == this.bookHash);
}

class SyncExcludedBooksCompanion
    extends UpdateCompanion<SyncExcludedBookEntity> {
  final Value<String> bookHash;
  final Value<int> rowid;
  const SyncExcludedBooksCompanion({
    this.bookHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncExcludedBooksCompanion.insert({
    required String bookHash,
    this.rowid = const Value.absent(),
  }) : bookHash = Value(bookHash);
  static Insertable<SyncExcludedBookEntity> custom({
    Expression<String>? bookHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookHash != null) 'book_hash': bookHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncExcludedBooksCompanion copyWith({
    Value<String>? bookHash,
    Value<int>? rowid,
  }) {
    return SyncExcludedBooksCompanion(
      bookHash: bookHash ?? this.bookHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookHash.present) {
      map['book_hash'] = Variable<String>(bookHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncExcludedBooksCompanion(')
          ..write('bookHash: $bookHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $ReadingProgressesTable readingProgresses =
      $ReadingProgressesTable(this);
  late final $HighlightsTable highlights = $HighlightsTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $SyncRevisionsTable syncRevisions = $SyncRevisionsTable(this);
  late final $SyncIdentitiesTable syncIdentities = $SyncIdentitiesTable(this);
  late final $SyncExcludedBooksTable syncExcludedBooks =
      $SyncExcludedBooksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    readingProgresses,
    highlights,
    bookmarks,
    syncRevisions,
    syncIdentities,
    syncExcludedBooks,
  ];
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      required String id,
      required String title,
      Value<String> author,
      required String format,
      Value<String?> coverUrl,
      Value<String?> fileUrl,
      required DateTime createdAt,
      Value<int> pageCount,
      Value<int> fileSizeBytes,
      Value<String?> contentHash,
      Value<bool> isSaved,
      Value<int> rowid,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> author,
      Value<String> format,
      Value<String?> coverUrl,
      Value<String?> fileUrl,
      Value<DateTime> createdAt,
      Value<int> pageCount,
      Value<int> fileSizeBytes,
      Value<String?> contentHash,
      Value<bool> isSaved,
      Value<int> rowid,
    });

final class $$BooksTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTable, BookEntity> {
  $$BooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $ReadingProgressesTable,
    List<ReadingProgressEntity>
  >
  _readingProgressesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.readingProgresses,
        aliasName: $_aliasNameGenerator(
          db.books.id,
          db.readingProgresses.bookId,
        ),
      );

  $$ReadingProgressesTableProcessedTableManager get readingProgressesRefs {
    final manager = $$ReadingProgressesTableTableManager(
      $_db,
      $_db.readingProgresses,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _readingProgressesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HighlightsTable, List<HighlightEntity>>
  _highlightsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.highlights,
    aliasName: $_aliasNameGenerator(db.books.id, db.highlights.bookId),
  );

  $$HighlightsTableProcessedTableManager get highlightsRefs {
    final manager = $$HighlightsTableTableManager(
      $_db,
      $_db.highlights,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_highlightsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookmarksTable, List<BookmarkEntity>>
  _bookmarksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookmarks,
    aliasName: $_aliasNameGenerator(db.books.id, db.bookmarks.bookId),
  );

  $$BookmarksTableProcessedTableManager get bookmarksRefs {
    final manager = $$BookmarksTableTableManager(
      $_db,
      $_db.bookmarks,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookmarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileUrl => $composableBuilder(
    column: $table.fileUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSaved => $composableBuilder(
    column: $table.isSaved,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> readingProgressesRefs(
    Expression<bool> Function($$ReadingProgressesTableFilterComposer f) f,
  ) {
    final $$ReadingProgressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingProgresses,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingProgressesTableFilterComposer(
            $db: $db,
            $table: $db.readingProgresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> highlightsRefs(
    Expression<bool> Function($$HighlightsTableFilterComposer f) f,
  ) {
    final $$HighlightsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.highlights,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HighlightsTableFilterComposer(
            $db: $db,
            $table: $db.highlights,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookmarksRefs(
    Expression<bool> Function($$BookmarksTableFilterComposer f) f,
  ) {
    final $$BookmarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableFilterComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileUrl => $composableBuilder(
    column: $table.fileUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSaved => $composableBuilder(
    column: $table.isSaved,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get fileUrl =>
      $composableBuilder(column: $table.fileUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSaved =>
      $composableBuilder(column: $table.isSaved, builder: (column) => column);

  Expression<T> readingProgressesRefs<T extends Object>(
    Expression<T> Function($$ReadingProgressesTableAnnotationComposer a) f,
  ) {
    final $$ReadingProgressesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.readingProgresses,
          getReferencedColumn: (t) => t.bookId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ReadingProgressesTableAnnotationComposer(
                $db: $db,
                $table: $db.readingProgresses,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> highlightsRefs<T extends Object>(
    Expression<T> Function($$HighlightsTableAnnotationComposer a) f,
  ) {
    final $$HighlightsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.highlights,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HighlightsTableAnnotationComposer(
            $db: $db,
            $table: $db.highlights,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookmarksRefs<T extends Object>(
    Expression<T> Function($$BookmarksTableAnnotationComposer a) f,
  ) {
    final $$BookmarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableAnnotationComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          BookEntity,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (BookEntity, $$BooksTableReferences),
          BookEntity,
          PrefetchHooks Function({
            bool readingProgressesRefs,
            bool highlightsRefs,
            bool bookmarksRefs,
          })
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> fileUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<int> fileSizeBytes = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<bool> isSaved = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                title: title,
                author: author,
                format: format,
                coverUrl: coverUrl,
                fileUrl: fileUrl,
                createdAt: createdAt,
                pageCount: pageCount,
                fileSizeBytes: fileSizeBytes,
                contentHash: contentHash,
                isSaved: isSaved,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> author = const Value.absent(),
                required String format,
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> fileUrl = const Value.absent(),
                required DateTime createdAt,
                Value<int> pageCount = const Value.absent(),
                Value<int> fileSizeBytes = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<bool> isSaved = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                title: title,
                author: author,
                format: format,
                coverUrl: coverUrl,
                fileUrl: fileUrl,
                createdAt: createdAt,
                pageCount: pageCount,
                fileSizeBytes: fileSizeBytes,
                contentHash: contentHash,
                isSaved: isSaved,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BooksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                readingProgressesRefs = false,
                highlightsRefs = false,
                bookmarksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (readingProgressesRefs) db.readingProgresses,
                    if (highlightsRefs) db.highlights,
                    if (bookmarksRefs) db.bookmarks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (readingProgressesRefs)
                        await $_getPrefetchedData<
                          BookEntity,
                          $BooksTable,
                          ReadingProgressEntity
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._readingProgressesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).readingProgressesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (highlightsRefs)
                        await $_getPrefetchedData<
                          BookEntity,
                          $BooksTable,
                          HighlightEntity
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._highlightsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).highlightsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookmarksRefs)
                        await $_getPrefetchedData<
                          BookEntity,
                          $BooksTable,
                          BookmarkEntity
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._bookmarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).bookmarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      BookEntity,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (BookEntity, $$BooksTableReferences),
      BookEntity,
      PrefetchHooks Function({
        bool readingProgressesRefs,
        bool highlightsRefs,
        bool bookmarksRefs,
      })
    >;
typedef $$ReadingProgressesTableCreateCompanionBuilder =
    ReadingProgressesCompanion Function({
      required String bookId,
      required double percentage,
      required String location,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ReadingProgressesTableUpdateCompanionBuilder =
    ReadingProgressesCompanion Function({
      Value<String> bookId,
      Value<double> percentage,
      Value<String> location,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ReadingProgressesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressesTable,
          ReadingProgressEntity
        > {
  $$ReadingProgressesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTable _bookIdTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.readingProgresses.bookId, db.books.id),
  );

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressesTable,
          ReadingProgressEntity,
          $$ReadingProgressesTableFilterComposer,
          $$ReadingProgressesTableOrderingComposer,
          $$ReadingProgressesTableAnnotationComposer,
          $$ReadingProgressesTableCreateCompanionBuilder,
          $$ReadingProgressesTableUpdateCompanionBuilder,
          (ReadingProgressEntity, $$ReadingProgressesTableReferences),
          ReadingProgressEntity,
          PrefetchHooks Function({bool bookId})
        > {
  $$ReadingProgressesTableTableManager(
    _$AppDatabase db,
    $ReadingProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<double> percentage = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressesCompanion(
                bookId: bookId,
                percentage: percentage,
                location: location,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required double percentage,
                required String location,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressesCompanion.insert(
                bookId: bookId,
                percentage: percentage,
                location: location,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReadingProgressesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable:
                                    $$ReadingProgressesTableReferences
                                        ._bookIdTable(db),
                                referencedColumn:
                                    $$ReadingProgressesTableReferences
                                        ._bookIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReadingProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressesTable,
      ReadingProgressEntity,
      $$ReadingProgressesTableFilterComposer,
      $$ReadingProgressesTableOrderingComposer,
      $$ReadingProgressesTableAnnotationComposer,
      $$ReadingProgressesTableCreateCompanionBuilder,
      $$ReadingProgressesTableUpdateCompanionBuilder,
      (ReadingProgressEntity, $$ReadingProgressesTableReferences),
      ReadingProgressEntity,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$HighlightsTableCreateCompanionBuilder =
    HighlightsCompanion Function({
      required String id,
      required String bookId,
      required String textContent,
      Value<String> color,
      required String location,
      Value<String?> note,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$HighlightsTableUpdateCompanionBuilder =
    HighlightsCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> textContent,
      Value<String> color,
      Value<String> location,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$HighlightsTableReferences
    extends BaseReferences<_$AppDatabase, $HighlightsTable, HighlightEntity> {
  $$HighlightsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.highlights.bookId, db.books.id),
  );

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HighlightsTableFilterComposer
    extends Composer<_$AppDatabase, $HighlightsTable> {
  $$HighlightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HighlightsTableOrderingComposer
    extends Composer<_$AppDatabase, $HighlightsTable> {
  $$HighlightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HighlightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HighlightsTable> {
  $$HighlightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HighlightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HighlightsTable,
          HighlightEntity,
          $$HighlightsTableFilterComposer,
          $$HighlightsTableOrderingComposer,
          $$HighlightsTableAnnotationComposer,
          $$HighlightsTableCreateCompanionBuilder,
          $$HighlightsTableUpdateCompanionBuilder,
          (HighlightEntity, $$HighlightsTableReferences),
          HighlightEntity,
          PrefetchHooks Function({bool bookId})
        > {
  $$HighlightsTableTableManager(_$AppDatabase db, $HighlightsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HighlightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HighlightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HighlightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> textContent = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HighlightsCompanion(
                id: id,
                bookId: bookId,
                textContent: textContent,
                color: color,
                location: location,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String textContent,
                Value<String> color = const Value.absent(),
                required String location,
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => HighlightsCompanion.insert(
                id: id,
                bookId: bookId,
                textContent: textContent,
                color: color,
                location: location,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HighlightsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable: $$HighlightsTableReferences
                                    ._bookIdTable(db),
                                referencedColumn: $$HighlightsTableReferences
                                    ._bookIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HighlightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HighlightsTable,
      HighlightEntity,
      $$HighlightsTableFilterComposer,
      $$HighlightsTableOrderingComposer,
      $$HighlightsTableAnnotationComposer,
      $$HighlightsTableCreateCompanionBuilder,
      $$HighlightsTableUpdateCompanionBuilder,
      (HighlightEntity, $$HighlightsTableReferences),
      HighlightEntity,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      required String id,
      required String bookId,
      required String location,
      required double percentage,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> location,
      Value<double> percentage,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$BookmarksTableReferences
    extends BaseReferences<_$AppDatabase, $BookmarksTable, BookmarkEntity> {
  $$BookmarksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.bookmarks.bookId, db.books.id),
  );

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          BookmarkEntity,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (BookmarkEntity, $$BookmarksTableReferences),
          BookmarkEntity,
          PrefetchHooks Function({bool bookId})
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<double> percentage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                bookId: bookId,
                location: location,
                percentage: percentage,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String location,
                required double percentage,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                location: location,
                percentage: percentage,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookmarksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable: $$BookmarksTableReferences
                                    ._bookIdTable(db),
                                referencedColumn: $$BookmarksTableReferences
                                    ._bookIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      BookmarkEntity,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (BookmarkEntity, $$BookmarksTableReferences),
      BookmarkEntity,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$SyncRevisionsTableCreateCompanionBuilder =
    SyncRevisionsCompanion Function({
      required String kind,
      required String entityId,
      required String bookId,
      required int modifiedAt,
      required String deviceId,
      Value<bool> deleted,
      required String payload,
      Value<int> rowid,
    });
typedef $$SyncRevisionsTableUpdateCompanionBuilder =
    SyncRevisionsCompanion Function({
      Value<String> kind,
      Value<String> entityId,
      Value<String> bookId,
      Value<int> modifiedAt,
      Value<String> deviceId,
      Value<bool> deleted,
      Value<String> payload,
      Value<int> rowid,
    });

class $$SyncRevisionsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRevisionsTable> {
  $$SyncRevisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncRevisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRevisionsTable> {
  $$SyncRevisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncRevisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRevisionsTable> {
  $$SyncRevisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$SyncRevisionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncRevisionsTable,
          SyncRevisionEntity,
          $$SyncRevisionsTableFilterComposer,
          $$SyncRevisionsTableOrderingComposer,
          $$SyncRevisionsTableAnnotationComposer,
          $$SyncRevisionsTableCreateCompanionBuilder,
          $$SyncRevisionsTableUpdateCompanionBuilder,
          (
            SyncRevisionEntity,
            BaseReferences<
              _$AppDatabase,
              $SyncRevisionsTable,
              SyncRevisionEntity
            >,
          ),
          SyncRevisionEntity,
          PrefetchHooks Function()
        > {
  $$SyncRevisionsTableTableManager(_$AppDatabase db, $SyncRevisionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRevisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRevisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRevisionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> modifiedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRevisionsCompanion(
                kind: kind,
                entityId: entityId,
                bookId: bookId,
                modifiedAt: modifiedAt,
                deviceId: deviceId,
                deleted: deleted,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String entityId,
                required String bookId,
                required int modifiedAt,
                required String deviceId,
                Value<bool> deleted = const Value.absent(),
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => SyncRevisionsCompanion.insert(
                kind: kind,
                entityId: entityId,
                bookId: bookId,
                modifiedAt: modifiedAt,
                deviceId: deviceId,
                deleted: deleted,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncRevisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncRevisionsTable,
      SyncRevisionEntity,
      $$SyncRevisionsTableFilterComposer,
      $$SyncRevisionsTableOrderingComposer,
      $$SyncRevisionsTableAnnotationComposer,
      $$SyncRevisionsTableCreateCompanionBuilder,
      $$SyncRevisionsTableUpdateCompanionBuilder,
      (
        SyncRevisionEntity,
        BaseReferences<_$AppDatabase, $SyncRevisionsTable, SyncRevisionEntity>,
      ),
      SyncRevisionEntity,
      PrefetchHooks Function()
    >;
typedef $$SyncIdentitiesTableCreateCompanionBuilder =
    SyncIdentitiesCompanion Function({
      Value<int> id,
      required String deviceId,
      required int clock,
    });
typedef $$SyncIdentitiesTableUpdateCompanionBuilder =
    SyncIdentitiesCompanion Function({
      Value<int> id,
      Value<String> deviceId,
      Value<int> clock,
    });

class $$SyncIdentitiesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncIdentitiesTable> {
  $$SyncIdentitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clock => $composableBuilder(
    column: $table.clock,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncIdentitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncIdentitiesTable> {
  $$SyncIdentitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clock => $composableBuilder(
    column: $table.clock,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncIdentitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncIdentitiesTable> {
  $$SyncIdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get clock =>
      $composableBuilder(column: $table.clock, builder: (column) => column);
}

class $$SyncIdentitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncIdentitiesTable,
          SyncIdentityEntity,
          $$SyncIdentitiesTableFilterComposer,
          $$SyncIdentitiesTableOrderingComposer,
          $$SyncIdentitiesTableAnnotationComposer,
          $$SyncIdentitiesTableCreateCompanionBuilder,
          $$SyncIdentitiesTableUpdateCompanionBuilder,
          (
            SyncIdentityEntity,
            BaseReferences<
              _$AppDatabase,
              $SyncIdentitiesTable,
              SyncIdentityEntity
            >,
          ),
          SyncIdentityEntity,
          PrefetchHooks Function()
        > {
  $$SyncIdentitiesTableTableManager(
    _$AppDatabase db,
    $SyncIdentitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncIdentitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncIdentitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncIdentitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> clock = const Value.absent(),
              }) => SyncIdentitiesCompanion(
                id: id,
                deviceId: deviceId,
                clock: clock,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String deviceId,
                required int clock,
              }) => SyncIdentitiesCompanion.insert(
                id: id,
                deviceId: deviceId,
                clock: clock,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncIdentitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncIdentitiesTable,
      SyncIdentityEntity,
      $$SyncIdentitiesTableFilterComposer,
      $$SyncIdentitiesTableOrderingComposer,
      $$SyncIdentitiesTableAnnotationComposer,
      $$SyncIdentitiesTableCreateCompanionBuilder,
      $$SyncIdentitiesTableUpdateCompanionBuilder,
      (
        SyncIdentityEntity,
        BaseReferences<_$AppDatabase, $SyncIdentitiesTable, SyncIdentityEntity>,
      ),
      SyncIdentityEntity,
      PrefetchHooks Function()
    >;
typedef $$SyncExcludedBooksTableCreateCompanionBuilder =
    SyncExcludedBooksCompanion Function({
      required String bookHash,
      Value<int> rowid,
    });
typedef $$SyncExcludedBooksTableUpdateCompanionBuilder =
    SyncExcludedBooksCompanion Function({
      Value<String> bookHash,
      Value<int> rowid,
    });

class $$SyncExcludedBooksTableFilterComposer
    extends Composer<_$AppDatabase, $SyncExcludedBooksTable> {
  $$SyncExcludedBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookHash => $composableBuilder(
    column: $table.bookHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncExcludedBooksTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncExcludedBooksTable> {
  $$SyncExcludedBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookHash => $composableBuilder(
    column: $table.bookHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncExcludedBooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncExcludedBooksTable> {
  $$SyncExcludedBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookHash =>
      $composableBuilder(column: $table.bookHash, builder: (column) => column);
}

class $$SyncExcludedBooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncExcludedBooksTable,
          SyncExcludedBookEntity,
          $$SyncExcludedBooksTableFilterComposer,
          $$SyncExcludedBooksTableOrderingComposer,
          $$SyncExcludedBooksTableAnnotationComposer,
          $$SyncExcludedBooksTableCreateCompanionBuilder,
          $$SyncExcludedBooksTableUpdateCompanionBuilder,
          (
            SyncExcludedBookEntity,
            BaseReferences<
              _$AppDatabase,
              $SyncExcludedBooksTable,
              SyncExcludedBookEntity
            >,
          ),
          SyncExcludedBookEntity,
          PrefetchHooks Function()
        > {
  $$SyncExcludedBooksTableTableManager(
    _$AppDatabase db,
    $SyncExcludedBooksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncExcludedBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncExcludedBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncExcludedBooksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  SyncExcludedBooksCompanion(bookHash: bookHash, rowid: rowid),
          createCompanionCallback:
              ({
                required String bookHash,
                Value<int> rowid = const Value.absent(),
              }) => SyncExcludedBooksCompanion.insert(
                bookHash: bookHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncExcludedBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncExcludedBooksTable,
      SyncExcludedBookEntity,
      $$SyncExcludedBooksTableFilterComposer,
      $$SyncExcludedBooksTableOrderingComposer,
      $$SyncExcludedBooksTableAnnotationComposer,
      $$SyncExcludedBooksTableCreateCompanionBuilder,
      $$SyncExcludedBooksTableUpdateCompanionBuilder,
      (
        SyncExcludedBookEntity,
        BaseReferences<
          _$AppDatabase,
          $SyncExcludedBooksTable,
          SyncExcludedBookEntity
        >,
      ),
      SyncExcludedBookEntity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$ReadingProgressesTableTableManager get readingProgresses =>
      $$ReadingProgressesTableTableManager(_db, _db.readingProgresses);
  $$HighlightsTableTableManager get highlights =>
      $$HighlightsTableTableManager(_db, _db.highlights);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$SyncRevisionsTableTableManager get syncRevisions =>
      $$SyncRevisionsTableTableManager(_db, _db.syncRevisions);
  $$SyncIdentitiesTableTableManager get syncIdentities =>
      $$SyncIdentitiesTableTableManager(_db, _db.syncIdentities);
  $$SyncExcludedBooksTableTableManager get syncExcludedBooks =>
      $$SyncExcludedBooksTableTableManager(_db, _db.syncExcludedBooks);
}
