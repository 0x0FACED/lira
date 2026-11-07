# Выпуск Lira

Основной путь — GitHub Actions в репозитории [`0x0FACED/lira`](https://github.com/0x0FACED/lira). Workflow использует Flutter **3.41.6**, сначала выполняет reusable CI (`ci.yml`), затем собирает Android, iOS, Windows, Linux и macOS. Push тега `v*` автоматически публикует GitHub Release после успеха всех сборок.

Это инструкция для пользователя: команды commit/push выполняются только после проверки выбранных изменений. Локальная правка workflow сама по себе не меняет GitHub Actions.

## 1. Доступ и Android secrets

Если авторизация уже настроена, достаточно проверить её:

```bash
gh auth status --hostname github.com
```

При необходимости войдите интерактивно:

```bash
gh auth login --hostname github.com --git-protocol https --web
```

Для Android release нужны четыре repository secrets:

| Secret | Значение |
|---|---|
| `ANDROID_KEYSTORE` | Содержимое keystore, закодированное в base64 |
| `KEY_STORE_PASSWORD` | Пароль хранилища |
| `KEY_PASSWORD` | Пароль ключа |
| `KEY_ALIAS` | Alias ключа |

Если keystore и secrets уже созданы, **не создавайте ключ заново** и пропустите загрузку. Проверьте только имена secrets, без чтения значений:

```bash
gh secret list --repo 0x0FACED/lira
```

Для первоначальной настройки создайте ключ, только если его ещё нет:

```bash
bash scripts/generate_keystore.sh
```

Сохраните keystore и пароли в защищённом резервном хранилище. Для обновлений используйте тот же ключ.

Загрузите keystore из выбранного файла; пример ниже использует путь по умолчанию генератора. Python одинаково кодирует base64 на macOS и Linux, без временного файла:

```bash
python3 -c 'import base64, pathlib, sys; sys.stdout.write(base64.b64encode(pathlib.Path(sys.argv[1]).read_bytes()).decode("ascii"))' \
  "$HOME/lira-release-key.jks" |
  gh secret set ANDROID_KEYSTORE --repo 0x0FACED/lira

gh secret set KEY_STORE_PASSWORD --repo 0x0FACED/lira
gh secret set KEY_PASSWORD --repo 0x0FACED/lira
gh secret set KEY_ALIAS --repo 0x0FACED/lira
```

Последние три команды запрашивают значения интерактивно: пароли не попадают в argv или историю shell. Не передавайте их через `--body` и не включайте трассировку shell.

## 2. Отправить проверенный код в GitHub

Сначала отправьте **необходимые изменения приложения и релизные файлы** в `main` напрямую либо через проверенный PR. Удалённый workflow не использует локальные изменения.

Для `0.7.2` включите исправление однострочных заголовков библиотеки и подборки вместе с регрессионными тестами:

```bash
git status --short
git add -- pubspec.yaml CHANGELOG.md RELEASE.md \
  lib/core/widgets/app_components.dart \
  lib/features/books/presentation/library_screen.dart \
  lib/features/discover/presentation/discover_screen.dart \
  test/discover_layout_test.dart test/library_layout_test.dart
```

Это список для текущего выпуска, а не универсальный staging-скрипт. Он не включает локальные EPUB, артефакты, посторонние изменения `.gitignore` и личные заметки. `TODO.md`, `READER.md`, `UI.md` и `QUICK_RELEASE.md` игнорируются как локальные заметки; не добавляйте их принудительно. Если файл содержит другие изменения, выберите нужные hunks через `git add -p -- путь` вместо добавления всего файла. Перед commit проверьте полный staged diff.

Не используйте `git add .`: в рабочем дереве могут быть unrelated изменения и EPUB fixtures, не относящиеся к релизу. Не добавляйте keystore или `android/key.properties`.

После проверки полного staged diff создайте commit. Следующие команды предполагают работу на `main`; при работе в другой ветке сначала отправьте её и завершите review/merge PR:

```bash
git diff --cached
git commit -m "release: v0.7.2"
git push origin main
```

## 3. Первый запуск — manual, без tag

После появления нового кода в `main` запустите release-сборку без публикации Release:

```bash
gh workflow run build.yml --ref main -f build_type=release --repo 0x0FACED/lira
gh run list --repo 0x0FACED/lira --workflow build.yml \
  --branch main --event workflow_dispatch --limit 5
```

Выберите ID именно своего запуска из списка:

```bash
printf 'Run ID: '; read -r RUN_ID
gh run watch "$RUN_ID" --repo 0x0FACED/lira --exit-status
gh run download "$RUN_ID" --repo 0x0FACED/lira --dir "build_dist/github-actions/$RUN_ID"
```

`watch --exit-status` сообщает об ошибке workflow; скачанные артефакты сами по себе не доказывают успешность всех jobs. Для диагностики:

```bash
gh run view "$RUN_ID" --repo 0x0FACED/lira --log-failed
```

Для debug вместо release:

```bash
gh workflow run build.yml --ref main -f build_type=debug --repo 0x0FACED/lira
```

Debug APK использует debug-подпись и не требует release secrets. **Release требует настоящий keystore: fallback на debug-подпись отсутствует.** AAB собирается только в release.

| Имя Actions artifact | Содержимое |
|---|---|
| `android-apk` | APK выбранного build type |
| `android-aab` | Подписанный AAB, только release |
| `ios-ipa` | `lira-ios-unsigned.ipa` для самостоятельной подписи |
| `linux-zip` | Linux bundle в ZIP |
| `windows-zip` | Windows bundle в ZIP |
| `macos-dmg` | macOS DMG |

Manual-запуск не создаёт GitHub Release, даже при `build_type=release`.

APK и AAB собираются в независимых matrix jobs на отдельных runners. Это исключает накопление промежуточных файлов обеих упаковок на одном диске и позволяет скачать готовый APK, даже если AAB завершился ошибкой. Для Android debug запускается только APK.

## Описание релиза из CHANGELOG

Описание GitHub Release берётся из `CHANGELOG.md` на коммите тега. Для `v0.7.2` нужен ровно один непустой раздел `## [0.7.2]`; дата после заголовка необязательна. Перед тегом перенесите готовые пункты из `[Unreleased]` в раздел новой версии. Markdown, русский текст и подразделы `### Changed` / `### Fixed` сохраняются.

Пример раздела:

```markdown
## [0.7.2] - 2026-11-08

### Fixed
- Библиотека и подборка: заголовок экрана и кнопки справа снова расположены в одной строке, в том числе на узких экранах.
```

После добавления раздела проверьте будущий текст до создания тега:

```bash
python3 scripts/extract_release_notes.py v0.7.2
```

Заголовок версии не дублируется в описании, изменения соседних версий и `[Unreleased]` не включаются. Внизу workflow добавляет предупреждения об установке iOS/macOS. Автоматический список коммитов/PR отключён.

Если раздел отсутствует, пуст или продублирован, подготовка описания завершается ошибкой и релиз не публикуется — подмены другим текстом нет. Изменения `CHANGELOG.md` должны попасть в commit **до** тега; manual-сборка релиз не публикует и этот раздел не требует.

Если ошибка обнаружена уже после отправки тега, обычный `Re-run jobs` снова использует его прежний commit, а не исправленный `main`. Не переносите существующий тег: подготовьте следующую версию и build number, оформите её раздел changelog, проверьте предпросмотр, отправьте commit и создайте новый тег.

## Проверки перед публикацией

Ограничение Anna’s Archive сохраняется: доступ может требовать браузерной проверки для того же домена/IP/User-Agent. Публикация приложения не снимает HTTP 403 на стороне источника. Не описывайте это как безусловно восстановленный анонимный поиск.

Сначала выполните `flutter pub get` из корня и `dart pub get` из `packages/zlibrary_api`. Затем запустите проверки из корня:

```bash
python3 -m unittest discover -s scripts -p 'test_*.py'
python3 scripts/extract_release_notes.py v0.7.2
dart analyze lib test packages/zlibrary_api/lib packages/zlibrary_api/test
flutter build macos --debug --no-pub
PDFIUM_PATH="$PWD/build/macos/Build/Products/Debug/pdfrx/pdfrx.framework/pdfrx" \
  flutter test --no-pub test packages/epub_engine/test packages/pdf_engine/test
```

Тесты чистого Dart-пакета запускаются дополнительно командой `dart test` из `packages/zlibrary_api`. CI выполняет оба набора перед платформенными сборками.

Перед широкой раздачей `0.7.2` проверьте на устройстве обновление поверх `0.7.1` тем же ключом и сохранность библиотеки, настроек, прогресса и пометок. Основной smoke: библиотека и подборка на узком экране и с увеличенным шрифтом — название и действия справа остаются в одной строке, кнопки доступны; при нехватке места название сокращается многоточием. В библиотеке проверьте меню плотности и импорт, в подборке — переход к источникам. Не очищайте данные приложения ради проверки; desktop smoke и unit-тесты не заменяют прогон на реальных телефонах.

Дополнительная проверка поведения, добавленного в `0.6.8`: на HyperOS проверьте автоприменение высокой частоты без ADB после возврата из фона и после перезагрузки телефона; на других производителях — сохранение стандартного поведения. Индикатор Гц измеряет режим дисплея, а не FPS содержимого.

Ранее выданное через ADB исключение на 120 Гц может маскировать результат. Для чистой проверки на HyperOS временно назначьте только Lira 60 Гц, затем уведите установленную release-сборку в фон и вернитесь: приложение должно самостоятельно повторить запрос высокой частоты. Команда не меняет данные Lira или настройки других пакетов:

```bash
adb shell am broadcast \
  -a com.xiaomi.joyose.OVERRIDE_GAME_FRESHRATE \
  -p com.miui.powerkeeper --receiver-registered-only \
  --es override_pkg_name dev.u0xfaced.lira --ei override_freshrate 60
```

Этот OEM-интерфейс проверен на POCO F7 с HyperOS 3 / Android 16. Не обещайте его поддержку на любой прошивке и не очищайте данные PowerKeeper/Joyose ради проверки.

## 4. Новый release tag и автоматическая публикация

Для следующего выпуска подготовлены `0.7.2+21` в `pubspec.yaml` и раздел `[0.7.2]` в `CHANGELOG.md`. Перед каждым последующим релизом повышайте версию и build number и оформляйте соответствующий раздел. Проверьте и отправьте изменения в `main`; если код изменился после manual-проверки, повторите её.

Существующие теги не переиспользуются и не перемещаются, даже если публикация предыдущего релиза не состоялась. Для нового выпуска используйте `v0.7.2`, согласованный с `pubspec.yaml` и `CHANGELOG.md`:

```bash
VERSION=0.7.2
git tag --list "v$VERSION"
git ls-remote --tags origin "refs/tags/v$VERSION" "refs/tags/v$VERSION^{}"
```

Продолжайте только если tag отсутствует и локально, и на GitHub. Создайте его на проверенном коммите `main` и отправьте **только этот tag**:

```bash
git tag "v$VERSION" main
git push origin "v$VERSION"
gh run list --repo 0x0FACED/lira --workflow build.yml --event push --limit 5
```

Push tag `v*` запускает release-сборку. После успешного CI и **всех пяти платформ** один publish job **публикует GitHub Release**, не черновик, и прикрепляет все шесть файлов. При ошибке любой сборки публикация не выполняется. Дождитесь нужного запуска через `gh run watch`, как выше.

Файлы GitHub Release называются `lira-<platform>-<tag>.<extension>`. Для тега `v0.7.2`:

- `lira-android-v0.7.2.apk`
- `lira-android-v0.7.2.aab`
- `lira-linux-v0.7.2.zip`
- `lira-windows-v0.7.2.zip`
- `lira-macos-v0.7.2.dmg`
- `lira-ios-v0.7.2.ipa` (без подписи)

Переименование выполняется в publish job; имена Actions artifacts и файлов manual-сборки из раздела 3 не меняются.

Откройте опубликованный релиз и проверьте файлы и описание:

```bash
gh release view "v$VERSION" --repo 0x0FACED/lira --web
```

## Обновление из приложения

Настройки читают последний стабильный релиз через публичный GitHub API (`releases/latest`); draft и prerelease не предлагаются. Для текущего pipeline тег — `vMAJOR.MINOR.PATCH`, версия в `pubspec.yaml` должна ему соответствовать. Перед новым выпуском повышайте и публичную версию, и Android build number: установщик запрещает `versionCode`, не превышающий установленный.

Для скачивания внутри Android имя asset должно быть **`lira-android-<tag>.apk`**, например `lira-android-v0.7.2.apk`, строго с тегом этого релиза. Приложение использует размер и `digest: sha256:…` из GitHub API, проверяет скачанный файл, затем нативно проверяет package name, `versionName`, `versionCode` и текущую подпись. Используйте прежний release keystore: APK с другим текущим подписантом, включая debug APK, не обновит установленную release-сборку. Ротация ключа этим механизмом не поддерживается.

Без APK с корректным digest релиз остаётся доступен по кнопке перехода на GitHub, но скачивание внутри приложения не предлагается. На iOS и desktop всегда используется только страница релиза; формат остальных артефактов не меняется.

Версии приложения со старым поиском `app-release.apk` не предложат скачивание нового именованного APK внутри приложения; для первого обновления используйте переход на страницу GitHub Release.

## Подпись и границы pipeline

- `scripts/configure_android_signing.py` читает четыре signing-переменные из окружения и создаёт `android/ci-release-key.jks` и `android/key.properties` с правами `0600`. Он записывает абсолютный `storeFile`, экранирует Java Properties и **не перезаписывает существующие файлы**. CI удаляет созданные signing files после сборки, в том числе при ошибке.
- Для ручного заполнения `android/key.properties.template` используйте **абсолютный** `storeFile`. Это Java Properties, не shell: обратный слеш требует `\\`, Unicode — соответствующих `\uXXXX` escape-последовательностей; простой вставки пароля может быть недостаточно. Helper делает escaping автоматически. Подробнее: [scripts/README.md](scripts/README.md).
- Web не поддерживается текущим приложением из-за `dart:io` и native SQLite; web artifact отсутствует.
- iOS собирается без Apple-секретов: `lira-ios-<tag>.ipa` в GitHub Release (`lira-ios-unsigned.ipa` в Actions artifact) содержит device build в `Payload/Runner.app`. Перед установкой подпишите IPA через AltStore, Sideloadly или аналогичный инструмент. Неподписанный IPA напрямую не устанавливается; это не пакет для App Store/TestFlight.
- macOS DMG собирается **без Developer ID и notarization**. Gatekeeper может препятствовать запуску; этот pipeline не решает задачу доверенного распространения macOS.
- Публикация в Google Play, других сторах или App Store здесь не автоматизирована; наличие AAB/DMG не означает готовности к публикации в них.
- Минимальная версия macOS — **11.0**: deployment target приложения и pods не ниже target готового PDFium. Поддержка macOS 10.15 этой сборкой не заявляется.

Релизные команды приведены в разделе 4. Локальные EPUB, временные проверки и личные заметки не добавляйте в релизный коммит.
