# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- EPUB: восстановлены все документы в порядке OPF spine независимо от оглавления и имени файла; повреждённый spine больше не даёт частично успешную книгу.
- EPUB: добавлено корректное чтение UTF-16 LE/BE; повреждённые текстовые последовательности не заменяются молча.
- EPUB: позиция привязана к тексту и сохраняется при reflow, смене режима, шрифта, отступов и размера окна; переход на правую страницу разворота не сохраняет предыдущую главу.
- EPUB: пересекающиеся highlights больше не дублируют текст; исправлены внутренние ссылки, fragments, encoded paths и Unicode hit-testing.
- PDF: подключены панели, оглавление, native selection, сохранённые highlights и переход к их геометрии; controller не теряется после rebuild.
- PDF: single tap не конфликтует с double-click selection, drag и long-press; native deselection очищает действия Lira.
- PDF: исправлен upstream zero-area bug для абсолютно горизонтального выделения; нормализуются только активные edges, без подмены native текста или сохранённой геометрии.
- PDF: переход к сохранённому выделению сохраняет текущий zoom, если диапазон помещается во viewport, вместо увеличения одной фразы на весь экран.
- Reader: устранена потеря новой позиции при медленной предыдущей записи; close/suspend выполняют flush, а одновременные Back не закрывают предыдущий route.
- Reader: повреждённые файлы показывают ошибку загрузки вместо подставной error-книги; выделение очищается после успешного сохранения.
- CI: исправлены несовместимая версия Flutter и игнорирование выбранного debug/release режима.
- Android: release больше не подменяет постоянный signing key debug-ключом; CI восстанавливает keystore из secrets без вывода паролей.
- Android CI: APK и AAB разделены на независимые runners после исчерпания диска при последовательной упаковке в одном job; готовый APK больше не теряется при ошибке AAB.

### Changed
- EPUB renderer окончательно переведён на native Flutter: удалены старый WebView, одноразовый patch script и неиспользуемые зависимости.
- Новые EPUB-позиции используют versioned `v:2` offsets; legacy JSON остаётся читаемым без миграции схемы БД.
- Добавлены reader-регрессии, включая настоящий PDFium; обновлены `READER.md` и документация пакетов.
- GitHub Actions закреплён на Flutter 3.41.6; CI на push/PR и перед сборками запускает reader-регрессии с настоящим PDFium.
- Релизный pipeline собирает Android, iOS, Windows, Linux и macOS; iOS IPA предназначен для самостоятельной подписи, AAB создаётся только в release, неподдерживаемый Web исключён.
- Push тега `v*` автоматически публикует единый GitHub Release, не черновик, только после успеха всех платформ; signing files удаляются после Android-сборок.
- Описание GitHub Release берётся из раздела `CHANGELOG.md` с версией тега вместо списка коммитов; отсутствующий, пустой или дублирующийся раздел блокирует публикацию.

## [0.5.0] - 2026-04-12

### Added
- Опция отключения двухстраничного разворота в горизонтальном EPUB режиме
- Скачивание обложек при импорте книг из поиска в библиотеку
- Более точное сохранение позиции и прогресса в native EPUB reader

### Changed
- **Версия приложения**: 0.4.0 → 0.5.0
- Переработан верхний блок экрана поиска и переключатель источников
- Улучшена навигация жестами и поведение выделения текста в EPUB reader

### Fixed
- Исправлены скачивания книг из Z-Library
- Исправлены overflow, неточное позиционирование и ошибки подсветки в EPUB reader
- Снижена нагрузка native EPUB reader в vertical mode

---

## [0.4.0] - 2026-04-10

### Added
- Frosted glass (blur) навигационная панель с кастомными иконками
- Фильтрация результатов поиска по формату (EPUB/PDF) и сортировка (по названию, автору)
- Поддержка SOCKS5 прокси с настройками в приложении
- Отдельный экран настроек приложения (Settings Screen)
- Tap по центру в EPUB ридере для показа/скрытия UI
- Контент прокручивается под навигационной панелью (edge-to-edge дизайн)

### Changed
- **Версия приложения**: 0.3.0 → 0.4.0
- Полностью переработан экран поиска — новый дизайн с чипами фильтров
- Переработана панель настроек ридера — компактнее, с drag handle
- Библиотека: edge-to-edge layout с blur эффектами
- Улучшена цветовая обработка в EPUB движке (CSS вместо нативных вызовов)

### Fixed
- Исправлен краш `setBackgroundColor` на macOS WebView (не поддерживается WKWebView)
- Исправлена работа EPUB ридера на macOS

### Technical
- Добавлен `preferences_provider` для SOCKS5 конфигурации
- Обновлены `reader_settings` модели (freezed regeneration)
- Добавлен `proxy_http_overrides.dart` для сетевого слоя
- Добавлены Podfile для iOS и macOS
- Обновлены macOS entitlements для сетевого доступа

---

## [0.3.0] - 2026-03-14

### Added
- Интеграция с Z-Library API для поиска и скачивания книг прямо в приложении
- Автоматическое получение версии приложения через `package_info_plus`
- Скрипты для автоматизации сборок (`build_all.sh`, `build_android.sh`)
- Скрипт для создания релиза (`create_release.sh`)
- Скрипт для генерации Android keystore (`generate_keystore.sh`)
- GitHub Actions workflow для автоматических сборок
- Документация по релизам (`RELEASE.md`)
- Шаблон `key.properties` для подписи Android

### Changed
- **Версия приложения**: 0.2.1 → 0.3.0
- **Описание приложения**: "A new Flutter project" → "Lira is your free feature-rich library"
- Обновлён `freezed_annotation` до `^3.1.0` в `epub_engine`
- Обновлён `freezed` до `^3.2.5` в `epub_engine`
- Версия в настройках теперь берётся автоматически из `pubspec.yaml`

### Fixed
- Исправлена ошибка компиляции Android с `package_info_plus`
- Исправлены неверные версии в различных файлах проекта

### Removed
- Хардкод версии в `settings_screen.dart`

### Technical
- Добавлен `package_info_plus: ^8.1.2`
- Настроена подписывание Android release сборок
- Добавлен GitHub Actions workflow для всех платформ
- Все скрипты добавлены в `scripts/` директорию

---

## [0.2.1] - 2026-03-XX

### Previous releases
See git history for details.
