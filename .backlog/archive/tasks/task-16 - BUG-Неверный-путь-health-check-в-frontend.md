---
id: TASK-16
title: '[BUG] Неверный путь health check в frontend'
status: To Do
assignee: []
created_date: '2026-03-22 13:17'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Проблема

Frontend делает запрос к http://localhost:8082/api/health который возвращает 404.

## Root cause

В app.js неправильно сформирован путь:
- API_BASE_URL = 'http://localhost:8082/api/v1'
- \`${API_BASE_URL}/../health\` резолвится в /api/health
- Правильный путь: /health (без префикса /api)

## Как исправить

Заменить строку в app.js:
\`fetch(\`${API_BASE_URL}/../health\`)\` 
на 
\`fetch('http://localhost:8082/health')\`

## PASS

Console показывает CORS OK при загрузке страницы без ошибок
<!-- SECTION:DESCRIPTION:END -->
