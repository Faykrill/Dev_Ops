IMAGE_NAME = quotes-scraper

.PHONY: build run clean ci

build:
	docker build -t $(IMAGE_NAME) .

run: build
	docker run --rm -v "$(CURDIR)/out:/app/out" $(IMAGE_NAME)

clean:
	-docker rmi $(IMAGE_NAME)
	-if exist out rmdir /s /q out

ci: build
	docker run --rm -v "$(CURDIR)/out:/app/out" $(IMAGE_NAME)
	@if not exist out\result.json (echo Ошибка: out/result.json отсутствует && exit 1)
	@python -c "import json; json.load(open('out/result.json'))" || (echo Ошибка: out/result.json не является валидным JSON && exit 1)
	@echo CI проверки пройдены успешно!