# Практика 2

Предметная область: система управления коворкингом.

## Состав

- `docs/er.md` - ER-диаграмма Mermaid в нотации Crow's Foot.
- `schema.sql` - DDL PostgreSQL.
- `queries/02_constraints.sql` - проверки.
- `docker-compose.yml` - Docker compose для запуска контейнеров DB и Adminer.

## Запуск

Выполнять команды из корневой папки проекта.

1. Применить схему:

```bash
docker exec -i course_db psql -v ON_ERROR_STOP=1 -U app -d coworking < schema.sql
```

2. Запустить проверки:

```bash
docker exec -i course_db psql -v ON_ERROR_STOP=1 -U app -d coworking < queries/02_constraints.sql
```

3. Посмотреть содержимое таблицы:
```bash
docker exec -it course_db psql -U app -d coworking -c "SELECT * FROM app_user;"
```

В выводе ожидаются сообщения `NOTICE: OK: ...`. Негативные тесты перехватывают ожидаемые ошибки, поэтому весь файл продолжает выполняться. В конце выводится количество строк. Файл тестов заканчивается `ROLLBACK`, поэтому тестовые данные не сохраняются.

`schema.sql` также удаляет одноименные таблицы перед созданием. При уже существующем Docker volume изменения `init.sql` не применяются автоматически. Для этого нужно использовать явный запуск `schema.sql`.

## Ключи

### 1. Пользователь (`app_user`)

Выбран суррогатный первичный ключ `user_id` (BIGINT), а `email` - альтернативный ключ с `UNIQUE`.

Email может измениться. Если бы он был PK, его изменение потребовало бы обновить все внешние ключи в связанных таблицах, например в `booking` и `user_phone`, а также затронуло бы индексы и ссылки. С `user_id` изменение email меняет только значение альтернативного ключа, а связи остаются прежними.

### 2. Помещение (`room`)

Выбран суррогатный PK `room_id` (BIGINT), а `code` - это альтернативный уникальный ключ.

Код помещения может измениться при реорганизации или перенумерации. Если использовать `code` как PK, изменение кода затронет все внешние ключи, ссылающиеся на помещение, и связанные индексы. С `room_id` меняется только `code`, а ссылки на помещение остаются стабильными.

**Вывод:** Суррогатные ключи дают стабильные связи между таблицами. Естественные идентификаторы (`email`, `code`) сохраняются как альтернативные ключи, чтобы не допускать дубликатов.

## Ответы на вопросы

**Какое ограничение оказалось сложнее всего сформулировать?**

Сложнее всего оказалось ограничение `EXCLUDE` для бронирований. Обычный `UNIQUE` не запрещает пересечение временных интервалов. Поэтому используется GIST и `tstzrange(start_at, end_at, '[)')` с оператором пересечения `&&`. Ограничение действует только для активных статусов `pending` и `confirmed`.

**Где пришлось выбирать между "строго" и "гибко"?**

При выборе `ON DELETE`. Для бронирований выбрано строгое `RESTRICT`, чтобы сохранить историю. Для телефонов и связок комната-удобство используется `CASCADE`, потому что эти записи не имеют самостоятельного смысла без владельца или комнаты. Для дочерних помещений выбрано `SET NULL`. При удалении родителя они сохраняются как самостоятельные помещения.

## Результаты запуска

<img width="793" height="563" alt="schema" src="https://github.com/user-attachments/assets/40b7cb32-6cc6-41d7-a70d-ecebaf504d5b" />

```
$ docker exec -i course_db psql -v ON_ERROR_STOP=1 -U app -d coworking < schema.sql
NOTICE:  extension "btree_gist" already exists, skipping
CREATE EXTENSION
DROP TABLE
DROP TABLE
DROP TABLE
DROP TABLE
DROP TABLE
DROP TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
ALTER TABLE
CREATE TABLE
CREATE TABLE
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
```

<img width="952" height="785" alt="1_constraints" src="https://github.com/user-attachments/assets/be2e5fea-e6e2-4fad-a989-76a35706812f" />

<img width="930" height="649" alt="2_constraints" src="https://github.com/user-attachments/assets/b949db03-f23a-4997-8470-923629ffeb37" />


```
bulterier04@DESKTOP-M20FOQ0 MINGW64 ~/Desktop/university/itmo_1/sql/2
$ docker exec -i course_db psql -v ON_ERROR_STOP=1 -U app -d coworking < queries/02_constraints.sql
BEGIN
TRUNCATE TABLE
INSERT 0 2
INSERT 0 2
UPDATE 1
INSERT 0 2
INSERT 0 1
INSERT 0 1
INSERT 0 1
DO
NOTICE:  OK: DEFAULT booking.status
NOTICE:  OK: ожидаемая ошибка NOT NULL app_user.email
DO
DO
NOTICE:  OK: ожидаемая ошибка UNIQUE app_user.email
NOTICE:  OK: ожидаемая ошибка CHECK capacity > 0
DO
NOTICE:  OK: ожидаемая ошибка CHECK booking time
DO
DO
NOTICE:  OK: ожидаемая ошибка FOREIGN KEY booking.room_id
NOTICE:  OK: ожидаемая ошибка составного PRIMARY KEY room_amenity
DO
NOTICE:  OK: ожидаемая ошибка CHECK room_amenity.quantity
DO
DO
NOTICE:  OK: ожидаемая ошибка EXCLUSION пересечения броней
INSERT 0 1
DO
NOTICE:  OK: ожидаемая ошибка ON DELETE RESTRICT пользователя с бронью
INSERT 0 1
INSERT 0 1
DELETE 1
DO
NOTICE:  OK: ON DELETE CASCADE user_phone
    entity    | rows_count 
--------------+------------
 app_user     |          2
 room         |          2
 booking      |          2
 amenity      |          2
 room_amenity |          1
 user_phone   |          1
(6 rows)

ROLLBACK
```
