# Build Scripts

## set_icon.sh

Скрипт для установки иконки приложения на все платформы.

### Использование

```bash
# С путем к иконке
./scripts/set_icon.sh /path/to/icon.png

# Или скопируй иконку вручную в assets/icon/icon.png
./scripts/set_icon.sh
```

### Требования к иконке

- **Формат**: PNG
- **Размер**: 1024x1024 или больше
- **Форма**: Квадрат (не круглая!)

### Что делает скрипт

1. Копирует иконку в `assets/icon/icon.png`
2. Запускает `flutter_launcher_icons` для генерации
3. Предлагает пересобрать приложение

---

## create_release.sh

Скрипт для подготовки нового релиза.

### Использование

```bash
./scripts/create_release.sh
```

Скрипт:
1. Запросит новую версию (например, `0.3.0`)
2. Обновит `pubspec.yaml`
3. Обновит `CHANGELOG.md`
4. Создаст Git tag (например, `v0.3.0`)
5. Подскажет следующие шаги

После запуска скрипта остаётся только сделать `git push` и GitHub Actions соберёт все билды.

---

## build_all.sh

Скрипт для сборки приложения под все доступные платформы.

### Использование

```bash
# Сборка release-версии (по умолчанию)
./scripts/build_all.sh

# Сборка debug-версии
./scripts/build_all.sh debug
```

### Выходные данные

Все билды сохраняются в директорию `build_dist/`:

- `lira-release-android.apk` — Android APK
- `lira-release-android.aab` — Android App Bundle (для Google Play)
- `lira-release-linux/` — Linux desktop
- `lira-release-web/` — Web приложение
- `lira-release-windows/` — Windows desktop
- `Lira.app` — macOS приложение

### Требования

| Платформа | Требования |
|-----------|------------|
| Android | Android SDK, JDK |
| Linux | clang, cmake, ninja |
| Web | Браузер (для тестирования) |
| Windows | Visual Studio с C++ workload |
| macOS | Xcode |
| iOS | macOS + Xcode |

### Подпись Android (для release)

#### 1. Создать keystore

```bash
./scripts/generate_keystore.sh
```

Или вручную:

```bash
keytool -genkey -v \
  -keystore ~/lira-release-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias lira
```

#### 2. Создать `android/key.properties`

Скопируйте `android/key.properties.template` в `android/key.properties` и заполните:

```properties
storePassword=<your_password>
keyPassword=<your_password>
keyAlias=lira
storeFile=/home/your_user/lira-release-key.jks
```

⚠ **Важно:** `key.properties` и `.jks` файлы добавлены в `.gitignore` — не коммитьте их!

### Логи

Логи сборки сохраняются в `build_dist/build_*.log`

---

## build_android.sh

Упрощённый скрипт для сборки только Android APK/AAB.

### Использование

```bash
# Release сборка
./scripts/build_android.sh release

# Debug сборка
./scripts/build_android.sh debug
```

### Особенности

- Проверяет наличие `key.properties` для release сборок
- Предлагает собрать App Bundle (.aab) для Google Play
- Показывает команду для установки на устройство

---

## generate_keystore.sh

Скрипт для генерации keystore для подписывания Android release сборок.

### Использование

```bash
./scripts/generate_keystore.sh
```

Скрипт интерактивно запросит:
- Путь к keystore файлу
- Alias для ключа
- Пароли (через keytool)

После выполнения следуйте инструкциям для создания `key.properties`.
