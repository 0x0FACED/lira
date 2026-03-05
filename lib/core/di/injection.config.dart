// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/books/data/repositories/books_local_repository.dart'
    as _i12;
import '../../features/highlights/data/repositories/highlights_local_repository.dart'
    as _i1036;
import '../../features/progress/data/repositories/reading_progress_local_repository.dart'
    as _i59;
import '../database/app_database.dart' as _i982;
import '../network/api_client.dart' as _i557;
import '../network/dio_module.dart' as _i614;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final dioModule = _$DioModule();
    gh.lazySingleton<_i982.AppDatabase>(() => _i982.AppDatabase());
    gh.lazySingleton<_i361.Dio>(() => dioModule.dio);
    gh.lazySingleton<_i557.ApiClient>(() => _i557.ApiClient(gh<_i361.Dio>()));
    gh.factory<_i12.BooksLocalRepository>(
      () => _i12.BooksLocalRepository(gh<_i982.AppDatabase>()),
    );
    gh.factory<_i1036.HighlightsLocalRepository>(
      () => _i1036.HighlightsLocalRepository(gh<_i982.AppDatabase>()),
    );
    gh.factory<_i59.ReadingProgressLocalRepository>(
      () => _i59.ReadingProgressLocalRepository(gh<_i982.AppDatabase>()),
    );
    return this;
  }
}

class _$DioModule extends _i614.DioModule {}
