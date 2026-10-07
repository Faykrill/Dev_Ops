# Стадия 1: Сборка и установка зависимостей
FROM node:22-bookworm AS builder

WORKDIR /app

# Устанавливаем Python и инструменты для venv
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv && rm -rf /var/lib/apt/lists/*

# Создаем виртуальное окружение
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Явно указываем Playwright, куда качать браузеры
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

COPY requirements.txt .

# Устанавливаем зависимости и браузер (это закэшируется!)
RUN pip install --no-cache-dir -r requirements.txt
RUN playwright install chromium
# В builder тоже ставим deps, чтобы кэш был полным, хотя для runner мы продублируем
RUN playwright install-deps chromium

# Стадия 2: Финальный образ (runner)
FROM node:22-bookworm AS runner

WORKDIR /app

# В финальном образе нужен только python3
RUN apt-get update && apt-get install -y python3 && rm -rf /var/lib/apt/lists/*

# Копируем браузеры из стадии builder
COPY --from=builder /ms-playwright /ms-playwright

# Копируем виртуальное окружение
COPY --from=builder /opt/venv /opt/venv

# Восстанавливаем переменные окружения для runner
ENV PATH="/opt/venv/bin:$PATH"
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# ВАЖНО: Устанавливаем системные зависимости ОС для запуска браузера в финальном образе
# Это быстро, так как сам браузер уже скопирован, качаются только мелкие системные библиотеки
RUN /opt/venv/bin/playwright install-deps chromium

# Копируем исходный код
COPY src/ ./src/

# Запускаем скрипт
CMD ["/opt/venv/bin/python", "src/main.py"]