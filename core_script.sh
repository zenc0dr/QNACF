#!/bin/bash

# QNACF Core Script - Управление файлами вопросов и ответов

set -e

# Конфигурация
QUESTIONS_DIR="questions"
ANSWERS_DIR="answers"
BACKUPS_DIR="backups"
STATE_FILE="state.json"
CONTEXT_FILE="context_state.json"

# Функция для получения следующего номера
get_next_number() {
    local dir=$1
    local prefix=$2
    
    # Найти максимальный номер в папке
    local max_num=0
    if [ -d "$dir" ]; then
            for file in "$dir"/*_${prefix}.json; do
        if [ -f "$file" ]; then
            local num=$(basename "$file" | sed "s/\([0-9]*\)_${prefix}\.json/\1/")
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt "$max_num" ]; then
                max_num=$num
            fi
        fi
    done
    fi
    
    # Вернуть следующий номер с ведущими нулями
    printf "%03d" $((max_num + 1))
}

# Функция создания вопроса
create_question() {
    local question_text="$1"
    local question_id=$(get_next_number "$QUESTIONS_DIR" "question")
    
    # Создать JSON структуру вопроса
    cat > "$QUESTIONS_DIR/${question_id}_question.json" << EOF
{
  "id": "$question_id",
  "question": "$question_text",
  "options": [],
  "preferred": null,
  "reason": "",
  "tags": [],
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    # Обновить state.json
    update_state "current_question_id" "$question_id"
    update_state "total_questions" "$(($(get_state_value "total_questions") + 1))"
    
    echo "Создан вопрос: $question_id"
    echo "$question_id"
}

# Функция добавления вариантов к вопросу
add_options_to_question() {
    local question_id="$1"
    local question_file="$QUESTIONS_DIR/${question_id}_question.json"
    
    if [ ! -f "$question_file" ]; then
        echo "Ошибка: Вопрос $question_id не найден"
        return 1
    fi
    
    # Временно сохранить существующие данные
    local temp_file=$(mktemp)
    cp "$question_file" "$temp_file"
    
    # Добавить варианты ответов (пока пустые, будут заполнены через API)
    jq '.options = [
        {"text": "Вариант 1", "pros": ["плюс1"], "cons": ["минус1"]},
        {"text": "Вариант 2", "pros": ["плюс2"], "cons": ["минус2"]},
        {"text": "Вариант 3", "pros": ["плюс3"], "cons": ["минус3"]}
    ] | .preferred = 1 | .reason = "Обоснование предпочтительного варианта"' "$temp_file" > "$question_file"
    
    rm "$temp_file"
    echo "Добавлены варианты к вопросу: $question_id"
}

# Функция обновления ответа
update_answer() {
    local question_id="$1"
    local selected_option="$2"
    local custom_comment="$3"
    local custom_answer="$4"
    local answer_type="$5"
    
    # Определяем summary в зависимости от типа ответа
    local summary
    if [ "$answer_type" = "custom" ]; then
        summary="Пользовательский ответ: ${custom_answer:0:50}..."
    else
        summary="Выбран вариант $selected_option: $custom_comment"
    fi
    
    # Создать JSON структуру ответа
    local temp_file=$(mktemp)
    jq -n \
        --arg id "$question_id" \
        --arg question_id "$question_id" \
        --argjson selected_option "${selected_option:-null}" \
        --arg custom_answer "${custom_answer:-}" \
        --arg custom_comment "$custom_comment" \
        --arg answer_type "$answer_type" \
        --arg summary "$summary" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            id: $id,
            question_id: $question_id,
            selected_option: $selected_option,
            custom_answer: ($custom_answer | if . == "" then null else . end),
            custom_comment: $custom_comment,
            answer_type: $answer_type,
            summary: $summary,
            timestamp: $timestamp
        }' > "$temp_file" && mv "$temp_file" "$ANSWERS_DIR/${question_id}_answer.json"
    
    # Обновить state.json
    update_state "answered_questions" "$(($(get_state_value "answered_questions") + 1))"
    
    echo "Сохранён ответ для вопроса: $question_id"
}

# Функция обновления state.json
update_state() {
    local key="$1"
    local value="$2"
    
    if [ -f "$STATE_FILE" ]; then
        # Использовать jq для обновления JSON
        jq --arg key "$key" --arg value "$value" '.[$key] = $value | .last_updated = now | .last_updated = (.last_updated | strftime("%Y-%m-%dT%H:%M:%SZ"))' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    fi
}

# Функция получения значения из state.json
get_state_value() {
    local key="$1"
    if [ -f "$STATE_FILE" ]; then
        jq -r ".$key // 0" "$STATE_FILE"
    else
        echo "0"
    fi
}

# Функция создания бэкапа
backup_files() {
    local backup_id=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$BACKUPS_DIR/backup_$backup_id"
    
    mkdir -p "$backup_dir"
    cp -r "$QUESTIONS_DIR" "$backup_dir/"
    cp -r "$ANSWERS_DIR" "$backup_dir/"
    cp "$STATE_FILE" "$backup_dir/" 2>/dev/null || true
    
    echo "Создан бэкап: $backup_dir"
}

# Функция инициализации
init() {
    echo "Инициализация QNACF системы..."
    
    # Создать папки если не существуют
    mkdir -p "$QUESTIONS_DIR" "$ANSWERS_DIR" "$BACKUPS_DIR"
    
    # Создать state.json если не существует
    if [ ! -f "$STATE_FILE" ]; then
        cat > "$STATE_FILE" << EOF
{
  "current_question_id": null,
  "total_questions": 0,
  "answered_questions": 0,
  "status": "initialized",
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "session_id": "session_001"
}
EOF
    fi
    
    # Инициализировать контекст если не существует
    if [ ! -f "$CONTEXT_FILE" ]; then
        init_context
    fi
    
    echo "Система инициализирована"
}

# Функция получения статуса
get_status() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo '{"status": "not_initialized"}'
    fi
}

# Функция поиска вопросов
search_questions() {
    local pattern="$1"
    if [ -z "$pattern" ]; then
        echo "Использование: $0 search_questions \"паттерн\""
        return 1
    fi
    
    find "$QUESTIONS_DIR" -name "*_question.json" -exec grep -l "$pattern" {} \; 2>/dev/null | while read file; do
        echo "=== $(basename "$file") ==="
        cat "$file" | jq -r '.question'
        echo ""
    done
}

# Функция поиска ответов
search_answers() {
    local pattern="$1"
    if [ -z "$pattern" ]; then
        echo "Использование: $0 search_answers \"паттерн\""
        return 1
    fi
    
    find "$ANSWERS_DIR" -name "*_answer.json" -exec grep -l "$pattern" {} \; 2>/dev/null | while read file; do
        echo "=== $(basename "$file") ==="
        cat "$file" | jq -r '.summary'
        echo ""
    done
}

# Функция показа последних вопросов
list_recent_questions() {
    local count="${1:-5}"
    find "$QUESTIONS_DIR" -name "*_question.json" -printf '%T@ %p\n' | sort -nr | head -n "$count" | cut -d' ' -f2- | while read file; do
        echo "=== $(basename "$file") ==="
        cat "$file" | jq -r '"\(.id): \(.question)"'
        echo ""
    done
}

# Функция показа статистики
show_stats() {
    local questions_count=$(find "$QUESTIONS_DIR" -name "*_question.json" | wc -l)
    local answers_count=$(find "$ANSWERS_DIR" -name "*_answer.json" | wc -l)
    local backups_count=$(find "$BACKUPS_DIR" -name "backup_*" | wc -l)
    
    echo "📊 Статистика QNACF:"
    echo "   Вопросов: $questions_count"
    echo "   Ответов: $answers_count"
    echo "   Бэкапов: $backups_count"
    echo ""
    
    if [ "$questions_count" -gt 0 ]; then
        echo "📝 Последние вопросы:"
        list_recent_questions 3
    fi
}

# Функция очистки системы
clear_all() {
    echo "🧹 Очистка системы QNACF..."
    
    # Удалить все вопросы
    if [ -d "$QUESTIONS_DIR" ]; then
        find "$QUESTIONS_DIR" -name "*_question.json" -delete
        echo "   Удалены все вопросы"
    fi
    
    # Удалить все ответы
    if [ -d "$ANSWERS_DIR" ]; then
        find "$ANSWERS_DIR" -name "*_answer.json" -delete
        echo "   Удалены все ответы"
    fi
    
    # Сбросить состояние
    cat > "$STATE_FILE" << EOF
{
  "current_question_id": null,
  "total_questions": 0,
  "answered_questions": 0,
  "status": "initialized",
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "session_id": "session_$(date +%s)"
}
EOF
    echo "   Сброшено состояние системы"
    echo "✅ Система очищена"
}

# Функция очистки только вопросов
clear_questions() {
    echo "🧹 Очистка вопросов..."
    if [ -d "$QUESTIONS_DIR" ]; then
        find "$QUESTIONS_DIR" -name "*_question.json" -delete
        echo "✅ Вопросы удалены"
    else
        echo "❌ Папка вопросов не найдена"
    fi
}

# Функция очистки только ответов
clear_answers() {
    echo "🧹 Очистка ответов..."
    if [ -d "$ANSWERS_DIR" ]; then
        find "$ANSWERS_DIR" -name "*_answer.json" -delete
        echo "✅ Ответы удалены"
    else
        echo "❌ Папка ответов не найдена"
    fi
}

# Функция удаления последнего ответа
remove_last_answer() {
    if [ -d "$ANSWERS_DIR" ]; then
        local last_answer=$(ls -t "$ANSWERS_DIR"/*_answer.json 2>/dev/null | head -1)
        if [ -n "$last_answer" ]; then
            local question_id=$(basename "$last_answer" | sed 's/_answer\.json$//')
            rm -f "$last_answer"
            echo "✅ Удалён ответ для вопроса $question_id"
            echo "$question_id"
        else
            echo "❌ Ответы не найдены"
            return 1
        fi
    else
        echo "❌ Папка ответов не найдена"
        return 1
    fi
}

# Функция для перегенерации вопроса
regenerate_question() {
    local question_id="$1"
    local reason="$2"
    
    # Проверяем существование вопроса
    local question_file="$QUESTIONS_DIR/${question_id}_question.json"
    if [ ! -f "$question_file" ]; then
        echo "❌ Вопрос $question_id не найден"
        return 1
    fi
    
    # Создаем бэкап старого вопроса
    local backup_file="$QUESTIONS_DIR/${question_id}_question_backup_$(date +%Y%m%d_%H%M%S).json"
    cp "$question_file" "$backup_file"
    
    # Обновляем вопрос с пометкой о перегенерации
    local temp_file=$(mktemp)
    jq --arg reason "$reason" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
        .regenerate_reason = $reason |
        .regenerate_timestamp = $timestamp |
        .regenerated = true
    ' "$question_file" > "$temp_file" && mv "$temp_file" "$question_file"
    
    echo "✅ Вопрос $question_id помечен для перегенерации"
    echo "Причина: $reason"
    echo "$question_id"
}

# Функция создания следующего вопроса на основе ответов
create_next_question() {
    local question_text="$1"
    if [ -z "$question_text" ]; then
        echo "Использование: $0 create_next_question \"Текст следующего вопроса\""
        return 1
    fi
    
    local question_id=$(get_next_number "$QUESTIONS_DIR" "question")
    
    # Создать JSON структуру вопроса
    cat > "$QUESTIONS_DIR/${question_id}_question.json" << EOF
{
  "id": "$question_id",
  "question": "$question_text",
  "options": [],
  "preferred": null,
  "reason": "",
  "tags": [],
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    # Обновить state.json
    update_state "current_question_id" "$question_id"
    update_state "total_questions" "$(($(get_state_value "total_questions") + 1))"
    
    echo "Создан следующий вопрос: $question_id"
    echo "$question_id"
}

# Функция инициализации состояния контекста
init_context() {
    cat > "$CONTEXT_FILE" << EOF
{
  "estimated_questions_remaining": 99,
  "context_integrity_percent": 20,
  "current_focus": "Определение базовой архитектуры",
  "key_insights": [],
  "risks": [],
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "session_id": "session_$(date +%s)"
}
EOF
    echo "Инициализировано состояние контекста"
}

# Функция обновления состояния контекста
update_context() {
    local questions_remaining="$1"
    local integrity_percent="$2"
    local focus="$3"
    local insight="$4"
    local risk="$5"
    
    # Читаем текущее состояние
    local current_insights="[]"
    local current_risks="[]"
    if [ -f "$CONTEXT_FILE" ]; then
        current_insights=$(cat "$CONTEXT_FILE" | jq -c '.key_insights // []')
        current_risks=$(cat "$CONTEXT_FILE" | jq -c '.risks // []')
    fi
    
    # Добавляем новое понимание если есть
    if [ -n "$insight" ]; then
        current_insights=$(echo "$current_insights" | jq --arg insight "$insight" '. + [$insight]')
    fi
    
    # Добавляем новый риск если есть
    if [ -n "$risk" ]; then
        current_risks=$(echo "$current_risks" | jq --arg risk "$risk" '. + [$risk]')
    fi
    
    # Обновляем файл
    cat > "$CONTEXT_FILE" << EOF
{
  "estimated_questions_remaining": ${questions_remaining:-99},
  "context_integrity_percent": ${integrity_percent:-20},
  "current_focus": "${focus:-Анализ требований}",
  "key_insights": $current_insights,
  "risks": $current_risks,
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "session_id": "session_$(date +%s)"
}
EOF
    echo "Обновлено состояние контекста"
}

# Функция получения состояния контекста
get_context() {
    if [ -f "$CONTEXT_FILE" ]; then
        cat "$CONTEXT_FILE"
    else
        echo '{"error": "Context state not initialized"}'
    fi
}

# Функция автоматического обновления контекста на основе ответов
auto_update_context() {
    local answered_count=$(find "$ANSWERS_DIR" -name "*_answer.json" | wc -l)
    local total_questions=$(find "$QUESTIONS_DIR" -name "*_question.json" | wc -l)
    
    # Рассчитываем примерное количество оставшихся вопросов
    local estimated_remaining=$((99 - answered_count))
    if [ $estimated_remaining -lt 5 ]; then
        estimated_remaining=5
    fi
    
    # Рассчитываем целостность контекста
    local integrity_percent=$((20 + (answered_count * 8)))
    if [ $integrity_percent -gt 95 ]; then
        integrity_percent=95
    fi
    
    # Определяем текущий фокус на основе количества ответов
    local focus="Анализ требований"
    if [ $answered_count -gt 3 ]; then
        focus="Проектирование архитектуры"
    fi
    if [ $answered_count -gt 6 ]; then
        focus="Детализация компонентов"
    fi
    if [ $answered_count -gt 10 ]; then
        focus="Планирование реализации"
    fi
    
    update_context "$estimated_remaining" "$integrity_percent" "$focus"
}

# Главная функция
main() {
    case "$1" in
        "init")
            init
            ;;
        "create_question")
            if [ -z "$2" ]; then
                echo "Использование: $0 create_question \"Текст вопроса\""
                exit 1
            fi
            create_question "$2"
            ;;
        "add_options")
            if [ -z "$2" ]; then
                echo "Использование: $0 add_options <question_id>"
                exit 1
            fi
            add_options_to_question "$2"
            ;;
        "update_answer")
            if [ -z "$2" ]; then
                echo "Использование: $0 update_answer <question_id> <selected_option> [comment] [custom_answer] [answer_type]"
                exit 1
            fi
            update_answer "$2" "$3" "${4:-}" "${5:-}" "${6:-option}"
            ;;
        "backup")
            backup_files
            ;;
        "status")
            get_status
            ;;
        "search_questions")
            if [ -z "$2" ]; then
                echo "Использование: $0 search_questions \"паттерн\""
                exit 1
            fi
            search_questions "$2"
            ;;
        "search_answers")
            if [ -z "$2" ]; then
                echo "Использование: $0 search_answers \"паттерн\""
                exit 1
            fi
            search_answers "$2"
            ;;
        "list_recent")
            list_recent_questions "${2:-5}"
            ;;
        "stats")
            show_stats
            ;;
        "clear_all")
            clear_all
            ;;
        "clear_questions")
            clear_questions
            ;;
        "clear_answers")
            clear_answers
            ;;
        "remove_last_answer")
            remove_last_answer
            ;;
        "regenerate_question")
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo "Использование: $0 regenerate_question QUESTION_ID \"Причина перегенерации\""
                exit 1
            fi
            regenerate_question "$2" "$3"
            ;;
        "create_next_question")
            if [ -z "$2" ]; then
                echo "Использование: $0 create_next_question \"Текст следующего вопроса\""
                exit 1
            fi
            create_next_question "$2"
            ;;
        "init_context")
            init_context
            ;;
        "update_context")
            update_context "$2" "$3" "$4" "$5" "$6"
            ;;
        "get_context")
            get_context
            ;;
        "auto_update_context")
            auto_update_context
            ;;
        *)
            echo "QNACF Core Script"
            echo "Использование: $0 <command> [args...]"
            echo ""
            echo "Команды записи:"
            echo "  init                    - Инициализация системы"
            echo "  create_question <text>  - Создать новый вопрос"
            echo "  create_next_question <text> - Создать следующий вопрос (после ответа)"
            echo "  add_options <id>        - Добавить варианты к вопросу"
            echo "  update_answer <id> <option> [comment] - Обновить ответ"
            echo "  backup                  - Создать бэкап"
            echo "  clear_all               - Очистить всю систему"
            echo "  clear_questions         - Очистить только вопросы"
            echo "  clear_answers           - Очистить только ответы"
            echo "  remove_last_answer      - Удалить последний ответ"
            echo ""
            echo "Команды контекста:"
            echo "  init_context            - Инициализировать состояние контекста"
            echo "  update_context <remaining> <integrity> <focus> [insight] [risk] - Обновить контекст"
            echo "  auto_update_context     - Автоматически обновить контекст"
            echo "  get_context             - Получить состояние контекста"
            echo ""
            echo "Команды чтения:"
            echo "  status                  - Получить статус"
            echo "  search_questions <pattern> - Поиск в вопросах"
            echo "  search_answers <pattern>   - Поиск в ответах"
            echo "  list_recent [count]     - Последние вопросы"
            echo "  stats                   - Статистика системы"
            ;;
    esac
}

# Запуск
main "$@"
