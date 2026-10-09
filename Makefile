IMAGE_NAME = quotes-scraper

.PHONY: build run clean ci

build:
	docker build -t $(IMAGE_NAME) .

run: build
	docker run --rm -v "$(CURDIR)/out:/app/out" $(IMAGE_NAME)

clean:
	-docker rmi $(IMAGE_NAME)
	-rm -rf out
	-if exist out rmdir /s /q out

ci: build
	docker run --rm -v "$(CURDIR)/out:/app/out" $(IMAGE_NAME)
	python -c "import os, json; f='out/result.json'; assert os.path.exists(f) and os.path.getsize(f) > 0, 'File missing or empty'; json.load(open(f))"
	@echo CI проверки пройдены успешно!