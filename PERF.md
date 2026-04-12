# Lira Performance Roadmap

План оптимизации производительности для Android-first сценария без поломки текущей логики приложения.

## Цель

- Убрать системные просадки FPS и input lag в EPUB reader, библиотеке и поиске.
- Снизить CPU/GPU нагрузку без изменения пользовательской логики.
- Делать изменения поэтапно, с обратимой стратегией и проверкой после каждого этапа.

## Ограничения

- Нельзя ломать навигацию, прогресс чтения, хайлайты, импорт книг, поиск и скачивание.
- Оптимизации, которые могут изменить поведение, сначала внедряются как внутренний refactor или под платформенным/функциональным флагом.
- Любая тяжёлая работа по возможности должна уходить с UI thread.

## Как измерять эффект

До начала каждой фазы и после неё нужно прогонять один и тот же набор сценариев в `profile`/`release`:

1. Открытие EPUB книги.
2. Листание EPUB в vertical и horizontal mode.
3. Выделение текста и работа с highlight.
4. Скролл библиотеки с обложками.
5. Скролл поиска и скачивание книги с активным progress.
6. Импорт EPUB и PDF.

Метрики:

- средний FPS и jank в Flutter DevTools;
- frame build time / raster time;
- memory peak и частота GC;
- время открытия книги;
- время появления progress UI при скачивании.

## Фаза 0. Baseline и guardrails

Цель: зафиксировать базовое состояние и не допустить случайной поломки UX во время оптимизаций.

| Зона | Где менять | Что сделать | На что повлияет | Безопасный путь |
|---|---|---|---|---|
| Профилирование | `android/`, весь app runtime | Подготовить repeatable perf-checklist и сохранить baseline по ключевым сценариям | Позволит видеть, где оптимизация реально помогает | Не менять код приложения, только измерение и чек-листы |
| Защита логики | Reader, Search, Library, Import | Сформировать smoke regression list: открыть книгу, восстановить прогресс, выделить текст, скачать книгу, удалить книгу | Уменьшит риск регрессий | Проверять после каждой фазы, а не в конце всего цикла |

## Фаза 1. Развязать reader от лишних rebuild'ов

Цель: убрать самые дорогие пересборки и стабилизировать FPS в EPUB reader.

| Зона | Где менять | Что сделать | На что повлияет | Безопасный путь |
|---|---|---|---|---|
| Reader screen rebuild fan-out | `lib/features/reader/presentation/reader_screen.dart` | Разделить стабильный reader surface и overlay/chrome state. Прогресс, selection, top/bottom bars и highlight panel не должны пересобирать весь reader widget | Сильное снижение микролагов при тапах, скролле и обновлении прогресса | Сохранить текущий `BookReaderEngine`, но вынести overlay в отдельные виджеты/нотификаторы |
| Progress updates | `lib/features/reader/presentation/reader_screen.dart` | Ограничить rebuild только прогресс-UI, а не всей страницы ридера | Более плавный input и меньше dropped frames | Использовать `ValueNotifier`, `Consumer` с `select` или локальные поддеревья |
| Highlight/selection updates | `lib/features/reader/presentation/reader_screen.dart` | Выделение текста и показ панели хайлайтов должны менять только overlay | Уменьшение лагов при выделении текста | Не трогать логику выделения, только сузить область rebuild |
| Full-screen future/build coupling | `lib/features/reader/presentation/reader_screen.dart` | Убедиться, что `engine.buildReaderWidget(...)` живёт в стабильном subtree и не пересоздаётся от мелкого UI state | Снижение лишней работы в build | Менять структуру экрана, не меняя API движка |

## Фаза 2. Удешевить EPUB pipeline

Цель: убрать CPU-heavy операции из UI thread и резко сократить стоимость пагинации/парсинга.

