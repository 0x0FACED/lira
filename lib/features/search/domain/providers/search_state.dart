import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:annas_archive_api/annas_archive_api.dart' as anna;

part 'search_state.freezed.dart';

@freezed
class SearchState with _$SearchState {
  const factory SearchState.initial() = _Initial;
  const factory SearchState.loading() = _Loading;
  const factory SearchState.loaded(List<anna.Book> books) = _Loaded;
  const factory SearchState.error(String message) = _Error;
}
