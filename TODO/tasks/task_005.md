# Task 005: Настройка Docker контейнеров и docker-compose

## Описание
Создать Docker-контейнеры для изоляции и развёртывания QNACF приложения.

## Выполнимые действия
1. Создать `Dockerfile` для Node.js сервера
2. Создать `Dockerfile.core` для core_script контейнера
3. Создать `docker-compose.yml` с двумя сервисами:
   - `web` - Node.js сервер
   - `core` - core_script контейнер
4. Настроить общий volume для файловой системы
5. Настроить сеть между контейнерами

## Структура Docker
```yaml
services:
  web:
    build: .
    ports:
      - "8820:8820"
    volumes:
      - ./data:/app/data
  core:
    build: -f Dockerfile.core .
    volumes:
      - ./data:/app/data
```

## Тест
```bash
# Собрать и запустить
docker-compose up --build
# Проверить работу
curl http://localhost:8820/api/status
# Проверить логи
docker-compose logs
```

## Команда запуска
```bash
docker-compose up --build
```
