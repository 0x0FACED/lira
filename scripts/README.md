# Скрипты Lira

Запускайте команды из корня репозитория. Основной release pipeline — `.github/workflows/build.yml` с Flutter **3.41.6**; локальные shell-скрипты не заменяют его.

Сначала отправьте workflow **и необходимые изменения приложения** в GitHub. Первый запуск — manual без tag:

```bash
gh workflow run build.yml --ref main -f build_type=release --repo 0x0FACED/lira
```

Для авторизации, настройки secrets без паролей в argv, targeted staging, ожидания и скачивания артефактов используйте [RELEASE.md](../RELEASE.md). Не используйте `git add .`; миграцию reader добавляйте отдельным осознанным набором проверенных файлов.

## `configure_android_signing.py`

Python 3 helper для Android release signing. Читает из окружения:

| Переменная | Значение |
|---|---|
| `ANDROID_KEYSTORE` | Keystore в base64 |
| `KEY_STORE_PASSWORD` | Пароль хранилища |
| `KEY_PASSWORD` | Пароль ключа |
| `KEY_ALIAS` | Alias ключа |

После безопасной передачи переменных в окружение:

```bash
python3 scripts/configure_android_signing.py
```

Helper создаёт:

- `android/ci-release-key.jks`;
- `android/key.properties` с **абсолютным** `storeFile`.

Оба файла получают права `0600`. Значения экранируются в формате Java Properties, включая backslash и Unicode. Helper **не перезаписывает существующие файлы**; перед повторным локальным использованием сохраните нужные существующие ключи и конфигурацию. Не коммитьте signing files и не выводите содержимое secrets в логи.

GitHub Actions передаёт четыре repository secrets в окружение helper и удаляет созданные файлы после сборки, в том числе при ошибке. Debug не запускает release signing и не требует этих secrets. Release без правильного ключа завершается ошибкой: fallback на debug-подпись отсутствует.

### Ручная конфигурация вместо helper

`android/key.properties.template` — только шаблон. Для создания `android/key.properties` укажите абсолютный путь, например:

```properties
storeFile=/absolute/path/to/lira-release-key.jks
storePassword=<escaped-keystore-password>
keyPassword=<escaped-key-password>
keyAlias=lira
```

Замените placeholders собственными значениями. Это **Java Properties**, не shell: `\` записывается как `\\`, Unicode — через соответствующие `\uXXXX` escape-последовательности. Также учитывайте правила escaping разделителей и пробелов. Не вставляйте сложный пароль без экранирования: загруженное значение может отличаться от исходного. Helper выполняет это преобразование автоматически.

Храните `key.properties` с ограниченным доступом и никогда не добавляйте его или keystore в Git.

## `generate_keystore.sh`

Интерактивное создание **нового** Android signing key через `keytool` (нужен JDK):

```bash
bash scripts/generate_keystore.sh
```

Скрипт запрашивает путь и alias; `keytool` запрашивает пароли. Путь по умолчанию — `$HOME/lira-release-key.jks`. Если ключ уже существует, не генерируйте замену ради повторного запуска pipeline. Сохраните ключ и пароли в защищённом резервном хранилище.

Загрузку secrets выполняйте командами из [RELEASE.md](../RELEASE.md#1-доступ-и-android-secrets), а не передачей паролей в аргументах.

## `build_android.sh`

Локальная Android-сборка; нужны Flutter, Android SDK и JDK:

```bash
bash scripts/build_android.sh debug
bash scripts/build_android.sh release
```

- Debug создаёт APK без release secrets.
- Release требует заранее настроенный `android/key.properties` и соответствующий ключ; без конфигурации сборка завершается ошибкой.
- После release APK скрипт предлагает отдельно собрать AAB. AAB в этом сценарии — только release; загрузка в store не выполняется.
- Результаты: `build/app/outputs/flutter-apk/app-debug.apk` или `app-release.apk`; release AAB — `build/app/outputs/bundle/release/app-release.aab`.

## Legacy-скрипты

### `create_release.sh`

**Не используйте для текущего release-процесса.** Скрипт меняет версию/changelog, может выполнить широкий staging, commit и создать tag; использует GNU-совместимый `sed -i`, непереносимый на стандартный macOS `sed`. Вместо него вручную обновите версию и build number, проверьте точные staged-файлы и следуйте [RELEASE.md](../RELEASE.md). `v0.5.0` уже существует; tags не переиспользуются.

### `build_all.sh`

Legacy-скрипт с устаревшим набором целей, включая Web/iOS, и логикой копирования выходных файлов. Он не является поддерживаемым способом подготовки полного release и не гарантирует комплект артефактов. В текущем приложении Web несовместим с `dart:io` и native SQLite. Используйте нативный CI, а не этот скрипт.

### `set_icon.sh`

Вспомогательный legacy-скрипт: копирует исходную иконку в `assets/icon/icon.png`, вызывает генератор, копирует web-иконки и может предложить Android rebuild. Ошибка генератора в нём подавляется, поэтому сообщение об успехе не подтверждает корректность иконок. Проверяйте изменения вручную; скрипт не подтверждает поддержку Web или готовность release.

## Границы CI

После CI собираются Android, Linux, Windows и macOS. Artifacts: `android-apk`, `android-aab` (только release), `linux-zip`, `windows-zip`, `macos-dmg`. Manual-запуск не создаёт GitHub Release. На push нового tag `v*` один publish job создаёт единый draft только после успеха всех четырёх платформ.

iOS и публикация в сторах не настроены. macOS DMG собирается без Developer ID и notarization; ограничения Gatekeeper этим pipeline не устраняются.
