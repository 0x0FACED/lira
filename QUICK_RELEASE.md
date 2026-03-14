# 🚀 Lira - Quick Release Guide

## Быстрый старт для релиза v0.3.0

### 1. Создать релиз (автоматически)

```bash
./scripts/create_release.sh
```

Скрипт спросит версию (введите `0.3.0` или нажмите Enter для предложенной).

### 2. Отправить в Git

```bash
git push origin main --tags
```

GitHub Actions автоматически соберёт билды под все платформы и создаст черновик релиза.

### 3. Или собрать локально

```bash
# Все платформы
./scripts/build_all.sh release

# Только Android
./scripts/build_android.sh release
```

---

## Что уже настроено

✅ Версия: **0.3.0+1**  
✅ Описание: "Lira is your free feature-rich library"  
✅ Автоматическое получение версии в приложении  
✅ Скрипты для сборок  
✅ GitHub Actions workflow  
✅ Документация  

---

## Подпись Android (для production)

Если планируете публиковать в Google Play:

```bash
# 1. Создать keystore
./scripts/generate_keystore.sh

# 2. Создать android/key.properties
cp android/key.properties.template android/key.properties
# Отредактировать с вашими паролями
```

Для тестовых сборок подпись не требуется.

---

## Файлы для релиза

После сборки в `build_dist/` появятся:

| Файл | Платформа |
|------|-----------|
| `lira-release-android.apk` | Android (установка) |
| `lira-release-android.aab` | Android (Google Play) |
| `lira-release-linux.zip` | Linux |
| `lira-release-web/` | Web |
| `lira-release-windows.zip` | Windows |
| `Lira.dmg` | macOS |

---

## Документация

- [`RELEASE.md`](RELEASE.md) — полное руководство по релизам
- [`scripts/README.md`](scripts/README.md) — описание скриптов
- [`CHANGELOG.md`](CHANGELOG.md) — история изменений

---

## Помощь

Если что-то не работает:

1. Проверьте `flutter doctor`
2. Запустите `flutter clean && flutter pub get`
3. Посмотрите логи в `build_dist/build_*.log`
