const express = require('express');
const cors = require('cors');
const fs = require('fs-extra');
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');
const logger = require('./logger');

const execAsync = promisify(exec);

const app = express();
const PORT = 8820;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Пути к файлам
const QUESTIONS_DIR = 'questions';
const ANSWERS_DIR = 'answers';
const STATE_FILE = 'state.json';
const CORE_SCRIPT = './core_script.sh';

// Функция для выполнения core_script команд
async function runCoreScript(command, ...args) {
    const startTime = Date.now();
    try {
        const { stdout, stderr } = await execAsync(`${CORE_SCRIPT} ${command} ${args.join(' ')}`);
        const duration = Date.now() - startTime;
        
        logger.logCoreScriptCall(command, args, true, stdout, null);
        
        return { success: true, output: stdout, error: stderr };
    } catch (error) {
        const duration = Date.now() - startTime;
        logger.logCoreScriptCall(command, args, false, error.stdout, error.message);
        
        return { success: false, output: '', error: error.message };
    }
}

// Функция для чтения JSON файла
async function readJsonFile(filePath) {
    try {
        const data = await fs.readFile(filePath, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        return null;
    }
}

// Функция для записи JSON файла
async function writeJsonFile(filePath, data) {
    try {
        await fs.writeFile(filePath, JSON.stringify(data, null, 2));
        return true;
    } catch (error) {
        console.error('Ошибка записи файла:', error);
        return false;
    }
}

// API Routes

// Получить статус системы
app.get('/api/status', async (req, res) => {
    const startTime = Date.now();
    try {
        const state = await readJsonFile(STATE_FILE);
        const questions = await fs.readdir(QUESTIONS_DIR).catch(() => []);
        const answers = await fs.readdir(ANSWERS_DIR).catch(() => []);
        
        const duration = Date.now() - startTime;
        logger.logApiCall('GET', '/api/status', 200, duration);
        
        res.json({
            status: 'ok',
            state: state || {},
            stats: {
                total_questions: questions.length,
                total_answers: answers.length,
                questions_dir: QUESTIONS_DIR,
                answers_dir: ANSWERS_DIR
            }
        });
    } catch (error) {
        const duration = Date.now() - startTime;
        logger.error('Ошибка получения статуса', error);
        logger.logApiCall('GET', '/api/status', 500, duration);
        res.status(500).json({ error: error.message });
    }
});

// Получить контекст системы
app.get('/api/context', async (req, res) => {
    try {
        const context = await readJsonFile('context_state.json');
        if (context) {
            res.json(context);
        } else {
            res.json({
                estimated_questions_remaining: 99,
                context_integrity_percent: 20,
                current_focus: "Инициализация",
                key_insights: [],
                risks: [],
                last_updated: new Date().toISOString(),
                session_id: "session_001"
            });
        }
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Получить все вопросы
app.get('/api/questions', async (req, res) => {
    try {
        const questions = [];
        const files = await fs.readdir(QUESTIONS_DIR).catch(() => []);
        
        for (const file of files) {
            if (file.endsWith('_question.json')) {
                const question = await readJsonFile(path.join(QUESTIONS_DIR, file));
                if (question) {
                    questions.push(question);
                }
            }
        }
        
        // Сортировать по ID
        questions.sort((a, b) => a.id.localeCompare(b.id));
        
        res.json(questions);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Получить конкретный вопрос
app.get('/api/questions/:id', async (req, res) => {
    try {
        const questionId = req.params.id;
        const questionFile = path.join(QUESTIONS_DIR, `${questionId}_question.json`);
        const question = await readJsonFile(questionFile);
        
        if (!question) {
            return res.status(404).json({ error: 'Вопрос не найден' });
        }
        
        res.json(question);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Создать новый вопрос
app.post('/api/questions', async (req, res) => {
    try {
        const { question } = req.body;
        
        if (!question) {
            return res.status(400).json({ error: 'Текст вопроса обязателен' });
        }
        
        const result = await runCoreScript('create_question', `"${question}"`);
        
        if (result.success) {
            const questionId = result.output.trim().split('\n').pop();
            res.json({ success: true, question_id: questionId });
        } else {
            res.status(500).json({ error: result.error });
        }
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Добавить варианты к вопросу
app.post('/api/questions/:id/options', async (req, res) => {
    try {
        const questionId = req.params.id;
        const { options } = req.body;
        
        if (!options || !Array.isArray(options)) {
            return res.status(400).json({ error: 'Варианты ответов обязательны' });
        }
        
        const questionFile = path.join(QUESTIONS_DIR, `${questionId}_question.json`);
        const question = await readJsonFile(questionFile);
        
        if (!question) {
            return res.status(404).json({ error: 'Вопрос не найден' });
        }
        
        question.options = options;
        question.timestamp = new Date().toISOString();
        
        const success = await writeJsonFile(questionFile, question);
        
        if (success) {
            res.json({ success: true, question });
        } else {
            res.status(500).json({ error: 'Ошибка сохранения вопроса' });
        }
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Сохранить ответ
app.post('/api/answers', async (req, res) => {
    const startTime = Date.now();
    try {
        const { question_id, selected_option, custom_answer, custom_comment, answer_type } = req.body;
        
        if (!question_id) {
            return res.status(400).json({ error: 'ID вопроса обязателен' });
        }
        
        if (!selected_option && !custom_answer) {
            return res.status(400).json({ error: 'Необходимо выбрать вариант или ввести собственный ответ' });
        }
        
        const result = await runCoreScript('update_answer', question_id, selected_option || '', `"${custom_comment || ''}"`, `"${custom_answer || ''}"`, answer_type || 'option');
        
        if (result.success) {
            logger.logAnswerSubmitted(question_id, selected_option || 'custom', custom_comment);
            logger.logApiCall('POST', '/api/answers', 200, Date.now() - startTime);
            res.json({ success: true });
        } else {
            logger.error('Ошибка сохранения ответа', null, { question_id, selected_option, custom_answer, error: result.error });
            logger.logApiCall('POST', '/api/answers', 500, Date.now() - startTime);
            res.status(500).json({ error: result.error });
        }
    } catch (error) {
        logger.error('Ошибка сохранения ответа', error);
        logger.logApiCall('POST', '/api/answers', 500, Date.now() - startTime);
        res.status(500).json({ error: error.message });
    }
});

// Отменить последний ответ
app.post('/api/answers/cancel', async (req, res) => {
    const startTime = Date.now();
    try {
        const result = await runCoreScript('remove_last_answer');
        
        if (result.success) {
            // Извлекаем ID вопроса из вывода (последняя строка)
            const lines = result.output.trim().split('\n');
            const questionId = lines[lines.length - 1];
            
            logger.logAnswerCancelled(questionId);
            logger.logApiCall('POST', '/api/answers/cancel', 200, Date.now() - startTime);
            
            res.json({ success: true, question_id: questionId });
        } else {
            logger.error('Ошибка отмены ответа', null, { error: result.error });
            logger.logApiCall('POST', '/api/answers/cancel', 500, Date.now() - startTime);
            res.status(500).json({ error: result.error });
        }
    } catch (error) {
        logger.error('Ошибка отмены ответа', error);
        logger.logApiCall('POST', '/api/answers/cancel', 500, Date.now() - startTime);
        res.status(500).json({ error: error.message });
    }
});

// Перегенерировать вопрос
app.post('/api/questions/regenerate', async (req, res) => {
    const startTime = Date.now();
    try {
        const { question_id, reason } = req.body;
        
        if (!question_id || !reason) {
            return res.status(400).json({ error: 'ID вопроса и причина перегенерации обязательны' });
        }
        
        const result = await runCoreScript('regenerate_question', question_id, `"${reason}"`);
        
        if (result.success) {
            logger.info(`Вопрос перегенерирован: ${question_id}`, { question_id, reason });
            logger.logApiCall('POST', '/api/questions/regenerate', 200, Date.now() - startTime);
            res.json({ success: true, question_id: question_id });
        } else {
            logger.error('Ошибка перегенерации вопроса', null, { question_id, reason, error: result.error });
            logger.logApiCall('POST', '/api/questions/regenerate', 500, Date.now() - startTime);
            res.status(500).json({ error: result.error });
        }
    } catch (error) {
        logger.error('Ошибка перегенерации вопроса', error);
        logger.logApiCall('POST', '/api/questions/regenerate', 500, Date.now() - startTime);
        res.status(500).json({ error: error.message });
    }
});

// Получить все ответы
app.get('/api/answers', async (req, res) => {
    try {
        const answers = [];
        const files = await fs.readdir(ANSWERS_DIR).catch(() => []);
        
        for (const file of files) {
            if (file.endsWith('_answer.json')) {
                const answer = await readJsonFile(path.join(ANSWERS_DIR, file));
                if (answer) {
                    answers.push(answer);
                }
            }
        }
        
        // Сортировать по ID
        answers.sort((a, b) => a.id.localeCompare(b.id));
        
        res.json(answers);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Создать бэкап
app.post('/api/backup', async (req, res) => {
    try {
        const result = await runCoreScript('backup');
        
        if (result.success) {
            res.json({ success: true, message: result.output });
        } else {
            res.status(500).json({ error: result.error });
        }
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Запуск сервера
app.listen(PORT, () => {
    console.log(`QNACF сервер запущен на порту ${PORT}`);
    console.log(`Откройте http://localhost:${PORT} в браузере`);
});