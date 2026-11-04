IMAGE_NAME = quotes-scraper
COMPOSE_FILE = docker-compose.yaml
COMPOSE = docker compose -f $(COMPOSE_FILE)
TF_DIR = infra

.PHONY: build provision deploy run clean destroy ci

build:
	docker build -t $(IMAGE_NAME) .

provision:
	@echo Проверка и запуск Floci...
	$(COMPOSE) up -d floci
	@echo Ожидание инициализации Floci (10 сек)...
	@timeout /t 10 /nobreak >nul
	terraform -chdir=$(TF_DIR) init
	terraform -chdir=$(TF_DIR) apply -auto-approve

deploy: build
	@echo Остановка предыдущей версии скрапера, если есть...
	@docker rm -f scraper-app >nul 2>&1 || echo "Скрапер не был запущен."
	$(COMPOSE) up -d --no-deps scraper
	@echo Скрапер запущен в фоне и ожидает задания.

run:
	@echo Отправка задания в SQS...
	$(COMPOSE) run --rm --no-deps send-task
	@echo Задание отправлено. Скрапер должен его обработать.

clean:
	@echo Очистка...
	@docker rm -f scraper-app >nul 2>&1 || echo "Скрапер не запущен."
	@docker rmi $(IMAGE_NAME) >nul 2>&1 || echo "Образ не найден."
	@if exist out rmdir /s /q out

destroy:
	@echo Удаление инфраструктуры...
	terraform -chdir=$(TF_DIR) destroy -auto-approve
	$(COMPOSE) down -v

ci:
	@echo Запуск CI проверок Terraform...
	terraform -chdir=$(TF_DIR) fmt -check
	terraform -chdir=$(TF_DIR) init -backend=false
	terraform -chdir=$(TF_DIR) validate
	terraform -chdir=$(TF_DIR) plan
	@echo Проверка docker-compose.yaml...
	$(COMPOSE) config --quiet
	@echo CI проверки пройдены успешно!
