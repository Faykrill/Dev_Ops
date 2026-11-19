SHELL := /bin/bash

export VM_NAME := quotes-lab
export MULTIPASS := multipass.exe

ANSIBLE_DIR := infra/ansible

.PHONY: setup destroy provision

setup:
	@bash scripts/setup.sh

destroy:
	@bash scripts/destroy.sh

provision: setup
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/bootstrap.yml