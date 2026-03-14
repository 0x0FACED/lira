# 🖼️ How to Add App Icon

## Инструкция по установке иконки приложения

---

## 📋 Шаг 1: Подготовь иконку

Требования к иконке:
- **Формат**: PNG
- **Размер**: 1024x1024 пикселей (или больше)
- **Фон**: Прозрачный или сплошной цвет
- **Форма**: Квадрат (не круглая!)

> ⚠️ **Важно**: Не используй круглую иконку — Android и iOS сами добавят маску.

---

## 📋 Шаг 2: Помести иконку в проект

Скопируй иконку в папку:

```
lira/assets/icon/icon.png
```

Или используй команду:

```bash
./scripts/set_icon.sh /путь/к/иконке.png
```

---

## 📋 Шаг 3: Сгенерируй иконки

Запусти команду:

```bash
flutter pub run flutter_launcher_icons:main
```

---

## 📋 Шаг 4: Обнови Web иконки (вручную)

```bash
cp assets/icon/icon.png web/icons/Icon-192.png
cp assets/icon/icon.png web/icons/Icon-512.png
cp assets/icon/icon.png web/icons/Icon-maskable-192.png
cp assets/icon/icon.png web/icons/Icon-maskable-512.png
```

---

## 📋 Шаг 5: Пересобери приложение

```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

## 🔧 Для разных платформ

### Android

Иконки автоматически добавляются в `android/app/src/main/res/`.

**Adaptive Icon (Android 8.0+)**:
Если хочешь разделить фон и передний план:

1. В `pubspec.yaml` раскомментируй:
   ```yaml
   flutter_launcher_icons:
     android: true
     adaptive_icon_background: "#000000"
     adaptive_icon_foreground: "assets/icon/icon_foreground.png"
   ```

2. Создай `assets/icon/icon_foreground.png` (только передний план)

3. Запусти генерацию снова

### iOS

Иконки добавляются в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

После генерации открой `ios/Runner.xcworkspace` в Xcode и проверь, что иконки отображаются.

### Web

Web иконки уже есть в `web/icons/`. Чтобы обновить:

1. Замени `web/icons/Icon-192.png` и `web/icons/Icon-512.png`
2. Или запусти генерацию с новыми настройками

### Linux

Иконка сохраняется в `linux/flutter/generated_plugin_registrant.cc`.

После сборки иконка будет в `build/linux/x64/release/bundle/`.

### Windows

Иконка встраивается в `.exe` файл при сборке.

### macOS

Иконка добавляется в `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.

---

## 🎨 Рекомендации по дизайну

### Размер и детализация

- Минимальный размер исходника: **1024x1024**
- Лучше больше: **2048x2048** для лучших результатов
- Избегай мелких деталей — они не видны на маленьких иконках

### Фон

- **Тёмный фон** (#000000 или #1a1a1a) — для тёмной темы
- **Сплошной цвет** — лучше градиентов
- **Прозрачный** — система сама добавит фон

### Контраст

- Иконка должна быть видна на любом фоне
- Проверяй на светлом и тёмном фоне
- Избегай тонких линий

---

## 🆘 Troubleshooting

### Иконка не обновляется на Android

```bash
flutter clean
rm -rf android/app/build/
flutter pub get
flutter build apk
```

### Иконка не обновляется на iOS

Открой `ios/Runner.xcworkspace` в Xcode:
1. Product → Clean Build Folder
2. Закрой Xcode
3. `flutter clean && flutter pub get`
4. Пересобери

### Ошибка при генерации

Проверь, что иконка:
- В формате PNG
- Размером не меньше 1024x1024
- По пути `assets/icon/icon.png`

---

## 📦 Быстрая команда

Всё в одной команде:

```bash
# Скопировать иконку
cp ~/Downloads/my_icon.png assets/icon/icon.png

# Сгенерировать
flutter pub run flutter_launcher_icons:main

# Пересобрать
flutter clean && flutter pub get && flutter build apk --release
```

---

## 📚 Ссылки

- [Flutter Launcher Icons](https://pub.dev/packages/flutter_launcher_icons)
- [Android Icon Design Guidelines](https://developer.android.com/guide/practices/ui_guidelines/icon_design_launcher)
- [iOS App Icon Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
