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

  @override
  String get discover => 'Подборка';

  @override
  String get discoverSources => 'Источники';

  @override
  String get discoverSearchHint => 'Поиск книг, статей и RFC';

  @override
  String get discoverSourceSearchHint => 'Поиск в этом источнике';

  @override
  String get discoverSourcesSearchHint => 'Название или описание источника';

  @override
  String get discoverBooks => 'Книги';

  @override
  String get discoverArticles => 'Статьи';

  @override
  String get discoverDocuments => 'RFC';

  @override
  String get discoverSelectedOnly => 'Только выбранные';

  @override
  String get discoverTopic => 'Тема';

  @override
  String get discoverAllTopics => 'Все темы';

  @override
  String get discoverTopicTechnology => 'Технологии';

  @override
  String get discoverTopicEconomics => 'Экономика';

  @override
  String get discoverTopicNature => 'Природа';

  @override
  String get discoverTopicHistory => 'История';

  @override
  String get discoverTopicCulture => 'Культура';

  @override
  String get discoverTopicPsychology => 'Психология';

  @override
  String get discoverTopicScience => 'Наука';

  @override
  String get discoverContentLanguage => 'Язык публикаций';

  @override
  String get discoverAllLanguages => 'Все языки';

  @override
  String get discoverLanguageRussian => 'Русский';

  @override
  String get discoverLanguageEnglish => 'Английский';

  @override
  String get discoverLanguageMultilingual => 'Несколько языков';

  @override
  String discoverSourceTopics(String topics) {
    return 'Темы: $topics';
  }

  @override
  String discoverSourceContentLanguage(String language) {
    return 'Язык публикаций: $language';
  }

  @override
  String discoverSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано $count источника',
      many: 'Выбрано $count источников',
      few: 'Выбрано $count источника',
      one: 'Выбран $count источник',
    );
    return '$_temp0';
  }

  @override
  String discoverSourcePosition(int position) {
    return 'Позиция $position';
  }

  @override
  String get discoverMoveUp => 'Переместить источник выше';

  @override
  String get discoverMoveDown => 'Переместить источник ниже';

  @override
  String get discoverSavingSources => 'Сохраняем выбор…';

  @override
  String get discoverSourcesSaved => 'Выбор сохранён на устройстве';

  @override
  String get discoverSourcesSaveError =>
      'Не удалось сохранить выбор источников';

  @override
  String get discoverNoSources => 'Выберите источники';

  @override
  String get discoverNoSourcesHint =>
      'Включите источники, чтобы видеть их публикации и искать в них.';

  @override
  String get discoverNoMatchingSources => 'Источники не найдены';

  @override
  String get discoverSearchOnly => 'Всё готово к поиску';

  @override
  String get discoverSearchOnlyHint =>
      'Выбранные книжные каталоги доступны через поиск. Найдите книгу в EPUB или PDF в строке выше.';

  @override
  String get discoverSearchSourceHint =>
      'Ищите в этом каталоге по названию, автору или ISBN.';

  @override
  String get discoverSearchPrompt => 'Что хотите почитать?';

  @override
  String get discoverSearchPromptHint =>
      'Поиск идёт только по выбранным источникам. Переключайте категории, чтобы увидеть отдельные результаты.';

  @override
  String get discoverNoMaterials => 'Публикации не найдены';

  @override
  String get discoverFeedError => 'Не удалось загрузить публикации';

  @override
  String get discoverSearchError => 'Не удалось выполнить поиск в источнике';

  @override
  String get discoverRecentOnly => 'Поиск только среди недавних публикаций';

  @override
  String get discoverWholeCatalog => 'Поиск по всему каталогу RFC';

  @override
  String get discoverCachedFeed =>
      'Показаны сохранённые публикации. Обновите, чтобы повторить загрузку.';

  @override
  String discoverUpdated(String date) {
    return 'Обновлено $date';
  }

  @override
  String get discoverRefresh => 'Обновить публикации';

  @override
  String get discoverRead => 'Читать в Lira';

  @override
  String get discoverSave => 'Сохранить в библиотеку';

  @override
  String get discoverSaved => 'Сохранено в библиотеке';

  @override
  String discoverSavedMessage(String title) {
    return '«$title» сохранено в библиотеку';
  }

  @override
  String get discoverPreparing => 'Готовим к чтению…';

  @override
  String get discoverPrepareError =>
      'Не удалось подготовить публикацию. Попробуйте ещё раз.';

  @override
  String get discoverSaveError =>
      'Не удалось сохранить публикацию. Попробуйте ещё раз.';

  @override
  String get discoverOpenOriginal => 'Открыть оригинал';

  @override
  String get discoverOpenOriginalError =>
      'Не удалось открыть оригинал в браузере.';

  @override
  String get discoverMaterialDetails => 'Публикация';

  @override
  String get discoverClearAll => 'Снять выбор';

  @override
  String get zLibraryMirrors => 'Зеркала Z-Library';

  @override
  String get zLibraryMirrorsSettingsHint => 'Для поиска, входа и скачивания';

  @override
  String get zLibraryMirrorsHint =>
      'Зеркала — запасные адреса одного каталога. Если адрес недоступен, Lira пробует следующий по списку, а не отправляет одинаковый поиск во все зеркала.';

  @override
  String get zLibraryMirrorsTrustWarning =>
      'Добавляйте только доверенные адреса. Настроенные зеркала могут получать вашу сессию Z-Library или данные для входа. Найденные адреса не включаются без просмотра и сохранения.';

  @override
  String get zLibraryMirrorsField => 'Адреса зеркал';

  @override
  String get zLibraryMirrorsFieldHint =>
      'По одному HTTPS-адресу в строке, в порядке приоритета. Можно вставить домен без https://.';

  @override
  String get zLibraryMirrorInvalid =>
      'Нужен хотя бы один HTTPS-адрес без пути, параметров запроса и встроенных данных для входа.';

  @override
  String get zLibraryMirrorsSaving => 'Сохраняем…';

  @override
  String get zLibraryMirrorsSaved => 'Список зеркал сохранён';

  @override
  String get zLibraryMirrorsSaveError =>
      'Не удалось сохранить зеркала. Продолжает действовать прежний список.';

  @override
  String get zLibraryMirrorsFind => 'Найти зеркала';

  @override
  String get zLibraryMirrorsFinding => 'Ищем зеркала…';

  @override
  String get zLibraryMirrorsRestore => 'Вернуть известные адреса';

  @override
  String get zLibraryMirrorsFound => 'Проверка найденных зеркал';

  @override
  String get zLibraryMirrorsReviewHint =>
      'Адреса получены из справки о доступе Z-Library. Проверьте их перед добавлением: доступность зависит от сети.';

  @override
  String get zLibraryMirrorsAddSelected => 'Добавить выбранные';

  @override
  String get zLibraryMirrorsReviewSave =>
      'Адреса добавлены в редактор. Нажмите «Сохранить», чтобы использовать новый список.';

  @override
  String get zLibraryMirrorDirectoryHint =>
      'Список берётся из публичного файла Z-Library о доступе, а не из непроверенного стороннего каталога зеркал.';

  @override
  String get zLibraryMirrorDirectoryOpen =>
      'Открыть официальную справку о доступе';

  @override
  String get zLibraryMirrorDirectoryError =>
      'Не удалось получить официальный список. Источник может быть недоступен или требовать проверку в браузере. Откройте справку о доступе или отредактируйте известные адреса вручную.';

  @override
  String get zLibraryMirrorDirectoryOpenError =>
      'Не удалось открыть справку о доступе.';

  @override
  String get annaSessionTitle => 'Доступ Anna’s Archive';

  @override
  String get annaSessionHint =>
      'Anna’s Archive может требовать проверку браузера перед поиском. После обычного прохождения проверки можно использовать сессию браузера здесь. Она отправляется только на выбранный официальный домен.';

  @override
  String get annaSessionDomain => 'Домен проверенного браузера';

  @override
  String get annaSessionOpen => 'Открыть поиск в браузере';

  @override
  String get annaSessionConnectionWarning =>
      'Браузер и Lira должны использовать одно соединение или выходной IP прокси и одинаковый User-Agent. Сессия без прокси не снимает блокировку прокси. Истёкшую проверку нужно пройти заново.';

  @override
  String get annaSessionInstructions =>
      'После проверки откройте инструменты разработчика браузера → Network → успешный запрос /search → Request Headers. Скопируйте сюда значения Cookie и User-Agent. Не передавайте их другим людям. Они сохраняются только на этом устройстве.';

  @override
  String get annaSessionToggleCookies => 'Показать или скрыть Cookie браузера';

  @override
  String get annaSessionClear => 'Удалить сессию';

  @override
  String get annaSessionSaved => 'Сессия браузера сохранена';

  @override
  String get annaSessionCleared => 'Сессия браузера удалена';

  @override
  String get annaSessionInvalid =>
      'Выберите официальный домен, укажите корректный заголовок Cookie и соответствующий User-Agent.';

  @override
  String get annaSessionSaveError => 'Не удалось сохранить сессию браузера.';

  @override
  String get readerSearch => 'Поиск по книге';

  @override
  String get readerSearchHint => 'Слово или фраза';

  @override
  String get readerSearchPrompt =>
      'Найдите нужный фрагмент в книге. Поиск работает без интернета.';

  @override
  String get readerSearching => 'Ищем…';

  @override
  String get readerSearchNoResults => 'Совпадений нет';

  @override
  String get readerSearchNoResultsHint =>
      'Попробуйте другое слово или более короткую фразу.';

  @override
  String get readerSearchNoPdfText =>
      'В этом PDF нет текстового слоя для поиска. Текст на сканах и изображениях не распознаётся.';

  @override
  String get readerSearchError => 'Не удалось выполнить поиск по книге';

  @override
  String get readerSearchRetry => 'Повторить';

  @override
  String get readerSearchPrevious => 'Предыдущее совпадение';

  @override
  String get readerSearchNext => 'Следующее совпадение';

  @override
  String get readerSearchFinish => 'Завершить поиск';

  @override
  String get readerSearchReturn => 'Вернуться к чтению';

  @override
  String get readerSearchNavigationError =>
      'Не удалось открыть это место. Попробуйте ещё раз.';

  @override
  String readerSearchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count совпадения',
      many: '$count совпадений',
      few: '$count совпадения',
      one: '$count совпадение',
      zero: 'Совпадений нет',
    );
    return '$_temp0';
  }

  @override
  String readerSearchPosition(int current, int total) {
    return '$current из $total';
  }

  @override
  String readerSearchPage(int number) {
    return 'Страница $number';
  }

  @override
  String readerSearchChapter(int number) {
    return 'Глава $number';
  }

  @override
  String get annaSessionOpenError =>
      'Не удалось открыть Anna’s Archive в браузере.';
}
