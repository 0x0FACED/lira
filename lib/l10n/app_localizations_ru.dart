// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Lira';

  @override
  String get signIn => 'Войти';

  @override
  String get register => 'Регистрация';

  @override
  String get username => 'Имя пользователя';

  @override
  String get password => 'Пароль';

  @override
  String get continueAsGuest => 'Продолжить как гость';

  @override
  String get guestLocalOnly =>
      'Книги и прогресс будут храниться только локально';

  @override
  String get noAccountRegister => 'Нет аккаунта? Зарегистрируйтесь';

  @override
  String get haveAccountSignIn => 'Уже есть аккаунт? Войти';

  @override
  String get yourLibrary => 'Ваша персональная библиотека';

  @override
  String get fillAllFields => 'Пожалуйста, заполните все поля';

  @override
  String get library => 'Библиотека';

  @override
  String get search => 'Поиск';

  @override
  String get settings => 'Настройки';

  @override
  String get noBooks => 'В библиотеке нет книг';

  @override
  String get noBooksHint => 'Нажмите + чтобы добавить первую книгу';

  @override
  String get importBook => 'Импорт книги';

  @override
  String get deleteBook => 'Удалить книгу';

  @override
  String deleteBookConfirm(String title) {
    return 'Вы уверены, что хотите удалить $title?';
  }

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get readBook => 'Читать';

  @override
  String get openBook => 'Открыть';

  @override
  String get duplicateBookError => 'Эта книга уже есть в вашей библиотеке.';

  @override
  String get searchBooks => 'Поиск книг';

  @override
  String get searchBooksHint =>
      'Поиск книг онлайн будет доступен в следующем обновлении.\nВы сможете искать в z-library и скачивать книги прямо в приложение.';

  @override
  String get profile => 'Профиль';

  @override
  String get signedIn => 'Авторизован';

  @override
  String get guest => 'Гость';

  @override
  String get guestSyncHint => 'Только локально — войдите для синхронизации';

  @override
  String get notSignedIn => 'Не авторизован';

  @override
  String get account => 'Аккаунт';

  @override
  String get logout => 'Выйти';

  @override
  String get signInComingSoon => 'Вход скоро будет доступен';

  @override
  String get registrationComingSoon => 'Регистрация скоро будет доступна';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get theme => 'Тема';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get language => 'Язык';

  @override
  String get languageEn => 'Русский';

  @override
  String get themeComingSoon => 'Переключение темы скоро будет доступно';

  @override
  String get languageComingSoon => 'Выбор языка скоро будет доступен';

  @override
  String get about => 'О приложении';

  @override
  String get version => 'Версия';

  @override
  String get editBook => 'Редактировать';

  @override
  String get editBookTitle => 'Название';

  @override
  String get editBookAuthor => 'Автор';

  @override
  String get save => 'Сохранить';

  @override
  String get details => 'Информация';

  @override
  String get size => 'Размер';

  @override
  String get pages => 'Страниц';

  @override
  String get added => 'Добавлена';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get tableOfContents => 'Оглавление';

  @override
  String get tocComingSoon =>
      'Оглавление будет доступно в следующем обновлении.';

  @override
  String get readerSettings => 'Настройки чтения';

  @override
  String get readerSettingsHint =>
      'Размер шрифта, тема и другие настройки будут доступны в следующем обновлении.';

  @override
  String get readerVertical => 'Вертикально';

  @override
  String get readerHorizontal => 'Горизонтально';

  @override
  String get readerFont => 'Шрифт';

  @override
  String get readerTwoPageSpread => 'Разворот на 2 страницы';

  @override
  String get highlightSaved => 'Выделение сохранено';

  @override
  String get errorLoadingBook => 'Ошибка загрузки книги';

  @override
  String get errorLoadingProgress => 'Ошибка загрузки прогресса';

  @override
  String get failedToInitReader => 'Не удалось инициализировать движок чтения.';

  @override
  String get noChapters => 'В этом EPUB нет доступных глав.';

  @override
  String get searchLibrary => 'Поиск по библиотеке...';

  @override
  String get downloadCancelled => 'Загрузка отменена';

  @override
  String get zLibrary => 'Z-Library';

  @override
  String get zLibraryLogin => 'Вход в Z-Library';

  @override
  String get zLibraryEmail => 'Email';

  @override
  String get zLibraryPassword => 'Пароль';

  @override
  String zLibraryLoggedIn(String email) {
    return 'Вошли как $email';
  }

  @override
  String get zLibraryNotLoggedIn => 'Нет входа в Z-Library';

  @override
  String get zLibraryLogout => 'Выйти';

  @override
  String get themeLight => 'Светлая';

  @override
  String get proxyHost => 'Хост';

  @override
  String get proxyPort => 'Порт';

  @override
  String get proxyDisabled => 'Выключен';

  @override
  String get searchBothSources => 'Оба источника';

  @override
  String get searchAllFormats => 'Все форматы';

  @override
  String get searchSort => 'Сортировка';

  @override
  String get searchSortRelevance => 'По релевантности';

  @override
  String get searchSortTitleAsc => 'Название: А—Я';

  @override
  String get searchSortTitleDesc => 'Название: Я—А';

  @override
  String get searchSortAuthorAsc => 'Автор: А—Я';

  @override
  String get searchLoading => 'Ищем на книжных полках…';

  @override
  String get searchNoResults => 'Книги не найдены';

  @override
  String get searchNoFilterResults => 'Нет книг с такими фильтрами';

  @override
  String get searchResetFilters => 'Сбросить фильтры';

  @override
  String get searchFailed => 'Поиск недоступен';

  @override
  String get searchRetry => 'Попробовать снова';

  @override
  String get searchSourcesPartialFailure =>
      'Часть источников недоступна. Показываем то, что удалось найти.';

  @override
  String get cancelDownload => 'Отменить загрузку';

  @override
  String get downloadBook => 'Скачать книгу';

  @override
  String get searchAnnaDescription =>
      'Ищите книги по названию, автору или ISBN в Anna’s Archive.';

  @override
  String get searchZLibraryDescription =>
      'Найдите следующую книгу в Z-Library. Для загрузки войдите в аккаунт в настройках.';

  @override
  String get searchBothDescription =>
      'Поиск одновременно в Anna’s Archive и Z-Library.';

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count книги',
      many: '$count книг',
      few: '$count книги',
      one: '$count книга',
    );
    return '$_temp0';
  }

  @override
  String get highlights => 'Выделения';

  @override
  String get highlightsEmpty => 'Выделений пока нет';

  @override
  String get highlightsEmptyHint =>
      'Выделите текст в книге, чтобы сохранить выделение или заметку.';

  @override
  String get highlightsLoadError => 'Не удалось загрузить выделения';

  @override
  String get annotations => 'Заметки и закладки';

  @override
  String get bookmarks => 'Закладки';

  @override
  String get bookmarksEmpty => 'Закладок пока нет';

  @override
  String get bookmarksEmptyHint =>
      'Нажмите кнопку закладки в читалке, чтобы сохранить место чтения.';

  @override
  String get bookmarksLoadError => 'Не удалось загрузить закладки';

  @override
  String bookmarkPosition(String percentage) {
    return 'Позиция: $percentage%';
  }

  @override
  String get addBookmark => 'Добавить закладку';

  @override
  String get removeBookmark => 'Удалить закладку';

  @override
  String bookmarkSaveError(String error) {
    return 'Не удалось сохранить закладку: $error';
  }

  @override
  String bookmarkDeleteError(String error) {
    return 'Не удалось удалить закладку: $error';
  }

  @override
  String highlightDeleteError(String error) {
    return 'Не удалось удалить выделение: $error';
  }

  @override
  String noteSaveError(String error) {
    return 'Не удалось сохранить заметку: $error';
  }

  @override
  String get addNote => 'Добавить заметку';

  @override
  String get editNote => 'Изменить заметку';

  @override
  String get noteHint => 'Ваша заметка…';

  @override
  String get copyText => 'Копировать';

  @override
  String get copied => 'Скопировано';

  @override
  String get highlightText => 'Выделить';

  @override
  String get tableOfContentsUnavailable => 'Оглавление недоступно';

  @override
  String get readerSansSerif => 'Без засечек';

  @override
  String get readerSerif => 'С засечками';

  @override
  String get readerMonospace => 'Моноширинный';

  @override
  String get readerFontSize => 'Размер шрифта';

  @override
  String get readerLineHeight => 'Межстрочный интервал';

  @override
  String get readerPageMargins => 'Отступы страницы';

  @override
  String get readerBrightness => 'Яркость';

  @override
  String get readerBackground => 'Фон страницы';

  @override
  String get readerPaper => 'Тёплая бумага';

  @override
  String get readerNight => 'Ночь';

  @override
  String get readerCharcoal => 'Уголь';

  @override
  String get readerGraphite => 'Графит';

  @override
  String get readerWhite => 'Белый';

  @override
  String get readerSepia => 'Сепия';

  @override
  String readerSavePositionError(String error) {
    return 'Не удалось сохранить позицию чтения: $error';
  }

  @override
  String highlightSaveError(String error) {
    return 'Не удалось сохранить выделение: $error';
  }

  @override
  String bookDownloaded(String title) {
    return '«$title» добавлена в библиотеку';
  }

  @override
  String get updateSection => 'Обновление приложения';

  @override
  String get updateSource => 'Официальные релизы на GitHub';

  @override
  String get updateCheckAction => 'Проверить обновления';

  @override
  String get updateCheckHint => 'Проверьте, доступна ли новая версия Lira.';

  @override
  String get updateChecking => 'Проверяем обновления…';

  @override
  String get updateUpToDate => 'У вас последняя версия.';

  @override
  String updateAvailable(String version) {
    return 'Доступна версия $version';
  }

  @override
  String updateDownloading(String percent, String received, String total) {
    return 'Скачивание: $percent · $received / $total МБ';
  }

  @override
  String updateReady(String version) {
    return 'Версия $version готова к установке';
  }

  @override
  String get updateOpeningInstaller => 'Открываем системный установщик…';

  @override
  String updateDownloadAction(String size) {
    return 'Скачать APK · $size МБ';
  }

  @override
  String get updateInstallAction => 'Установить обновление';

  @override
  String get updateInstallHint =>
      'Android попросит подтвердить установку. Библиотека и настройки сохранятся.';

  @override
  String get updateReleaseAction => 'Открыть релиз на GitHub';

  @override
  String get updateExternalHint =>
      'Скачайте и установите версию для своего устройства со страницы релиза.';

  @override
  String get updateNoApk =>
      'В этом релизе нет APK с проверяемой контрольной суммой. Варианты установки — на странице релиза.';

  @override
  String get updateUnavailable => 'Опубликованных релизов пока нет.';

  @override
  String get updateNetworkError =>
      'Не удалось проверить обновления. Проверьте подключение и попробуйте ещё раз.';

  @override
  String get updateRateLimited =>
      'Достигнут лимит запросов GitHub. Попробуйте позже.';

  @override
  String get updateInvalidRelease => 'Не удалось проверить данные релиза.';

  @override
  String get updateDownloadError =>
      'Не удалось скачать обновление. Попробуйте скачать его ещё раз.';

  @override
  String get updateChecksumError =>
      'Скачанный APK не прошёл проверку. Скачайте его ещё раз.';

  @override
  String get updatePermissionHint =>
      'Разрешите Lira установку из неизвестных источников в настройках Android, затем снова нажмите «Установить обновление».';

  @override
  String get updateSignatureError =>
      'APK подписан другим ключом и не может обновить установленное приложение.';

  @override
  String get updateInvalidApk =>
      'Этот APK не подходит для обновления установленной версии Lira.';

  @override
  String get updateInstallError =>
      'Не удалось открыть установщик Android. Попробуйте ещё раз или откройте страницу релиза.';

  @override
  String get updateReleaseError =>
      'Не удалось открыть страницу релиза в браузере.';
}
