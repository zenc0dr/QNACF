const fs = require('fs');
const path = require('path');

class Logger {
    constructor() {
        this.logDir = 'logs';
        this.ensureLogDir();
    }

    ensureLogDir() {
        if (!fs.existsSync(this.logDir)) {
            fs.mkdirSync(this.logDir, { recursive: true });
        }
    }

    getLogFileName(level) {
        const date = new Date().toISOString().split('T')[0];
        return path.join(this.logDir, `${level}_${date}.log`);
    }

    formatMessage(level, message, data = null) {
        const timestamp = new Date().toISOString();
        const dataStr = data ? ` | Data: ${JSON.stringify(data)}` : '';
        return `[${timestamp}] [${level.toUpperCase()}] ${message}${dataStr}\n`;
    }

    writeLog(level, message, data = null) {
        const logFile = this.getLogFileName(level);
        const formattedMessage = this.formatMessage(level, message, data);
        
        try {
            fs.appendFileSync(logFile, formattedMessage);
        } catch (error) {
            console.error('Ошибка записи в лог:', error);
        }
    }

    info(message, data = null) {
        console.log(`[INFO] ${message}`);
        this.writeLog('info', message, data);
    }

    warn(message, data = null) {
        console.warn(`[WARN] ${message}`);
        this.writeLog('warn', message, data);
    }

    error(message, error = null, data = null) {
        const errorData = error ? {
            message: error.message,
            stack: error.stack,
            ...data
        } : data;
        
        console.error(`[ERROR] ${message}`, error);
        this.writeLog('error', message, errorData);
    }

    debug(message, data = null) {
        if (process.env.NODE_ENV === 'development') {
            console.debug(`[DEBUG] ${message}`);
            this.writeLog('debug', message, data);
        }
    }

    // Специальные методы для QNACF
    logQuestionCreated(questionId, questionText) {
        this.info(`Вопрос создан: ${questionId}`, { questionId, questionText });
    }

    logAnswerSubmitted(questionId, selectedOption, comment) {
        this.info(`Ответ отправлен: ${questionId}`, { questionId, selectedOption, comment });
    }

    logAnswerCancelled(questionId) {
        this.info(`Ответ отменён: ${questionId}`, { questionId });
    }

    logApiCall(method, endpoint, status, duration) {
        this.info(`API ${method} ${endpoint}`, { 
            method, 
            endpoint, 
            status, 
            duration: `${duration}ms` 
        });
    }

    logCoreScriptCall(command, args, success, output, error) {
        const level = success ? 'info' : 'error';
        this[level](`Core script: ${command}`, { 
            command, 
            args, 
            success, 
            output: output?.substring(0, 200), // Ограничиваем длину
            error 
        });
    }
}

module.exports = new Logger();

