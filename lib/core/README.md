# Lira Core (Data & API)

Реализация контракта взаимодействия приложения:
1. `core/network/` — DI модуль для `Dio` и сгенерированный API клиент (`ApiClient`) на базе Retrofit.
2. `core/database/` — Инициализация локальной базы данных Drift (`AppDatabase`) с таблицами: `Books`, `ReadingProgresses`, `Highlights`.
3. `features/.../domain/models/` — `freezed` DTO объекты (`BookDto`, `ReadingProgressDto`, `HighlightDto`), настроенные на `snake_case` маппинг для будущего сервера.

## Использование БД
Инжектируйте `AppDatabase` через DI в репозитории для доступа к DAO.

## Пример API
Инжектируйте `ApiClient` для удаленных HTTP вызовов. 
Базовый URL пока захардкожен в `DioModule` и должен быть вынесен в `.env`.
