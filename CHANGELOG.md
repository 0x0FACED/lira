# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
