import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final downloadNotifierProvider =
    StateNotifierProvider<DownloadNotifier, Map<String, double>>((ref) {
      return DownloadNotifier();
    });

class DownloadNotifier extends StateNotifier<Map<String, double>> {
  DownloadNotifier() : super({});

  /// Active CancelTokens for ongoing downloads
  final Map<String, CancelToken> _cancelTokens = {};

  /// Set download progress. Use -1 for indeterminate (preparing).
  void setProgress(String downloadId, double progress) {
    state = {...state, downloadId: progress};
  }

  /// Register a CancelToken for a download and return it.
  CancelToken startDownload(String downloadId) {
    final token = CancelToken();
    _cancelTokens[downloadId] = token;
    return token;
  }

  /// Cancel an ongoing download.
  void cancelDownload(String downloadId) {
    final token = _cancelTokens.remove(downloadId);
    if (token != null && !token.isCancelled) {
      token.cancel('User cancelled download');
    }
    final newState = Map<String, double>.from(state);
    newState.remove(downloadId);
    state = newState;
  }

  /// Check if a download is cancellable.
  bool isCancellable(String downloadId) {
    return _cancelTokens.containsKey(downloadId);
  }

  void finish(String downloadId) {
    _cancelTokens.remove(downloadId);
    final newState = Map<String, double>.from(state);
    newState.remove(downloadId);
    state = newState;
  }
}
