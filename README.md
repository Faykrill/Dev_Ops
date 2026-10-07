# Quotes Scraper

Скрапер на Python + Playwright, который извлекает цитаты с динамически подгружаемой страницы `https://quotes.toscrape.com/scroll` и сохраняет их в `out/result.json`.

Проект упакован в multistage Docker-образ на базе `node:22-bookworm` с использованием `Makefile` как единой точки входа.

## Локальная разработка

1. Убедиться, что у установлен [Docker Desktop](https://www.docker.com/products/docker-desktop) и он запущен.
2. Для работы с `Makefile` на Windows рекомендуется использовать Git Bash, WSL2 или установить утилиту `make` (например, через `choco install make`).
3. Установить зависимости локально (опционально, для IDE):
   ```bash
   pip install -r requirements.txt
   playwright install chromium

## Сборка
Все операции выполняются через Makefile. Ручные docker команды не требуются.
+ make build — собрать Docker-образ (использует кэш, не скачивает браузер заново при изменении кода).
+ make run — собрать образ и запустить скрапер. Результат появится в папке out/result.json.
+ make clean — удалить Docker-образ и папку out/.
+ make ci — запустить сборку и автоматическую проверку валидности выходного JSON (используется в GitHub Actions).