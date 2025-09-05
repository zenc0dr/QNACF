FROM node:18-alpine

WORKDIR /app

# Установить зависимости
COPY package*.json ./
RUN npm install

# Копировать исходный код
COPY . .

# Установить права на выполнение скрипта
RUN chmod +x core_script.sh

# Установить jq для работы с JSON
RUN apk add --no-cache jq

# Создать папки для данных
RUN mkdir -p questions answers backups

EXPOSE 8820

CMD ["npm", "start"]
