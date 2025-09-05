# Task 003: Создание Node.js сервера с файловым мониторингом

## Описание
Создать Node.js сервер, который отслеживает изменения файлов и предоставляет API для web-интерфейса.

## Выполнимые действия
1. Создать `server.js` с Express сервером на порту 8820
2. Реализовать файловый мониторинг (fs.watch) для папок questions/ и answers/
3. Создать API endpoints:
   - `GET /api/questions` - список всех вопросов
   - `GET /api/questions/:id` - конкретный вопрос
   - `POST /api/answers` - сохранение ответа
   - `GET /api/status` - текущее состояние
4. Интегрировать с core_script.sh через child_process

## Тест
```bash
# Запустить сервер
node server.js
# Проверить API
curl http://localhost:8820/api/status
curl http://localhost:8820/api/questions
```

## Команда запуска
```bash
node server.js
```
