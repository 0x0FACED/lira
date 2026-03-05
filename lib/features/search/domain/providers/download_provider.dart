import 'package:flutter_riverpod/flutter_riverpod.dart';

final downloadNotifierProvider =
    StateNotifierProvider<DownloadNotifier, Map<String, double>>((ref) {
      return DownloadNotifier();
    });

class DownloadNotifier extends StateNotifier<Map<String, double>> {
  DownloadNotifier() : super({});

  void setProgress(String downloadId, double progress) {
    state = {...state, downloadId: progress};
  }

  void finish(String downloadId) {
    final newState = Map<String, double>.from(state);
    newState.remove(downloadId);
    state = newState;
  }
}