| Зона | Где менять | Что сделать | На что повлияет | Безопасный путь |
|---|---|---|---|---|
| Полная репагинация | `packages/epub_engine/lib/src/epub_native_view.dart` | Ввести кэш пагинации по ключу `book + viewport width + reader settings + spread mode` | Меньше лагов при resize, повороте, смене настроек | Инвалидировать кэш только на реальные изменения размера/типографики |
| Eager parsing chapters | `packages/epub_engine/lib/src/epub_native_view.dart` | Убрать лишний eager parse всех глав в UI thread | Ускорение открытия книги и горизонтального режима | Сначала перенести расчёт в isolate, затем подключить кэш |
| Text measurement | `packages/epub_engine/lib/src/epub_native_view.dart` | Сократить количество вызовов `TextPainter`, переиспользовать результаты измерений, не мерить одинаковые блоки повторно | Снижение CPU нагрузки | Делать memoization по тексту, стилю и ширине |
| HTML parsing | `packages/epub_engine/lib/src/xhtml_parser.dart` | Вынести HTML parse и подготовку chapter tree в `compute`/isolate | Сильное снижение main-thread нагрузки | Оставить на выходе те же структуры данных |
| Span tree rebuild for highlights | `packages/epub_engine/lib/src/xhtml_parser.dart` | Кэшировать дерево `TextSpan` без хайлайтов и поверх него кэш применения highlights по версии списка | Быстрее открытие главы с большим числом highlights | Не менять формат highlight location и текущую логику навигации |
| Image lookup in XHTML | `packages/epub_engine/lib/src/xhtml_parser.dart` | Заменить линейный поиск изображений по имени на заранее подготовленный индекс | Уменьшение лишнего CPU при построении главы | Изменение локальное и безопасное |
| EPUB asset loading | `packages/epub_engine/lib/src/epub_parser.dart` | Перестать жадно тянуть и держать в памяти все изображения и тяжёлые assets сразу | Меньше memory spikes и GC pauses | Сначала сделать lazy loading для не-критичных assets, API наружу не ломать |

## Фаза 3. Стабилизировать Android rendering cost

Цель: уменьшить GPU cost на Android, не ломая визуальную структуру приложения.

| Зона | Где менять | Что сделать | На что повлияет | Безопасный путь |
|---|---|---|---|---|
| Bottom navigation blur | `lib/features/navigation/presentation/main_shell.dart` | Ослабить или отключить `BackdropFilter` на Android | Меньше raster lag почти на всех экранах | Desktop/iOS можно оставить красивый blur, Android упростить платформенно |
| Library top bar blur | `lib/features/books/presentation/library_screen.dart` | Упростить blur на app bar библиотеки | Более плавный скролл библиотеки | Использовать полупрозрачный fill вместо live blur на Android |
| Library book card blur | `lib/features/books/presentation/widgets/book_card.dart` | Убрать/сильно облегчить blur за обложками на Android | Снижение GPU нагрузки в grid/list | Сохранить тот же layout, упростить только эффект |
| Heavy shadows | `lib/features/books/presentation/widgets/book_card.dart` | Уменьшить число и радиус теней на карточках | Меньше raster time | Сначала упростить только Android theme branch |
| File checks in build | `lib/features/books/presentation/widgets/book_card.dart` | Убрать `File(...).existsSync()` из build | Меньше синхронных стопов во время скролла | Кэшировать наличие cover заранее в модели/контроллере |

## Фаза 4. Оптимизировать поиск и карточки

Цель: убрать широкие rebuild'ы и дорогой layout на экране поиска.

| Зона | Где менять | Что сделать | На что повлияет | Безопасный путь |
|---|---|---|---|---|
| Download progress fan-out | `lib/features/search/presentation/widgets/search_book_card.dart` | Подписывать карточку только на свой `book.id`, а не на весь map прогресса | При скачивании перестанет дёргаться весь список | Использовать `ref.watch(...select(...))` или family provider |
| Progress state shape | `lib/features/search/domain/providers/download_provider.dart` | Если одного `select` будет мало, разделить прогресс по `bookId` на более узкие providers | Ещё меньше rebuild’ов при скачивании | Делать после consumer-side сужения подписок, чтобы не ломать API раньше времени |
| Expensive layout in list | `lib/features/search/presentation/widgets/search_book_card.dart` | Убрать `IntrinsicHeight` из карточек | Ускорение layout списка | Перейти на фиксированные constraints и явную высоту |
| Network image decoding | `lib/features/search/presentation/widgets/search_book_card.dart` | Уменьшить decode cost и улучшить caching strategy для обложек | Плавнее скролл поиска | Не менять источник обложек, только способ их отображения |
| Repeated filtering/sorting | `lib/features/search/presentation/search_screen.dart` | Мемоизировать фильтрацию и сортировку результатов | Меньше лишней CPU работы при вводе и смене фильтров | Перенести derived state в provider или локальный memoized слой |
| `setState` on text/focus | `lib/features/search/presentation/search_screen.dart` | Ограничить rebuild header-зоной, не всем экраном | Плавнее работа search screen | Разделить header и results list на независимые части |

