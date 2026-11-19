#!/usr/bin/env bash
# Удаление VM и артефактов. Идемпотентно: повторный запуск без ошибки.
set -euo pipefail

VM_NAME="${VM_NAME:-quotes-lab}"
MULTIPASS="${MULTIPASS:-multipass.exe}"

if "$MULTIPASS" info "$VM_NAME" >/dev/null 2>&1; then
  "$MULTIPASS" delete --purge "$VM_NAME"
fi
rm -rf .lab infra/ansible/inventories/lab
echo "destroyed: VM и .lab/ удалены"