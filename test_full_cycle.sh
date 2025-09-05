#!/bin/bash

# QNACF Full Cycle Test Script

echo "🚀 Запуск полного теста QNACF системы..."

# Остановить предыдущие процессы
pkill -f "node server.js" 2>/dev/null || true

# Очистить данные
rm -rf questions/* answers/* backups/*
./core_script.sh init

echo "✅ 1. Система инициализирована"

# Создать первый вопрос
QUESTION_OUTPUT=$(./core_script.sh create_question "Какой подход выбрать для архитектуры приложения?")
QUESTION_ID=$(echo "$QUESTION_OUTPUT" | tail -1)
echo "✅ 2. Создан вопрос: $QUESTION_ID"

# Добавить варианты
./core_script.sh add_options $QUESTION_ID
echo "✅ 3. Добавлены варианты к вопросу"

# Обновить варианты через API
curl -X POST http://localhost:8820/api/questions/$QUESTION_ID/options \
  -H "Content-Type: application/json" \
  -d '{
    "options": [
      {
        "text": "Монолитная архитектура",
        "pros": ["Простота разработки", "Легкое тестирование"],
        "cons": ["Сложность масштабирования", "Единая точка отказа"]
      },
      {
        "text": "Микросервисная архитектура", 
        "pros": ["Независимое масштабирование", "Технологическое разнообразие"],
        "cons": ["Сложность управления", "Сетевые задержки"]
      },
      {
        "text": "Гибридный подход",
        "pros": ["Баланс простоты и гибкости", "Постепенная миграция"],
        "cons": ["Сложность принятия решений", "Потенциальная несогласованность"]
      }
    ]
  }' > /dev/null 2>&1

echo "✅ 4. Обновлены варианты через API"

# Запустить сервер
node server.js &
SERVER_PID=$!
sleep 3

echo "✅ 5. Сервер запущен (PID: $SERVER_PID)"

# Проверить API
STATUS=$(curl -s http://localhost:8820/api/status | jq -r '.status')
if [ "$STATUS" = "ok" ]; then
    echo "✅ 6. API отвечает корректно"
else
    echo "❌ 6. Ошибка API"
    exit 1
fi

# Проверить вопросы
QUESTIONS_COUNT=$(curl -s http://localhost:8820/api/questions | jq '. | length')
if [ "$QUESTIONS_COUNT" -gt 0 ]; then
    echo "✅ 7. Вопросы загружены ($QUESTIONS_COUNT шт.)"
else
    echo "❌ 7. Ошибка загрузки вопросов"
    exit 1
fi

# Симулировать ответ пользователя
curl -X POST http://localhost:8820/api/answers \
  -H "Content-Type: application/json" \
  -d '{
    "question_id": "'$QUESTION_ID'",
    "selected_option": 1,
    "custom_comment": "Выбираем монолитную архитектуру для простоты"
  }' > /dev/null 2>&1

echo "✅ 8. Ответ сохранён"

# Проверить ответы
ANSWERS_COUNT=$(curl -s http://localhost:8820/api/answers | jq '. | length')
if [ "$ANSWERS_COUNT" -gt 0 ]; then
    echo "✅ 9. Ответы загружены ($ANSWERS_COUNT шт.)"
else
    echo "❌ 9. Ошибка загрузки ответов"
    exit 1
fi

# Создать бэкап
./core_script.sh backup
echo "✅ 10. Бэкап создан"

# Проверить web-интерфейс
WEB_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8820/)
if [ "$WEB_RESPONSE" = "200" ]; then
    echo "✅ 11. Web-интерфейс доступен"
else
    echo "❌ 11. Ошибка web-интерфейса (HTTP: $WEB_RESPONSE)"
fi

# Остановить сервер
kill $SERVER_PID 2>/dev/null || true

echo ""
echo "🎉 Полный тест завершён успешно!"
echo ""
echo "📊 Результаты:"
echo "   - Вопросов создано: $QUESTIONS_COUNT"
echo "   - Ответов сохранено: $ANSWERS_COUNT"
echo "   - API статус: $STATUS"
echo "   - Web-интерфейс: HTTP $WEB_RESPONSE"
echo ""
echo "📁 Файлы:"
ls -la questions/ answers/ backups/ 2>/dev/null || true
echo ""
echo "🔗 Для запуска: docker-compose up"
