#!/bin/bash

# QNACF Server Management Script
# Идемпотентный скрипт для управления сервером

set -e

# Конфигурация
SERVER_SCRIPT="server.js"
PID_FILE="server.pid"
LOG_FILE="server.log"
PORT=8820

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌${NC} $1"
}

# Функция проверки существования процесса
is_server_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            # PID файл существует, но процесс не запущен
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Функция получения PID процесса на порту
get_port_pid() {
    lsof -ti:$PORT 2>/dev/null || echo ""
}

# Функция запуска сервера
start_server() {
    log "Запуск сервера QNACF..."
    
    if is_server_running; then
        log_warning "Сервер уже запущен (PID: $(cat $PID_FILE))"
        return 0
    fi
    
    # Проверяем, не занят ли порт другим процессом
    local port_pid=$(get_port_pid)
    if [ -n "$port_pid" ]; then
        log_warning "Порт $PORT занят процессом $port_pid"
        log "Попытка завершить процесс..."
        kill -9 "$port_pid" 2>/dev/null || true
        sleep 2
    fi
    
    # Проверяем существование server.js
    if [ ! -f "$SERVER_SCRIPT" ]; then
        log_error "Файл $SERVER_SCRIPT не найден"
        exit 1
    fi
    
    # Проверяем существование node_modules
    if [ ! -d "node_modules" ]; then
        log "Установка зависимостей..."
        npm install
    fi
    
    # Запускаем сервер в фоне
    nohup node "$SERVER_SCRIPT" > "$LOG_FILE" 2>&1 &
    local server_pid=$!
    
    # Сохраняем PID
    echo "$server_pid" > "$PID_FILE"
    
    # Ждем запуска
    sleep 3
    
    # Проверяем, что сервер запустился
    if is_server_running; then
        log_success "Сервер запущен (PID: $server_pid, порт: $PORT)"
        log "Логи: $LOG_FILE"
        log "URL: http://localhost:$PORT"
    else
        log_error "Не удалось запустить сервер"
        log "Проверьте логи: $LOG_FILE"
        exit 1
    fi
}

# Функция остановки сервера
stop_server() {
    log "Остановка сервера QNACF..."
    
    if ! is_server_running; then
        log_warning "Сервер не запущен"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    log "Завершение процесса $pid..."
    
    # Пытаемся завершить gracefully
    kill -TERM "$pid" 2>/dev/null || true
    sleep 2
    
    # Если процесс все еще работает, принудительно завершаем
    if ps -p "$pid" > /dev/null 2>&1; then
        log_warning "Принудительное завершение процесса..."
        kill -9 "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    # Удаляем PID файл
    rm -f "$PID_FILE"
    
    # Проверяем, что порт освободился
    local port_pid=$(get_port_pid)
    if [ -n "$port_pid" ]; then
        log_warning "Порт $PORT все еще занят процессом $port_pid"
        kill -9 "$port_pid" 2>/dev/null || true
    fi
    
    log_success "Сервер остановлен"
}

# Функция перезапуска сервера
restart_server() {
    log "Перезапуск сервера QNACF..."
    stop_server
    sleep 2
    start_server
}

# Функция проверки статуса
status_server() {
    log "Проверка статуса сервера QNACF..."
    
    if is_server_running; then
        local pid=$(cat "$PID_FILE")
        local port_pid=$(get_port_pid)
        
        log_success "Сервер запущен"
        log "PID: $pid"
        log "Порт: $PORT"
        
        if [ "$pid" = "$port_pid" ]; then
            log_success "Порт $PORT корректно привязан к процессу"
        else
            log_warning "Порт $PORT занят другим процессом ($port_pid)"
        fi
        
        # Проверяем доступность API
        if command -v curl > /dev/null 2>&1; then
            if curl -s "http://localhost:$PORT/api/status" > /dev/null 2>&1; then
                log_success "API доступен"
            else
                log_warning "API недоступен"
            fi
        fi
        
        return 0
    else
        log_warning "Сервер не запущен"
        return 1
    fi
}

# Функция показа логов
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        log "Последние 50 строк логов:"
        echo "----------------------------------------"
        tail -n 50 "$LOG_FILE"
    else
        log_warning "Файл логов не найден: $LOG_FILE"
    fi
}

# Функция показа справки
show_help() {
    echo "QNACF Server Management Script"
    echo ""
    echo "Использование: $0 <команда>"
    echo ""
    echo "Команды:"
    echo "  start     - Запустить сервер"
    echo "  stop      - Остановить сервер"
    echo "  restart   - Перезапустить сервер"
    echo "  status    - Показать статус сервера"
    echo "  logs      - Показать логи сервера"
    echo "  help      - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 start"
    echo "  $0 status"
    echo "  $0 restart"
    echo "  $0 logs"
}

# Главная функция
main() {
    case "${1:-help}" in
        "start")
            start_server
            ;;
        "stop")
            stop_server
            ;;
        "restart")
            restart_server
            ;;
        "status")
            status_server
            ;;
        "logs")
            show_logs
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Неизвестная команда: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Запуск
main "$@"