## Фаза 5. Убрать блокировки при импорте и обновлении библиотеки

Цель: сделать импорт и обновление книжной базы менее тяжёлыми для UI.

| Зона | Где менять | Что сделать | На что повлияет | Безопасный путь |
|---|---|---|---|---|
| EPUB metadata extraction | `lib/features/books/domain/providers/books_provider.dart` | Вынести `EpubParser.parse`, подсчёт текста и page count estimate в isolate | Меньше подвисаний при добавлении EPUB | Оставить существующий импортный flow, изменить только место выполнения |
| PDF cover generation | `lib/features/books/domain/providers/books_provider.dart` | Вынести render/encode cover из main isolate | Быстрее импорт PDF, меньше input lag | Сохранять тот же выходной PNG и тот же pipeline сохранения |
| PNG encode loop | `lib/features/books/domain/providers/books_provider.dart` | Оптимизировать `_encodePng` или заменить на менее дорогой путь | Снижение CPU времени на импорт | Менять локально, без смены результата |
| Full reload after delete | `lib/features/books/domain/providers/books_provider.dart` | После удаления книги не перечитывать весь список библиотеки | Ускорение library updates | Делать инкрементальную мутацию локального state |
| Highlights full reload | `lib/features/highlights/domain/providers/highlights_provider.dart` | После add/update/delete не загружать заново весь список highlights | Более отзывчивый reader/highlights UI | Делать optimistic local update и затем подтверждать из repo |
| Repository usage pattern | `lib/features/books/data/repositories/books_local_repository.dart` | Сохранить текущий repo API, но перестать использовать full reload там, где достаточно локальной правки state | Снижение лишней DB и UI работы | Начать с provider/controller, repo не ломать |

## Фаза 6. Инфраструктурные и системные мелочи

Цель: убрать накопленные мелкие источники лишней работы.

| Зона | Где менять | Что сделать | На что повлияет | Безопасный путь |
|---|---|---|---|---|
| SharedPreferences churn | `lib/core/providers/preferences_provider.dart` | Перевести провайдеры на уже предзагруженный `sharedPrefs`, убрать повторные `getInstance()` | Более спокойный startup и меньше async дерганий состояния | Поведение настроек не меняется, меняется только источник доступа |
| Side-effect in build | `lib/main.dart` | Перенести `updateGlobalProxyConfig(...)` из build в `ref.listen` или bootstrap flow | Меньше лишних побочных действий при rebuild | Изменение локальное и безопасное |
| Settings screen futures | `lib/features/settings/presentation/settings_screen.dart` | Убрать `PackageInfo.fromPlatform()` из rebuild path, задебаунсить proxy inputs | Меньше шума на settings screen | Сначала вынести info в provider/future field |
| Verbose logging | `packages/zlibrary_api/lib/src/zlibrary_api_client.dart` | Убрать `print()` из горячих путей, оставить debug-only logging | Чище runtime и меньше лишних аллокаций | На функциональность скачивания не влияет |

## Порядок внедрения

Последовательность важна. Оптимально идти так:

1. `Фаза 0` — снять baseline.
2. `Фаза 1` — изолировать rebuild’ы reader screen.
3. `Фаза 2` — разгрузить EPUB pipeline и пагинацию.
4. `Фаза 3` — удешевить Android visuals.
5. `Фаза 4` — сузить rebuild’ы поиска и карточек.
6. `Фаза 5` — убрать блокировки при импорте и обновлении данных.
7. `Фаза 6` — дочистить инфраструктуру.

## Что даст максимальный эффект первым

Если нужна самая быстрая отдача по FPS, сначала делать только эти шаги:

1. Развязать `reader_screen.dart` от лишних rebuild’ов.
2. Ввести кэш пагинации и вынести EPUB parsing в isolate.
3. Отключить/сильно упростить blur и тяжёлые тени на Android.
4. Исправить широкие подписки `download progress` на карточках поиска.
5. Вынести импорт EPUB/PDF из main isolate.

## Критерий завершения roadmap

Roadmap можно считать выполненным, когда:

- EPUB reader на Android держит плавное листание без заметных регулярных фризов;
- библиотека и поиск скроллятся без массовых dropped frames;
- импорт книг не блокирует интерфейс;
- ни одна из оптимизаций не ломает прогресс, highlights, скачивание, поиск и восстановление позиции.
