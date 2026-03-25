# СТАТУСЫ И ПЕРЕХОДЫ

Единый справочник. Все агенты ссылаются на этот файл.

## Порядок статусов

```
To Do → In Progress → qdev-check → code-review → review-debug → ready-for-testing → review-human-await → Done
```

## Допустимые переходы

| Из | В | Кто выполняет | Условие |
|----|---|---------------|---------|
| To Do | In Progress | DEV | Агент запущен и начал работу |
| In Progress | qdev-check | DEV | DEV завершил, код запушен |
| qdev-check | code-review | QDEV | Проверка запускаемости пройдена (PASS) |
| qdev-check | review-debug | QDEV | Проверка не пройдена (FAIL) |
| code-review | ready-for-testing | REVIEW | Код одобрен |
| code-review | review-debug | REVIEW | Код отклонён (TRY < 3) |
| code-review | review-human-await | REVIEW | Код отклонён 3+ раз |
| review-debug | In Progress | DEV | DEV берёт исправления |
| ready-for-testing | Done | PM/QA | QA Gate пройден |
| ready-for-testing | To Do | QA | Баги найдены |
| * | cancelled | PM | Задача не нужна |

## Валидация перехода

Перед изменением статуса агент проверяет:

```
1. Текущий статус задачи (backlog__task_get)
2. Допустим ли переход из текущего в целевой (таблица выше)
3. Выполнено ли условие перехода

Если переход недопустим:
  → НЕ менять статус
  → Записать: [PM-LOG action:blocked | details: {причина}]
```

## Специальные статусы

- **review-human-await** — задача отклонена 3+ раз. Ожидает ручного ревью. PM эскалирует человеку.
- **cancelled** — задача закрыта без выполнения. Допустим переход из любого статуса.

## Конфигурация .backlog/config.yml

```yaml
statuses:
  - To Do
  - In Progress
  - qdev-check
  - code-review
  - review-debug
  - ready-for-testing
  - review-human-await
  - Done
```
