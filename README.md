# Quotes Scraper

Асинхронный скрапер на Python + Playwright, который извлекает цитаты с динамически подгружаемой страницы `https://quotes.toscrape.com/scroll` и сохраняет результат в S3-объект `s3://scraper-results-bucket/result.json`.

Проект построен по модели **producer → queue → worker**: задание кладётся в SQS, воркер забирает его, скрапит страницу через headless Chromium и пишет JSON в S3. AWS-сервисы при этом локальные — их эмулирует контейнер **Floci** (`floci/floci:2.2.0`, порт `4566`), а инфраструктура описана в Terraform. Управление — через `Makefile` как единую точку входа.

## Как это работает

```
make run                          make deploy
(одноразовый контейнер)           (фоновый контейнер scraper-app)
       │                                  │
       ▼                                  ▼
send_task.py ──► SQS: scraper-tasks-queue ──► main.py (цикл receive_message, long polling 10 сек)
                                                  │
                                                  ├─ Playwright + Chromium → /scroll, скролл, .quote
                                                  ▼
                                          S3: scraper-results-bucket/result.json
                                                  │
                                                  └─ delete_message только после успешной записи

                S3 и SQS живут в сервисе floci из docker-compose.yaml (порт 4566)
                (ресурсы описаны в infra/main.tf, состояние — infra/terraform.tfstate)
```

Воркер бесконечный: после обработки задания он сразу ждёт следующее. При ошибке сообщение из очереди **не** удаляется и станет доступно повторно после истечения visibility timeout.

## Структура

| Путь | Назначение |
|---|---|
| `src/main.py` | воркер: SQS → Playwright-скрапинг → S3 → удаление сообщения |
| `src/send_task.py` | продюсер: отправляет `{"action": "scrape"}` в SQS |
| `infra/versions.tf` | требуемые версии: Terraform `>= 1.5.0`, провайдер `hashicorp/aws ~> 5.0` |
| `infra/provider.tf` | провайдер AWS, направленный на эндпоинты Floci (отключены `skip_*` проверки) |
| `infra/variables.tf` | имена бакета/очереди, эндпоинты, регион и фейковые креды — всё с дефолтами |
| `infra/main.tf` | ресурсы: бакет `scraper-results-bucket` + очередь `scraper-tasks-queue` |
| `infra/outputs.tf` | `tasks_queue_url`, `tasks_queue_url_from_host`, `results_bucket_name`, `results_bucket_arn` |
| `infra/.terraform.lock.hcl` | зафиксирован провайдер `hashicorp/aws` 5.100.0 |
| `docker-compose.yaml` | сервисы `floci`, `scraper`, `send-task` и volume `floci-data` |
| `Dockerfile` | multistage-образ `python:3.13.7-bookworm` (стадии `browser`, `deps`, `runner`) |
| `Makefile` | все команды сборки, деплоя и работы с инфраструктурой |
| `.github/workflows/ci.yml` | CI: проверки Terraform через `make ci` |
| `requirements.txt` | `playwright==1.48.0`, `boto3==1.35.0` |

## Требования

- **Docker Desktop** (запущен).
- **Terraform CLI** — конфигурация лежит в `infra/`, провайдер `hashicorp/aws ~> 5.0` берётся из `infra/.terraform.lock.hcl`.
- **Docker Compose v2** (`docker compose`, входит в Docker Desktop) — через него `Makefile` поднимает Floci, воркер и отправитель заданий.
- **make в cmd-оболочке Windows.** Цели `provision`, `deploy`, `clean` используют `>nul 2>&1`, `timeout /t 10` и `if exist ... rmdir /s /q` — это cmd-синтаксис, в Git Bash/WSL эти цели сломаются. `make ci` от оболочки не зависит.
- Локальный Python и `pip install -r requirements.txt` нужны **только для IDE/подсветки** — сам скрапер исполняется внутри Docker-образа, и Chromium для него ставится там же.

## Быстрый старт

```bash
make provision    # 1) docker compose up -d floci (:4566), 2) terraform -chdir=infra init + apply (S3 + SQS)
make deploy       # собирает образ quotes-scraper и запускает scraper-app в фоне
make run          # отправляет одно задание в SQS — воркер его подхватит
```

Логи воркера и проверка результата:

```bash
docker logs -f scraper-app
aws --endpoint-url=http://localhost:4566 s3 cp s3://scraper-results-bucket/result.json - ^
    --access-key-id test --secret-access-key test --region us-east-1
```

Уборка:

```bash
make destroy    # terraform destroy + остановить и удалить floci-local
make clean      # удалить контейнер scraper-app, образ quotes-scraper и папку out/
```

## Цели Makefile

