import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/search_result_item.dart';

part 'search_state.freezed.dart';

@freezed
class SearchState with _$SearchState {
  const factory SearchState.initial() = _Initial;
  const factory SearchState.loading() = _Loading;
  const factory SearchState.loaded(List<SearchResultItem> books) = _Loaded;
  const factory SearchState.error(String message, {List<SearchResultItem>? partialResults}) = _Error;
}
