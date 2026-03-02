import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

import '../../features/books/domain/models/book_dto.dart';
import '../../features/progress/domain/models/reading_progress_dto.dart';
import '../../features/highlights/domain/models/highlight_dto.dart';

part 'api_client.g.dart';

@RestApi()
@lazySingleton
abstract class ApiClient {
  @factoryMethod
  factory ApiClient(Dio dio) = _ApiClient;

  // --- Auth ---
  @POST('/auth/login')
  Future<Map<String, String>> login(@Body() Map<String, String> credentials);

  @POST('/auth/register')
  Future<Map<String, String>> register(@Body() Map<String, String> credentials);

  // --- Books ---
  @GET('/books')
  Future<List<BookDto>> getBooks();

  @POST('/books')
  Future<BookDto> createBook(@Body() BookDto book);

  @GET('/books/{id}')
  Future<BookDto> getBook(@Path('id') String id);

  @DELETE('/books/{id}')
  Future<void> deleteBook(@Path('id') String id);

  // --- Progress ---
  @GET('/progress')
  Future<List<ReadingProgressDto>> getProgress();

  @PUT('/progress/{book_id}')
  Future<void> syncProgress(
    @Path('book_id') String bookId,
    @Body() ReadingProgressDto progress,
  );

  // --- Highlights ---
  @GET('/highlights')
  Future<List<HighlightDto>> getHighlights();

  @POST('/highlights')
  Future<HighlightDto> createHighlight(@Body() HighlightDto highlight);

  @PUT('/highlights/{id}')
  Future<HighlightDto> updateHighlight(
    @Path('id') String id,
    @Body() HighlightDto highlight,
  );

  @DELETE('/highlights/{id}')
  Future<void> deleteHighlight(@Path('id') String id);
}
