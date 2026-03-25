#!/bin/bash
# .claude/test-setup.sh — Быстрая проверка системы
# Запуск: bash .claude/test-setup.sh

echo "=== Claude Setup — Smoke Test ==="
echo ""

ERRORS=0
WARNINGS=0

# 1. Проверить структуру .claude/
echo "--- Агенты ---"
REQUIRED_AGENTS="analyst.md developer.md reviewer.md qa.md scrum-master.md git-sync.md qdev.md setup.md"
for agent in $REQUIRED_AGENTS; do
  if [ -f ".claude/agents/$agent" ] && [ -s ".claude/agents/$agent" ]; then
    echo "  ✓ $agent ($(wc -l < .claude/agents/$agent) строк)"
  else
    echo "  ✗ $agent ОТСУТСТВУЕТ"
    ERRORS=$((ERRORS + 1))
  fi
done

# 2. Проверить фазовые модули
echo ""
echo "--- Фазовые модули ---"
REQUIRED_PHASES="phase-1-sa.md phase-2-scrum.md phase-3-dev.md phase-4-completion.md"
for phase in $REQUIRED_PHASES; do
  if [ -f ".claude/phases/$phase" ]; then
    echo "  ✓ $phase"
  else
    echo "  ✗ $phase ОТСУТСТВУЕТ"
    ERRORS=$((ERRORS + 1))
  fi
done

# 3. Проверить shared
echo ""
echo "--- Shared ---"
if [ -f ".claude/shared/statuses.md" ]; then
  echo "  ✓ statuses.md"
else
  echo "  ✗ statuses.md ОТСУТСТВУЕТ"
  ERRORS=$((ERRORS + 1))
fi

# 4. Проверить CLAUDE.md
echo ""
echo "--- CLAUDE.md ---"
if [ -f "CLAUDE.md" ]; then
  LINES=$(wc -l < CLAUDE.md)
  echo "  ✓ CLAUDE.md ($LINES строк)"
  if [ $LINES -gt 800 ]; then
    echo "  ⚠ Рекомендация: CLAUDE.md > 800 строк, рассмотреть сокращение"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo "  ✗ CLAUDE.md ОТСУТСТВУЕТ"
  ERRORS=$((ERRORS + 1))
fi

# 5. Проверить Spec-Kitty
echo ""
echo "--- Spec-Kitty ---"
SK_COUNT=$(ls .claude/commands/spec-kitty.*.md 2>/dev/null | wc -l)
if [ $SK_COUNT -ge 5 ]; then
  echo "  ✓ Spec-Kitty ($SK_COUNT команд)"
else
  echo "  ⚠ Spec-Kitty: $SK_COUNT команд (нужно ≥5, SA будет использовать fallback)"
  WARNINGS=$((WARNINGS + 1))
fi

# 6. Проверить шаблоны
echo ""
echo "--- Шаблоны ---"
EXPLORE_COUNT=$(ls .claude/templates/explore/*.md 2>/dev/null | wc -l)
echo "  Explore шаблоны: $EXPLORE_COUNT"
FALLBACK_COUNT=$(ls .claude/templates/fallback/*.md 2>/dev/null | wc -l)
echo "  Fallback шаблоны: $FALLBACK_COUNT"

# 7. Проверить Backlog
echo ""
echo "--- Backlog ---"
if [ -f ".backlog/config.yml" ]; then
  echo "  ✓ .backlog/config.yml"
  # Проверить статусы
  if grep -q "qdev-check" .backlog/config.yml; then
    echo "  ✓ Статус qdev-check присутствует"
  else
    echo "  ✗ Статус qdev-check отсутствует в config.yml"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "  ✗ .backlog/config.yml ОТСУТСТВУЕТ (запустите: backlog init)"
  ERRORS=$((ERRORS + 1))
fi

# 8. Проверить Continue.dev checks
echo ""
echo "--- Continue.dev ---"
CHECKS_COUNT=$(ls .continue/checks/*.md 2>/dev/null | wc -l)
echo "  Checks: $CHECKS_COUNT файлов"

# 9. Проверить Backlog MCP
echo ""
echo "--- Backlog MCP ---"
if command -v backlog &> /dev/null; then
  echo "  ✓ backlog CLI установлен ($(backlog --version 2>/dev/null || echo 'версия неизвестна'))"
else
  echo "  ✗ backlog CLI не установлен (npm install -g backlog.md)"
  ERRORS=$((ERRORS + 1))
fi

# Итог
echo ""
echo "=== ИТОГ ==="
echo "  Ошибки: $ERRORS"
echo "  Предупреждения: $WARNINGS"

if [ $ERRORS -eq 0 ]; then
  echo "  ✓ Система готова к работе"
  exit 0
else
  echo "  ✗ Требуются исправления"
  exit 1
fi
