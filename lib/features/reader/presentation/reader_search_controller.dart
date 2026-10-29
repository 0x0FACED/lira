import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/engine/book_reader_engine.dart';
import '../domain/models/book_search.dart';

/// One transient search session; never writes progress or annotations.
class ReaderSearchController extends ChangeNotifier {
  ReaderSearchController(this._engine);

  final BookReaderEngine _engine;
  Timer? _debounce;
  BookSearchRequest? _request;
  bool _disposed = false;
  String query = '';
  List<BookSearchMatch> matches = const [];
  int activeIndex = -1;
  bool isSearching = false;
  bool hasSearched = false;
  bool hasText = true;
  Object? error;

  BookSearchMatch? get activeMatch =>
      activeIndex >= 0 && activeIndex < matches.length
      ? matches[activeIndex]
      : null;

  void updateQuery(String value) {
    final next = value.trim();
    if (next == query) return;
    _cancelPending();
    query = next;
    matches = const [];
    activeIndex = -1;
    hasSearched = false;
    hasText = true;
    error = null;
    isSearching = next.isNotEmpty;
    notifyListeners();
    if (next.isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 250), searchNow);
    }
  }

  Future<void> searchNow() async {
    _cancelPending();
    if (_disposed || query.isEmpty) return;
    final request = BookSearchRequest(query);
    _request = request;
    isSearching = true;
    error = null;
    notifyListeners();
    try {
      final result = await _engine.search(request);
      if (!_isCurrent(request)) return;
      matches = result.matches;
      hasText = result.hasText;
      activeIndex = -1;
      hasSearched = true;
    } catch (failure) {
      if (!_isCurrent(request)) return;
      matches = const [];
      activeIndex = -1;
      error = failure;
      hasSearched = true;
    } finally {
      if (_isCurrent(request)) {
        isSearching = false;
        _request = null;
        notifyListeners();
      }
    }
  }

  bool _isCurrent(BookSearchRequest request) =>
      !_disposed && identical(_request, request) && !request.isCancelled;

  void select(int index) {
    if (_disposed || isSearching || index < 0 || index >= matches.length)
      return;
    activeIndex = index;
    notifyListeners();
  }

  void clear() {
    _cancelPending();
    query = '';
    matches = const [];
    activeIndex = -1;
    isSearching = false;
    hasSearched = false;
    hasText = true;
    error = null;
    notifyListeners();
  }

  void _cancelPending() {
    _debounce?.cancel();
    _debounce = null;
    _request?.cancel();
    _request = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelPending();
    super.dispose();
  }
}
