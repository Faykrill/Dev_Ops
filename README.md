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

## Управление инфраструктурой и приложением

Все операции выполняются через Makefile. Ручные команды terraform/docker/aws не требуются.

- `make provision` — запускает контейнер Floci (если не запущен) и разворачивает инфраструктуру (S3 + SQS) через Terraform.
- `make deploy` — собирает Docker-образ и запускает скрапер в фоновом режиме с нужными переменными окружения.
- `make run` — отправляет тестовое задание в очередь SQS. Скрапер подхватит его, сохранит результат в S3 и удалит сообщение.
- `make destroy` — удаляет все созданные Terraform-ресурсы и останавливает контейнер Floci.
- `make ci` — проверяет форматирование, валидность и строит план Terraform (используется в GitHub Actions).
- `make clean` — удаляет Docker-образ и локальную папку `out/`.