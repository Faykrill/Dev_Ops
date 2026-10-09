# ==========================================
# Стадия 1: Установка браузера (параллельная)
# ==========================================
FROM python:3.13.7-bookworm AS browser

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# Устанавливаем сам playwright, чтобы скачать браузер
RUN pip install --no-cache-dir playwright==1.48.0
RUN playwright install chromium

# ==========================================
# Стадия 2: Установка Python-зависимостей (параллельная)
# ==========================================
FROM python:3.13.7-bookworm AS deps

WORKDIR /app

# Создаем виртуальное окружение
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Копируем файл зависимостей и устанавливаем их
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ==========================================
# Стадия 3: Финальный образ (собирает всё вместе)
# ==========================================
FROM python:3.13.7-bookworm AS runner

WORKDIR /app

# Копируем готовое виртуальное окружение из deps
COPY --from=deps /opt/venv /opt/venv

# Копируем скачанный браузер из browser
COPY --from=browser /ms-playwright /ms-playwright

# Настраиваем переменные окружения
ENV PATH="/opt/venv/bin:$PATH"
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# Устанавливаем системные библиотеки для запуска браузера
RUN playwright install-deps chromium

# Копируем исходный код
COPY src/ ./src/

# Команда запуска
CMD ["python", "src/main.py"]