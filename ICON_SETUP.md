# 🖼️ Quick Icon Setup

## Быстрая установка иконки

### Вариант 1: Через скрипт (рекомендуется)

```bash
./scripts/set_icon.sh /путь/к/иконке.png
```

### Вариант 2: Вручную

1. Скопируй иконку:
   ```bash
   cp /путь/к/иконке.png assets/icon/icon.png
   ```

2. Сгенерируй иконки:
   ```bash
   flutter pub run flutter_launcher_icons:main
   ```

3. Пересобери:
   ```bash
   flutter clean && flutter pub get && flutter build apk --release
   ```

---

## Требования к иконке

| Параметр | Значение |
|----------|----------|
| Формат | PNG |
| Размер | 1024x1024 или больше |
| Форма | Квадрат |
| Фон | Любой (прозрачный или цветной) |

---

## Что будет сгенерировано

- ✅ Android: все размеры (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- ✅ iOS: все размеры (AppIcon 20x20, 29x29, 40x40, 60x60, etc.)
- ✅ Web: 192x192, 512x512, maskable
- ✅ Windows: иконка для .exe
- ✅ macOS: все размеры
- ✅ Linux: иконка для приложения

---

## Проверка

После сборки проверь иконки:

```bash
# Android
ls android/app/src/main/res/mipmap-*/ic_launcher.png

# iOS
ls ios/Runner/Assets.xcassets/AppIcon.appiconset/

# Web
ls web/icons/
```

---

## Полная документация

См. [`assets/icon/README.md`](assets/icon/README.md)
