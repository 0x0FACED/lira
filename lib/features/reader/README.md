# Lira Reader Module

Общий экран чтения EPUB/PDF. Модуль координирует содержимое, навигацию и пометки; реализации движков находятся в [`epub_engine`](../../../packages/epub_engine) и [`pdf_engine`](../../../packages/pdf_engine).

## Ответственность

- `ReaderScreen`: загрузка локального файла, lifecycle, панели, TOC, поиск, настройки, сохранение progress/highlights/notes/bookmarks.
- `BookReaderEngine`: выбор содержимого, поиск и навигация через непрозрачный `BookLocation.locator`.
- `EpubBookReaderEngine`: нативный Flutter renderer из `packages/epub_engine`.
- `PdfBookReaderEngine`: `pdfrx` viewer из `packages/pdf_engine`.

`initialLocation` — начальное состояние, не команда навигации при каждой записи в БД. После открытия переходы выполняются через `goToLocation`. Асинхронная загрузка старой книги не может подменить новую; движок освобождается при ошибке/закрытии.

## Координаты

**EPUB:** собственный JSON `EpubLocation`/`EpubCfi`. В `v:2` поле `c` означает точный UTF-16 offset разобранного содержимого; unversioned записи читаются с legacy-семантикой. Это не стандартная EPUB CFI-строка.

**PDF:** старый строковый номер страницы для progress; versioned `PdfReaderLocation` с page ranges и PDF rectangles для selection/highlights.

`ReaderScreen` передаёт движкам:

- EPUB highlights: `{highlightId, chapterIndex, startOffset, endOffset, color}`;
- PDF highlights: `{highlightId, location, color}`, где декодирование location принадлежит PDF-пакету.

Общий интерфейс не должен интерпретировать PDF rectangles или EPUB HTML.

`search(BookSearchRequest)` ищет без навигации и возвращает контекст, раздел/страницу и точный range locator. `ReaderSearchController` владеет debounce/отменой и временной выдачей; экран сохраняет исходное место поисковой сессии и добавляет её подсветки только к render data. Поисковые диапазоны не записываются в БД и не подменяют пользовательские пометки. Подробнее — [READER.md](../../../READER.md#поиск-по-книге).

## Сохранение

`ReadingProgressController` объединяет частые события, сериализует записи и предоставляет `flush()`. Экран вызывает его перед явным Back и при lifecycle/disposal. Окончание старой записи не очищает более новую pending-позицию. Ошибки хранения не маскируются успешным сохранением.

Выделение очищается после успешной записи, а не до неё. Текст для заметки фиксируется перед открытием диалога. При смене книги async close/highlight операции ограничены поколением загрузки и исходным route.

## Закладки и панели

Закладка сохраняет текущий locator и процент из событий движка. Верхняя кнопка добавляет/удаляет текущее место; `ReaderAnnotationsPanel` разделяет выделения и закладки, позволяет перейти к месту и удалить запись. Хранение — `features/bookmarks`, отдельная таблица Drift с уникальностью по книге и locator; схема v3 мигрирует существующую v2 без потери данных.

Клавиатура редактора заметки изменяет только диалог, не viewport книги. Верхняя и нижняя панели выдвигаются и скрываются на свою высоту через `AnimatedSlide`, без изменения layout текста; reduced motion сохраняется.

