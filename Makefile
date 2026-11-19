SHELL := /bin/bash

export VM_NAME := quotes-lab
export MULTIPASS := multipass.exe

ANSIBLE_DIR := infra/ansible
ANSIBLE := ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventories/lab/hosts.yml

.PHONY: setup destroy provision deploy run verify fault-test

setup:
	@bash scripts/setup.sh

destroy:
	@bash scripts/destroy.sh

provision: setup
	cd $(ANSIBLE_DIR) && $(ANSIBLE) playbooks/bootstrap.yml
	cd $(ANSIBLE_DIR) && $(ANSIBLE) playbooks/site.yml

deploy: setup
	cd $(ANSIBLE_DIR) && $(ANSIBLE) playbooks/site.yml

run:
	@test -n "$(URL)" || { echo "Использование: make run URL=<url> [CRASH=1]"; exit 1; }
	@mkdir -p .lab
	@JOB_ID="job-$$(date +%s)-$$RANDOM"; \
	echo "$$JOB_ID" > .lab/last_job_id; \
	echo "Отправляю задание job_id=$$JOB_ID"; \
	cd $(ANSIBLE_DIR) && $(ANSIBLE) playbooks/run.yml \
	  -e job_id="$$JOB_ID" -e job_url="$(URL)" -e crash="$(CRASH)"

verify:
	@test -f .lab/last_job_id || { echo "Сначала выполните make run URL=..."; exit 1; }
	@JOB_ID="$$(cat .lab/last_job_id)"; \
	cd $(ANSIBLE_DIR) && $(ANSIBLE) playbooks/verify.yml -e job_id="$$JOB_ID"

fault-test:
	@mkdir -p .lab
	@JOB_ID="ft-$$(date +%s)-$$RANDOM"; \
	echo "fault-test job_id=$$JOB_ID"; \
	cd $(ANSIBLE_DIR) && $(ANSIBLE) playbooks/fault_test.yml \
	  -e job_id="$$JOB_ID" -e job_url="https://quotes.toscrape.com/scroll"