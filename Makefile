SHELL := /bin/bash

export VM_NAME := quotes-lab
export MULTIPASS := multipass.exe

.PHONY: setup destroy

setup:
	@bash scripts/setup.sh

destroy:
	@bash scripts/destroy.sh