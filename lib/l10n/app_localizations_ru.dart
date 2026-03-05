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
}
