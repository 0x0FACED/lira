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

Сначала отправьте **новый workflow и необходимые изменения приложения** в `main` напрямую либо через проверенный PR. Не запускайте удалённый workflow, пока на GitHub остаётся старый код.

Проверьте рабочее дерево и добавьте только файлы release pipeline:

```bash
git status --short
git add -- .github/workflows/build.yml .github/workflows/ci.yml \
  android/app/build.gradle.kts scripts/configure_android_signing.py \
  scripts/extract_release_notes.py scripts/test_extract_release_notes.py \
  scripts/build_android.sh README.md RELEASE.md QUICK_RELEASE.md scripts/README.md BUILD_SUMMARY.md ios
git add -p -- pubspec.yaml CHANGELOG.md
```

**Отдельно и осознанно добавьте миграцию reader и остальные необходимые application changes.** Выберите точные пути из `git status`, просмотрите их diff и используйте `git add --` с перечислением файлов; для отдельных изменений tracked-файлов используйте `git add -p --` с выбранными путями. Учтите нужные новые файлы, удаления и изменения зависимостей. Команды выше не включают миграцию автоматически.

Не используйте `git add .`: в рабочем дереве могут быть unrelated изменения и EPUB fixtures, не относящиеся к релизу. Не добавляйте keystore или `android/key.properties`.

После проверки полного staged diff создайте commit. Следующие команды предполагают работу на `main`; при работе в другой ветке сначала отправьте её и завершите review/merge PR:

```bash
git diff --cached
git commit -m "ci: prepare native release pipeline"
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

Описание GitHub Release берётся из `CHANGELOG.md` на коммите тега. Для `v0.5.2` нужен ровно один непустой раздел `## [0.5.2]`; дата после заголовка необязательна. Перед тегом перенесите готовые пункты из `[Unreleased]` в раздел новой версии. Markdown, русский текст и подразделы `### Added` / `### Fixed` сохраняются.

Пример раздела:

```markdown
## [0.5.2] - 2026-10-23

### Added
- Сборка iOS IPA для самостоятельной подписи.

### Fixed
- Исправлено восстановление позиции чтения.
```

После добавления раздела проверьте будущий текст до создания тега:

```bash
python3 scripts/extract_release_notes.py v0.5.2
```

Заголовок версии не дублируется в описании, изменения соседних версий и `[Unreleased]` не включаются. Внизу workflow добавляет предупреждения об установке iOS/macOS. Автоматический список коммитов/PR отключён.

Если раздел отсутствует, пуст или продублирован, подготовка описания завершается ошибкой и релиз не публикуется — подмены другим текстом нет. Изменения `CHANGELOG.md` должны попасть в commit **до** тега; manual-сборка релиз не публикует и этот раздел не требует.

Если ошибка обнаружена уже после отправки тега, обычный `Re-run jobs` снова использует его прежний commit, а не исправленный `main`. Не переносите существующий тег: подготовьте следующую версию и build number, оформите её раздел changelog, проверьте предпросмотр, отправьте commit и создайте новый тег.

## 4. Новый release tag и автоматическая публикация

Для следующего выпуска подготовлены `0.5.2+4` в `pubspec.yaml` и раздел `[0.5.2]` в `CHANGELOG.md`. Перед каждым последующим релизом повышайте версию и build number и оформляйте соответствующий раздел. Проверьте и отправьте изменения в `main`; если код изменился после manual-проверки, повторите её.

`v0.5.0` и `v0.5.1` уже существуют; публикация `v0.5.1` не состоялась. Существующие теги не переиспользуются и не перемещаются. Для нового выпуска используйте `v0.5.2`, согласованный с `pubspec.yaml` и `CHANGELOG.md`:

```bash
VERSION=0.5.2
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

Откройте опубликованный релиз и проверьте файлы и описание:

```bash
gh release view "v$VERSION" --repo 0x0FACED/lira --web
```

## Подпись и границы pipeline

- `scripts/configure_android_signing.py` читает четыре signing-переменные из окружения и создаёт `android/ci-release-key.jks` и `android/key.properties` с правами `0600`. Он записывает абсолютный `storeFile`, экранирует Java Properties и **не перезаписывает существующие файлы**. CI удаляет созданные signing files после сборки, в том числе при ошибке.
- Для ручного заполнения `android/key.properties.template` используйте **абсолютный** `storeFile`. Это Java Properties, не shell: обратный слеш требует `\\`, Unicode — соответствующих `\uXXXX` escape-последовательностей; простой вставки пароля может быть недостаточно. Helper делает escaping автоматически. Подробнее: [scripts/README.md](scripts/README.md).
- Web не поддерживается текущим приложением из-за `dart:io` и native SQLite; web artifact отсутствует.
- iOS собирается без Apple-секретов: `lira-ios-unsigned.ipa` содержит device build в `Payload/Runner.app`. Перед установкой подпишите IPA через AltStore, Sideloadly или аналогичный инструмент. Неподписанный IPA напрямую не устанавливается; это не пакет для App Store/TestFlight.
- macOS DMG собирается **без Developer ID и notarization**. Gatekeeper может препятствовать запуску; этот pipeline не решает задачу доверенного распространения macOS.
- Публикация в Google Play, других сторах или App Store здесь не автоматизирована; наличие AAB/DMG не означает готовности к публикации в них.

Краткая последовательность: [QUICK_RELEASE.md](QUICK_RELEASE.md).
