# Lira Universal Reader — Architecture Plan

## Проблема

Текущие библиотеки не работают кросс-платформенно:
- `pdfx` → **crash на Linux** (`MissingPluginException`)
- `epub_view` → **2-3 FPS на Android** (рендер через `flutter_html`)
- `epubx` → **crash** на некоторых EPUB файлах (`RangeError`)

## Варианты решения

### Вариант A: Замена библиотек (быстрый фикс)

| Формат | Текущая | Замена | Плюсы | Минусы |
|---|---|---|---|---|
| PDF | `pdfx` | `pdfrx` | Поддержка Linux/Desktop, активный maintainer | Баги с шрифтами, pan-to-scroll |
| EPUB | `epub_view` | `flutter_epub_viewer` | epub.js + InAppWebView, хайлайты, поиск | WebView-based → тяжёлый, нет Desktop |

**Время:** ~2-4 часа  
**Риск:** Новые библиотеки могут иметь свои баги на нестандартных платформах.

---

### Вариант B: Универсальный ридер (свой рендер)

Пишем собственный рендер, который:
1. **Парсит** EPUB/PDF → извлекает контент (текст, изображения, метаданные)
2. **Нормализует** в единый `BookContent` формат
3. **Рендерит** нативными Flutter виджетами

#### Архитектура

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  EPUB File  │────▶│  ContentParser   │────▶│   BookContent   │
│  PDF File   │     │  (epub/pdf)      │     │   (unified)     │
│  FB2 (todo) │     │                  │     │                 │
└─────────────┘     └──────────────────┘     └────────┬────────┘
                                                       │
                                              ┌────────▼────────┐
                                              │  LiraReader     │
                                              │  (Flutter UI)   │
                                              │  - PageView     │
                                              │  - Text/Images  │
                                              │  - Highlights   │
                                              └─────────────────┘
```

#### Модель данных

```dart
class BookContent {
  final BookMetadata metadata;    // title, author, cover, language
  final List<Chapter> chapters;   // ordered list of chapters
}

class Chapter {
  final String title;
  final List<ContentBlock> blocks; // text, image, table, etc.
}

sealed class ContentBlock {}
class TextBlock extends ContentBlock {  // paragraph, heading, etc.
  final String text;
  final TextStyle? style;
  final TextBlockType type;  // paragraph, h1, h2, h3, quote, code
}
class ImageBlock extends ContentBlock {
  final Uint8List imageData;
  final String? altText;
}
class TableBlock extends ContentBlock { ... }
```

#### Парсеры

| Формат | Библиотека для парсинга | Что извлекаем |
|---|---|---|
| EPUB | `epubx` (парсинг ZIP) + дополнительный HTML-парсер | Главы → HTML → ContentBlock |
| PDF | `syncfusion_flutter_pdf` (извлечение текста/изображений) | Страницы → текст/изображения → ContentBlock |

#### Рендер (Flutter native)

```dart
class LiraReaderView extends StatefulWidget {
  final BookContent content;
  final BookLocation initialLocation;
  final void Function(BookLocation, double) onProgressChanged;
}
```

- `PageView` для постраничного листания (плавные анимации)
- `RichText` / `Text.rich` для текста с поддержкой выделения
- `Image.memory` для встроенных изображений
- `SelectableText` для выделения текста → хайлайты

**Время:** ~2-3 дня  
**Плюсы:** Полный контроль, единый UX, работает на ВСЕХ платформах, расширяемость (FB2, MOBI)  
**Минусы:** Сложность парсинга PDF (layout-based), не все EPUB стили будут поддержаны

---

### Вариант C: Гибрид (рекомендуемый)

Комбинация подходов:
- **PDF** → заменить `pdfx` на `pdfrx` (поддержка Desktop, проверенный) 
- **EPUB** → свой рендер: `epubx` для парсинга + `flutter_widget_from_html` для отображения HTML-глав нативно (без WebView)

Это даёт:
- ✅ PDF работает на всех платформах через `pdfrx`
- ✅ EPUB рендерится нативно (без WebView) → производительность
- ✅ Легко добавить FB2/MOBI позже
- ✅ Быстрее реализовать чем полный Вариант B

**Время:** ~4-6 часов

## Рекомендация

**Вариант C (гибрид)** — оптимальный баланс скорости и качества.

### План реализации

1. Заменить `pdfx` на `pdfrx` в `pdf_engine` (фикс Linux)
2. Переписать `epub_engine`: `epubx` парсинг + `flutter_widget_from_html` для рендера глав
3. Добавить error handling для невалидных EPUB/PDF
4. Протестировать на Linux + Android
