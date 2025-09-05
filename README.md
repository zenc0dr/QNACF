# QNACF - Context Focusing

**QNACF** (Question-Answer Context Focusing) - это система для фокусировки контекста через структурированный диалог между человеком и AI-ассистентом. Система превращает размытые задачи в четкие, выполнимые чек-листы.

## 🎯 Назначение

QNACF решает проблему неопределенности в технических заданиях через:
- **Структурированный диалог** - AI задает вопросы с вариантами ответов
- **Анализ плюсов и минусов** - каждый вариант имеет обоснование
- **Накопление контекста** - система отслеживает прогресс и целостность ТЗ
- **Генерация чек-листов** - финальный результат в виде готовых к выполнению задач

## 🚀 Быстрый старт

### 1. Установка зависимостей
```bash
npm install
```

### 2. Инициализация системы
```bash
./core_script.sh init
```

### 3. Запуск сервера
```bash
./manage_server.sh start
```

### 4. Открыть в браузере
```
http://localhost:8820
```

## 📁 Структура проекта

```
QNACF/
├── core_script.sh          # Основной скрипт управления данными
├── manage_server.sh        # Скрипт управления сервером
├── server.js               # Node.js сервер
├── logger.js               # Система логирования
├── public/
│   └── index.html          # Веб-интерфейс
├── questions/              # JSON файлы вопросов
├── answers/                # JSON файлы ответов
├── backups/                # Бэкапы системы
├── logs/                   # Логи приложения
├── context_state.json      # Состояние контекста
└── state.json              # Состояние системы
```

## 🛠 Управление сервером

### Скрипт управления (идемпотентный)
```bash
# Запуск сервера
./manage_server.sh start

# Остановка сервера
./manage_server.sh stop

# Перезапуск сервера
./manage_server.sh restart

# Проверка статуса
./manage_server.sh status

# Просмотр логов
./manage_server.sh logs

# Справка
./manage_server.sh help
```

### Ручное управление
```bash
# Запуск в фоне
node server.js &

# Остановка
pkill -f "node server.js"
```

## 🔧 Core Script - Управление данными

### Основные команды

#### Инициализация
```bash
./core_script.sh init
```
Создает папки и базовые файлы системы.

#### Создание вопросов
```bash
./core_script.sh create_question "Текст вопроса"
./core_script.sh add_options QUESTION_ID
```

#### Управление ответами
```bash
./core_script.sh update_answer QUESTION_ID OPTION_NUMBER "Комментарий"
./core_script.sh remove_last_answer
```

#### Управление контекстом
```bash
./core_script.sh init_context
./core_script.sh auto_update_context
./core_script.sh update_context 85 65 "Проектирование" "Инсайт" "Риск"
```

#### Очистка данных
```bash
./core_script.sh clear_all
./core_script.sh clear_questions
./core_script.sh clear_answers
```

#### Бэкапы
```bash
./core_script.sh backup
```

#### Поиск и статистика
```bash
./core_script.sh search_questions "паттерн"
./core_script.sh search_answers "паттерн"
./core_script.sh stats
./core_script.sh status
```

## 🌐 API Endpoints

### Статус системы
```http
GET /api/status
```

### Контекст
```http
GET /api/context
```

### Вопросы
```http
GET /api/questions
POST /api/questions
POST /api/questions/:id/options
```

### Ответы
```http
GET /api/answers
POST /api/answers
POST /api/answers/cancel
```

## 📊 Мониторинг и логирование

### Система логирования
- **Логи API** - все запросы и ответы
- **Логи Core Script** - выполнение команд
- **Логи ошибок** - детальная информация об ошибках
- **Логи действий** - создание вопросов, ответов, отмены

### Файлы логов
```
logs/
├── info_2024-09-05.log     # Информационные сообщения
├── warn_2024-09-05.log     # Предупреждения
├── error_2024-09-05.log    # Ошибки
└── debug_2024-09-05.log    # Отладочная информация
```

### Мониторинг состояния
- **Состояние ТЗ** - отображается в веб-интерфейсе
- **Прогресс** - количество оставшихся вопросов
- **Целостность контекста** - процент готовности ТЗ
- **Текущий фокус** - этап работы

## 🎨 Веб-интерфейс

### Основные функции
- **Отображение вопросов** с вариантами ответов
- **Анализ плюсов и минусов** каждого варианта
- **Комментарии** к ответам
- **Отмена ответов** с подтверждением
- **Мониторинг состояния** ТЗ в реальном времени
- **История вопросов** в боковой панели

### Состояния интерфейса
- **Загрузка** - начальная загрузка данных
- **Вопрос** - отображение текущего вопроса
- **Обработка** - ожидание следующего вопроса
- **Завершено** - все вопросы отвечены

## 🔄 Процесс работы

1. **Инициализация** - создание первого вопроса
2. **Диалог** - AI задает вопросы с вариантами
3. **Анализ** - пользователь выбирает вариант
4. **Контекст** - система обновляет состояние
5. **Продолжение** - AI создает следующий вопрос
6. **Завершение** - генерация чек-листов

## 🐳 Docker поддержка

### Запуск в Docker
```bash
docker-compose up -d
```

### Структура Docker
- **web** - Node.js сервер
- **core** - Core Script контейнер
- **shared volume** - общие данные

## 📝 Форматы данных

### Вопрос (questions/XXX_question.json)
```json
{
  "id": "001",
  "question": "Текст вопроса",
  "options": [
    {
      "text": "Вариант 1",
      "pros": ["плюс1", "плюс2"],
      "cons": ["минус1", "минус2"]
    }
  ],
  "preferred": 1,
  "reason": "Обоснование",
  "tags": ["tag1"],
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### Ответ (answers/XXX_answer.json)
```json
{
  "id": "001",
  "question_id": "001",
  "selected_option": 1,
  "custom_comment": "Комментарий",
  "summary": "Резюме выбора",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### Контекст (context_state.json)
```json
{
  "estimated_questions_remaining": 85,
  "context_integrity_percent": 65,
  "current_focus": "Проектирование архитектуры",
  "key_insights": ["Инсайт 1", "Инсайт 2"],
  "risks": ["Риск 1", "Риск 2"],
  "last_updated": "2024-01-01T00:00:00Z",
  "session_id": "session_001"
}
```

## 🚨 Устранение неполадок

### Сервер не запускается
```bash
# Проверить порт
lsof -i :8820

# Остановить процессы
pkill -f "node server.js"

# Перезапустить
./manage_server.sh restart
```

### Ошибки Core Script
```bash
# Проверить права
chmod +x core_script.sh

# Проверить зависимости
which jq
which find
which grep
```

### Проблемы с данными
```bash
# Создать бэкап
./core_script.sh backup

# Очистить данные
./core_script.sh clear_all

# Переинициализировать
./core_script.sh init
```

## 📚 Дополнительные ресурсы

- **Методология QNACF** - `qnacf_method.md`
- **Правила Cursor** - `.cursor/rules/`
- **Примеры использования** - `examples/`

## 🤝 Участие в разработке

1. Форкните репозиторий
2. Создайте ветку для функции
3. Внесите изменения
4. Создайте Pull Request

## 📄 Лицензия

MIT License - см. файл LICENSE

---

**QNACF** - превращаем хаос в структуру через диалог! 🚀