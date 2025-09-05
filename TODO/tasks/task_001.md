# Task 001: Создание структуры папок и базовых файлов

## Описание
Создать базовую файловую структуру для QNACF приложения.

## Выполнимые действия
1. Создать папки: `questions/`, `answers/`, `backups/`
2. Создать файл `state.json` с базовой структурой
3. Создать файл `focused_checklist.md` как результат
4. Создать `core_script.sh` с базовыми функциями

## Тест
```bash
# Проверить существование папок
ls -la questions/ answers/ backups/
# Проверить существование файлов
ls -la state.json focused_checklist.md core_script.sh
```

## Команда запуска
```bash
./core_script.sh init
```
