IMAGE_NAME = quotes-scraper
FLOCI_CONTAINER = floci-local
AWS_ENDPOINT = http://host.docker.internal:4566
S3_BUCKET = scraper-results-bucket
SQS_QUEUE_NAME = scraper-tasks-queue
QUEUE_URL = $(AWS_ENDPOINT)/000000000000/$(SQS_QUEUE_NAME)

.PHONY: build provision deploy run clean destroy ci

build:
	docker build -t $(IMAGE_NAME) .

provision:
	@echo Проверка и запуск Floci...
	@docker rm -f $(FLOCI_CONTAINER) >nul 2>&1 || echo "Контейнер не существовал, создаем новый..."
	@docker run -d --name $(FLOCI_CONTAINER) -p 4566:4566 floci/floci:2.2.0
	@echo Ожидание инициализации Floci (10 сек)...
	@timeout /t 10 /nobreak >nul
	terraform init
	terraform apply -auto-approve

deploy: build
	@echo Остановка предыдущей версии скрапера, если есть...
	@docker rm -f scraper-app >nul 2>&1 || echo "Скрапер не был запущен."
	docker run -d --rm --name scraper-app --add-host=host.docker.internal:host-gateway -e AWS_ENDPOINT_URL=$(AWS_ENDPOINT) -e S3_BUCKET_NAME=$(S3_BUCKET) -e SQS_QUEUE_URL=$(QUEUE_URL) $(IMAGE_NAME)
	@echo Скрапер запущен в фоне и ожидает задания.

run:
	@echo Отправка задания в SQS...
	docker run --rm --add-host=host.docker.internal:host-gateway -e AWS_ENDPOINT_URL=$(AWS_ENDPOINT) -e SQS_QUEUE_URL=$(QUEUE_URL) $(IMAGE_NAME) python src/send_task.py
	@echo Задание отправлено. Скрапер должен его обработать.

clean:
	@echo Очистка...
	@docker rm -f scraper-app >nul 2>&1 || echo "Скрапер не запущен."
	@docker rmi $(IMAGE_NAME) >nul 2>&1 || echo "Образ не найден."
	@if exist out rmdir /s /q out

destroy:
	@echo Удаление инфраструктуры...
	terraform destroy -auto-approve
	@docker rm -f $(FLOCI_CONTAINER) >nul 2>&1 || echo "Контейнер Floci не найден."

ci:
	@echo Запуск CI проверок Terraform...
	terraform fmt -check
	terraform init -backend=false
	terraform validate
	terraform plan
	@echo CI проверки Terraform пройдены успешно!