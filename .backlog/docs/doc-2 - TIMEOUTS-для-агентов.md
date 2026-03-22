---
id: doc-2
title: TIMEOUTS для агентов
type: implementation
created_date: '2026-03-22 13:00'
---

# TIMEOUTS для агентов

> Реализация механизма timeout для всех агентов PM-системы
> Задача: TASK-11
> Дата: 2026-03-22

## Критерий завершённости

PASS: Каждый агент имеет timeout, при timeout записывается лог в backlog
FAIL: Агенты могут зависнуть бесконечно

## Реализованные timeout'ы

| Агент | Timeout | Описание |
|-------|---------|----------|
| SETUP | 10 минут (600000 ms) | Агенты установки инструментов |
| GIT_SYNC | 5 минут (300000 ms) | Синхронизация git |
| SA | 30 минут (1800000 ms) | Аналитик (Spec-Kitty цикл) |
| SCRUM | 15 минут (900000 ms) | Верификация бэклога |
| CONSOLIDATION | 10 минут (600000 ms) | Консолидация артефактов |
| DEV | 20 минут (1200000 ms) | Разработчик (новые задачи) |
| DEV_FIX | 25 минут (1500000 ms) | Разработчик (исправление по review) |
| REVIEW | 10 минут (600000 ms) | Code review |
| QA | 15 минут (900000 ms) | Тестирование |
| DEBUG | 15 минут (900000 ms) | Отладка |

## Изменённые файлы

1. **CLAUDE.md**
   - Добавлена секция `### TIMEOUTS — Ограничение времени выполнения агентов`
   - Добавлен словарь `TIMEOUTS` с константами
   - Обновлены все 17 вызовов `Task()` с параметром `timeout`

2. **.claude/agents/developer.md**
   - Добавлена секция `## TIMEOUT` с информацией о лимитах

3. **.claude/agents/analyst.md**
   - Добавлена секция `## TIMEOUT` с информацией о лимите

4. **.claude/agents/reviewer.md**
   - Добавлена секция `## TIMEOUT` с информацией о лимите

5. **.claude/agents/qa.md**
   - Добавлена секция `## TIMEOUT` с информацией о лимите

## Использование

При вызове агентов PM всегда указывает `timeout=TIMEOUTS["AGENT_TYPE"]`:

```python
Task(
  description="DEV: {task.title}",
  prompt=f"...",
  model="claude-opus-4-5",
  subagent_type="general-purpose",
  timeout=TIMEOUTS["DEV"]
)
```

## При timeout

Если время истекает:
1. Агент останавливается
2. В backlog записывается `[TIMEOUT]` лог
3. PM может перезапустить агента с увеличенным timeout
