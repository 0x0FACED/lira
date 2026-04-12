# Lira Release Guide

Как сделать полноценный релиз приложения.

---

## 📋 Чеклист релиза

- [ ] Обновить версию в `pubspec.yaml`
- [ ] Обновить `CHANGELOG.md`
- [ ] Протестировать приложение
- [ ] Создать Git tag
- [ ] Собрать билды
- [ ] Опубликовать релиз на GitHub
- [ ] (Опционально) Опубликовать в сторах

---

## 1. Подготовка

### Обновить версию

Откройте `pubspec.yaml` и измените версию:

```yaml
version: 0.5.0+2  # major.minor.patch+build_number
```

**Версионирование (SemVer):**
- `0.3.0` — minor release (новая функциональность)
- `0.3.1` — patch release (багфиксы)
- `1.0.0` — major release (значительные изменения)

### Обновить CHANGELOG.md

Создайте или обновите файл `CHANGELOG.md`:

```markdown
## [0.5.0] - 2026-04-12

### Added
- Опция single-page horizontal mode для EPUB
- Улучшения поиска и импорта обложек

### Changed
- Обновлена версия приложения на 0.5.0
- Улучшен native EPUB reader

### Fixed
- Исправлены ошибки компиляции Android
```

### Закоммитить изменения

```bash
git add .
git commit -m "chore: prepare release v0.3.0"
```

---

## 2. Сборка

### Локальная сборка (все платформы)

```bash
./scripts/build_all.sh release
```

Билды сохранятся в `build_dist/`.

### Сборка только Android

```bash
./scripts/build_android.sh release
```

### Автоматическая сборка (GitHub Actions)

1. Создайте tag:
   ```bash
   git tag v0.5.0
   git push origin v0.5.0
   ```

2. GitHub Actions автоматически:
   - Соберёт билды под все платформы
   - Создаст черновик релиза на GitHub
   - Прикрепит артефакты

---

## 3. Публикация

### GitHub Release

1. Перейдите на https://github.com/your-username/lira/releases
2. Найдите черновик релиза (Draft)
3. Отредактируйте описание
4. Нажмите "Publish release"

### Шаблон описания релиза

```markdown
## Lira v0.5.0

### 📱 Что нового

- Новая функция X
- Улучшения интерфейса
- Исправления багов

### 📦 Файлы для скачивания

- **Android**: `lira-release-android.apk` ( APK)
- **Android (Google Play)**: `lira-release-android.aab`
- **Linux**: `lira-release-linux.zip`
- **Windows**: `lira-release-windows.zip`
- **macOS**: `Lira.dmg`
- **Web**: `web-build.zip`

### 🔧 Технические детали

- Flutter version: 3.24.0
- Dart version: 3.9.4
- Min SDK: Android 5.0 (API 21)

### 📝 Полный changelog

См. [CHANGELOG.md](CHANGELOG.md)
```

---

## 4. Публикация в сторах (опционально)

### Google Play Store

1. Войдите в [Google Play Console](https://play.google.com/console)
2. Выберите приложение
3. Создайте новый релиз
4. Загрузите `app-release.aab`
5. Заполните описание изменений
6. Отправьте на ревью

### RuStore

1. Войдите в [RuStore Console](https://console.rustore.ru)
2. Создайте релиз
3. Загрузите APK или AAB
4. Заполните метаданные

---

## 🔐 Подпись Android

### Первый релиз

Для первого релиза нужно создать keystore:

```bash
./scripts/generate_keystore.sh
```

**Важно:**
- Сохраните keystore в надёжном месте
- Запомните пароли
- Сделайте бэкап!

**Без keystore** нельзя будет выпускать обновления приложения.

### Настройка

Создайте `android/key.properties`:

```properties
storePassword=your_password
keyPassword=your_password
keyAlias=lira
storeFile=/path/to/lira-release-key.jks
```

### GitHub Actions (секреты)

Для автоматической подписи в CI добавьте секреты:

1. `ANDROID_KEYSTORE` — base64 закодированный keystore
2. `KEY_STORE_PASSWORD` — пароль keystore
3. `KEY_PASSWORD` — пароль ключа
4. `KEY_ALIAS` — алиас ключа

```bash
# Закодировать keystore
base64 -w 0 lira-release-key.jks > keystore_base64.txt
```

---

## 🚀 Автоматизация

### Создать релиз одной командой

```bash
# Скрипт prepare_release.sh
VERSION="0.5.0"

# Обновить версию
sed -i "s/version: .*/version: ${VERSION}+1/" pubspec.yaml

# Закоммитить
git add pubspec.yaml
git commit -m "chore: release v${VERSION}"

# Создать tag
git tag "v${VERSION}"

# Отправить
git push origin main --tags
```

После этого GitHub Actions автоматически соберёт все билды.

---

## 📊 Версии и build numbers

| Версия | Описание |
|--------|----------|
| `0.1.0+1` | Первый альфа-релиз |
| `0.2.0+1` | Добавлена поддержка EPUB |
| `0.5.0+2` | Текущий релиз |
| `1.0.0+1` | Стабильная версия |

**Build number** (`+1`) увеличивается при каждом билде для стора.

---

## 🆘 Troubleshooting

### Ошибка подписи Android

```
Signing failed: keystore file not found
```

**Решение:** Создайте `android/key.properties` с правильным путём.

### GitHub Actions не запускается

**Решение:** Проверьте, что tag начинается с `v` (например, `v0.3.0`).

### Билд не проходит на macOS

**Решение:** Убедитесь, что установлен Xcode и приняты лицензионные соглашения:
```bash
sudo xcodebuild -license accept
```

---

## 📚 Ссылки

- [Flutter Release Guide](https://docs.flutter.dev/deployment/android)
- [SemVer Specification](https://semver.org)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Google Play Publishing](https://developer.android.com/distribute/best-practices/launch)
