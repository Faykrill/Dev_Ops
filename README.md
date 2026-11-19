# Quotes Scraper — Лабораторная работа 3

Скрапер цитат с `quotes.toscrape.com/scroll` на Ubuntu 24.04 (Multipass VM). Задания принимает через Redis Streams, результаты сохраняет на диск и отдаёт через Nginx.

## Требования к хосту

- **Windows 10/11** (любая редакция, включая Home)
- **Multipass 1.17+** с драйвером `hcs` (работает без Hyper-V/VirtualBox)
- **WSL2** с Ubuntu 24.04 (control node для Make/Ansible)
- **Сеть**: WSL2 и Multipass используют разные NAT-подсети; требуется либо `networkingMode=mirrored` в `.wslconfig`, либо forwarding между адаптерами `vEthernet (WSL)` и `vEthernet (Multipass vNetwork)`

## Архитектура

make run URL=...
↓
send_task.py → Redis Stream "jobs" (consumer group "scrapers")
↓
worker.py (Playwright + Chromium) → /srv/quotes-scraper/results/<job_id>.json
↓
Nginx (port 80) → HTTP GET /<job_id>.json


- **Redis** с AOF и volume, порт 6379 не публикуется
- **Nginx** монтирует каталог результатов read-only
- **Атомарная запись**: временный файл → `os.replace` → финальный JSON
- **Отказоустойчивость**: `XACK` только после записи; падение до XACK оставляет сообщение в pending, которое переобрабатывается при рестарте

## Структура

repo/
├─ src/worker.py # воркер: Redis Streams → Playwright → JSON → XACK
├─ src/send_task.py # продюсер: XADD задания в стрим
├─ Dockerfile # multi-stage образ с Playwright/Chromium
├─ deploy/ # compose.yaml, nginx.conf, redis.conf
├─ infra/
│ ├─ cloud-init.yaml # bootstrap: временный юзер, ключ, sudo, Python
│ └─ ansible/ # роли: bootstrap, ssh_hardening, docker_engine, scraper
├─ scripts/ # setup.sh, destroy.sh
└─ Makefile # единая точка входа


## Команды

| Цель | Описание |
|------|----------|
| `make setup` | Создать VM через Multipass, дождаться cloud-init, сгенерировать inventory |
| `make provision` | `setup` + Ansible: создать `admin`, ужесточить SSH, установить Docker, развернуть стек |
| `make deploy` | Только Ansible-развёртывание (без пересоздания VM) |
| `make run URL=<url>` | Отправить одно задание на скрапинг (генерирует `job_id`, сохраняет в `.lab/last_job_id`) |
| `make verify` | Проверить результат последнего задания: JSON, HTTP, отсутствие `.tmp`, пустой `XPENDING` |
| `make fault-test` | Тест отказоустойчивости: падение до XACK → pending → рестарт → дообработка |
| `make destroy` | Удалить VM и `.lab/` (идемпотентно) |
| `make ci` | Статические проверки: yamllint, ansible-lint, syntax-check, docker compose config |

## Быстрый старт

```bash
# 1. Установить зависимости в WSL2
pip install ansible ansible-lint yamllint
ansible-galaxy collection install -r infra/ansible/requirements.yml

# 2. Создать и развернуть окружение
make provision

# 3. Отправить задание и проверить результат
make run URL=https://quotes.toscrape.com/scroll
make verify

# 4. Тест отказоустойчивости
make fault-test

# 5. Удалить окружение
make destroy

## Идемпотентность

Повторный `make provision` или `make deploy` при неизменных исходниках даёт `changed=0` (второй прогон ничего не меняет): apt-кэш обновляется только при первом запуске и при смене файла репозитория Docker, образ пересобирается только при изменении исходников.

## Безопасность

- cloud-init создаёт только временного пользователя `bootstrap`
- Ansible создаёт постоянного `admin` с ключом и sudo, затем удаляет bootstrap
- SSH: `PermitRootLogin no`, `PasswordAuthentication no`, `KbdInteractiveAuthentication no`
- `admin` не входит в группу `docker` (все docker-команды через `become`)
- Docker Engine включён и запущен через systemd (`enabled` + `active`), проверка `docker info`
- Порт Redis (6379) не публикуется наружу

## CI

GitHub Actions запускает `make ci` при push в `main`/`feat/ansible-deploy` и при PR в `main`. Проверки статические (без запуска VM).