| Цель | Что делает |
|---|---|
| `build` | `docker build -t quotes-scraper .` (вызывается автоматически из `deploy`) |
| `provision` | `docker compose up -d floci` (идемпотентно), ожидание 10 сек, `terraform -chdir=infra init` + `apply -auto-approve` |
| `deploy` | `build`, затем `docker compose up -d --no-deps scraper` (контейнер `scraper-app`, env из compose) |
| `run` | `docker compose run --rm --no-deps send-task` — одноразовый контейнер с `python src/send_task.py` |
| `destroy` | `terraform -chdir=infra destroy -auto-approve`, затем `docker compose down -v` (контейнеры + volume с данными Floci) |
| `ci` | `terraform -chdir=infra fmt -check`, `init -backend=false`, `validate`, `plan` и `docker compose config --quiet` |
| `clean` | удаление контейнера, образа и legacy-папки `out/` |

## Переменные окружения

| Переменная | Значение | Обязательна | Кто читает |
|---|---|---|---|
| `AWS_ENDPOINT_URL` | `http://host.docker.internal:4566` (подставляется и по default в коде) | нет | `main.py`, `send_task.py` |
| `SQS_QUEUE_URL` | `http://host.docker.internal:4566/000000000000/scraper-tasks-queue` | **да** | `main.py`, `send_task.py` |
| `S3_BUCKET_NAME` | `scraper-results-bucket` | **да** (`main.py` выходит с кодом 1) | `main.py` |

Значения по умолчанию живут в `docker-compose.yaml` (интерполяция `${VAR:-значение}`), поэтому `make deploy`/`make run` можно перезапустить с другими именами ресурсов, не правя compose: `set SQS_QUEUE_URL=... && make run`. Канонический URL очереди отдаёт `terraform -chdir=infra output tasks_queue_url`.

`host.docker.internal` (в compose — `extra_hosts: ["host.docker.internal:host-gateway"]`) вместо `localhost`, потому что изнутри контейнера `localhost` — это сам контейнер, а не Floci. Креды `test`/`test` и регион `us-east-1` заданы дефолтами в `infra/variables.tf` и захардкожены в коде Python — их достаточно только для локальной эмуляции, для реального AWS их нужно вынести в переменные/секреты.

## Docker-образ

Multistage на базе `python:3.13.7-bookworm`, чтобы тяжёлые слои не пересобирались при каждой правке кода:

1. `browser` — ставит `playwright` и скачивает Chromium в `/ms-playwright`.
2. `deps` — создаёт venv в `/opt/venv` и ставит `requirements.txt` (слой кэшируется по `COPY requirements.txt`).
3. `runner` — копирует `/opt/venv` и `/ms-playwright` из предыдущих стадий, доустанавливает системные библиотеки браузера (`playwright install-deps chromium`), добавляет `src/` и задаёт `CMD ["python", "src/main.py"]`.

## CI

`.github/workflows/ci.yml` срабатывает на `push` в ветки `main` и `Terraform`, `runs-on: ubuntu-latest`: `actions/checkout@v4` → `hashicorp/setup-terraform@v3` → `make ci`. Проверки статические (`fmt -check`, `init -backend=false`, `validate`, `plan`) плюс `docker compose config --quiet`, поэтому запущенный Floci в CI не нужен — `plan` не обращается к эндпоинтам из `infra/`. Остальные цели в CI не выполняются: они cmd-специфичны.

## Известные особенности

- **Гарантия at-least-once.** `visibility_timeout_seconds` и DLQ в `infra/main.tf` не заданы, то есть дефолтные 30 секунд (Terraform это прямо показывает в `plan`). Если скрапинг займёт дольше, сообщение вернётся в очередь и будет обработано повторно, перезаписав `result.json`.
- Готовность Floci в `provision` ожидается фиксированным `timeout /t 10`, а не health-check — при медленном старте Docker первый `terraform apply` может не успеть.
- Данные Floci лежат в volume `floci-data` (в образе это `/app/data`, куда он пишет по `FLOCI_STORAGE_PERSISTENT_PATH`), поэтому повторный `make provision` видит существующие bucket и queue и не меняет инфраструктуру. `make destroy` удаляет и volume — следующий `make provision` стартует с чистого состояния. Если на машине остался контейнер `floci-local`, поднятый прежней версией `provision` через `docker run`, удалите его один раз вручную (`docker rm -f floci-local`), иначе порт 4566 может быть занят.
- В конце `scrape_quotes()` стоит фиксированный `asyncio.sleep(1)` после прокрутки: если страница подгружает цитаты дольше, часть из них может не попасть в результат.
- Упоминания `out/result.json` в `.gitignore`, `.dockerignore` и в цели `clean` — наследие прошлой версии, когда скрапер писал файл на диск. Сейчас воркер пишет исключительно в S3, и папки `out/` в проекте нет.
- Состояние Terraform локальное: `infra/terraform.tfstate` (в `.gitignore`), то есть между машинами и между оболочками оно не разделяется.
