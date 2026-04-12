# 📦 Lira Build Summary

## Статус сборок для v0.3.0

---

## ✅ Успешно собрано

### Android APK
- **Файл:** `build_dist/lira-release-android.apk`
- **Размер:** 80 MB
- **Путь:** `/home/faced/coding/flutter/lira/build_dist/lira-release-android.apk`
- **Статус:** Готово к использованию

### Android App Bundle (Google Play)
- **Файл:** `build_dist/lira-release-android.aab`
- **Размер:** 59 MB
- **Путь:** `/home/faced/coding/flutter/lira/build_dist/lira-release-android.aab`
- **Статус:** Готово для публикации в Google Play

### Linux
- **Папка:** `build_dist/lira-release-linux/`
- **Файл:** `lira` (исполняемый)
- **Статус:** Готово к запуску

---

## ❌ Не собрано

### Web
**Причина:** `drift` + `sqlite3` не поддерживают Web (требуется FFI)

**Решение:**
1. Использовать `drift_web` с WASM
2. Или отключить БД для Web версии
3. Или использовать изолированное хранилище (`shared_preferences`)

**Требуемые изменения:**
- Добавить `drift_web: ^2.20.0`
- Настроить условную компиляцию в database.dart
- Использовать `WebDatabase` для Web

---

### Windows
**Причина:** Требуется Windows для компиляции

**Решение:**
- Собирать на Windows машине
- Или использовать GitHub Actions (workflow уже настроен)

---

### macOS
**Причина:** Требуется macOS для компиляции

**Решение:**
- Собирать на Mac
- Или использовать GitHub Actions

---

### iOS
**Причина:** Требуется macOS + Xcode

**Решение:**
- Собирать на Mac с Xcode
- Или использовать GitHub Actions

---

## 📁 Расположение билдов

```
build_dist/
├── lira-release-android.apk    # Android APK
├── lira-release-android.aab    # Android App Bundle
├── lira-release-linux/         # Linux desktop
│   ├── lira                    # Executable
│   ├── data/
│   └── lib/
└── build_*.log                 # Логи сборки
```

---

## 🚀 Как использовать

### Android

**Установка на устройство:**
```bash
adb install build_dist/lira-release-android.apk
```

**Или через Flutter:**
```bash
flutter install
```

### Linux

**Запуск:**
```bash
cd build_dist/lira-release-linux
./lira
```

**Или установить в систему:**
```bash
sudo cp -r build_dist/lira-release-linux/* /opt/lira/
sudo ln -s /opt/lira/lira /usr/local/bin/lira
```

---

## 🔄 Автоматическая сборка

GitHub Actions автоматически собирает билды при создании тега:

```bash
git tag v0.5.0
git push origin --tags
```

Workflow создаст черновик релиза на GitHub со всеми артефактами.

**File:** `.github/workflows/build.yml`

---

## 🛠️ Локальная сборка

### Все доступные платформы
```bash
./scripts/build_all.sh release
```

### Только Android
```bash
./scripts/build_android.sh release
```

### Отдельные платформы

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# Linux
flutter build linux --release

# Web (требуется настройка drift_web)
flutter build web --release

# Windows (нужна Windows)
flutter build windows --release

# macOS (нужен macOS)
flutter build macos --release

# iOS (нужен macOS + Xcode)
flutter build ios --release
```

---

## 📝 Замечания

### Иконки
Все иконки сгенерированы из `assets/icon/icon.png`:
- ✅ Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- ✅ iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- ✅ Web: `web/icons/Icon-*.png`

### Версия
Текущая версия: **0.5.0+2**

Версия автоматически отображается в настройках приложения через `package_info_plus`.

### Подпись Android
Для release сборок без `key.properties` используется debug подпись.

**Для Google Play:**
1. Создать keystore: `./scripts/generate_keystore.sh`
2. Настроить `android/key.properties`
3. Пересобрать

---

## 📊 Сравнение размеров

| Платформа | Размер | Примечание |
|-----------|--------|------------|
| Android APK | 80 MB | Для прямой установки |
| Android AAB | 59 MB | Для Google Play (меньше) |
| Linux | ~200 MB | Включает библиотеки |

---

## 🔧 Troubleshooting

### Web сборка не работает
```
Error: Type 'Pointer' not found
```

**Решение:** Настроить `drift_web` или отключить БД для Web.

### Linux сборка не запускается
```
error while loading shared libraries
```

**Решение:** Установить зависимости:
```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

### Android APK не устанавливается
```
INSTALL_FAILED_UPDATE_INCOMPATIBLE
```

**Решение:** Удалить старую версию или установить с флагом:
```bash
adb install -r build_dist/lira-release-android.apk
```

---

## 📚 Документация

- [`RELEASE.md`](RELEASE.md) — полное руководство по релизам
- [`QUICK_RELEASE.md`](QUICK_RELEASE.md) — быстрый старт
- [`ICON_SETUP.md`](ICON_SETUP.md) — настройка иконок
- [`scripts/README.md`](scripts/README.md) — скрипты для сборок
- [`.github/workflows/build.yml`](.github/workflows/build.yml) — GitHub Actions

---

**Последнее обновление:** 2026-04-12  
**Версия:** 0.5.0+2
