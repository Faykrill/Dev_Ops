#!/usr/bin/env bash
# Создание VM и подготовка inventory. Вызывается только через make setup.
set -euo pipefail

VM_NAME="${VM_NAME:-quotes-lab}"
MULTIPASS="${MULTIPASS:-multipass.exe}"
LAB_DIR=".lab"
KEY="$LAB_DIR/id_ed25519"

mkdir -p "$LAB_DIR" infra/ansible/inventories/lab

# 1. SSH-ключ (идемпотентно)
if [[ ! -f "$KEY" ]]; then
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "lab3" >/dev/null
fi
chmod 600 "$KEY"

# 2. Рендер cloud-init: подставляем публичный ключ
PUBKEY="$(cat "$KEY.pub")"
sed "s|__BOOTSTRAP_SSH_KEY__|$PUBKEY|" infra/cloud-init.yaml > "$LAB_DIR/cloud-init.yaml"

# 3. Запуск VM (если уже есть — просто стартуем)
if ! "$MULTIPASS" info "$VM_NAME" >/dev/null 2>&1; then
  CI_WIN="$(wslpath -w "$LAB_DIR/cloud-init.yaml")"
  "$MULTIPASS" launch 24.04 --name "$VM_NAME" \
    --cpus 2 --memory 4G --disk 20G --timeout 600 --cloud-init "$CI_WIN"
else
  "$MULTIPASS" start "$VM_NAME" >/dev/null 2>&1 || true
fi

# 4. Ждём завершения cloud-init
"$MULTIPASS" exec "$VM_NAME" -- cloud-init status --wait

# 5. IP виртуалки
IP="$("$MULTIPASS" info "$VM_NAME" --format json \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['info']['$VM_NAME']['ipv4'][0])")"
echo "$IP" > "$LAB_DIR/vm_ip"

# 6. Ждём SSH и снимаем host-key (TOFU; host key checking остаётся включён)
for _ in $(seq 1 60); do
  if ssh-keyscan -T 3 "$IP" 2>/dev/null | grep -q "ssh-"; then break; fi
  sleep 2
done
ssh-keyscan -H "$IP" > "$LAB_DIR/known_hosts" 2>/dev/null

# 7. Определяем пользователя: admin (если уже создан) иначе bootstrap
SSH_OPTS="-i $KEY -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$LAB_DIR/known_hosts -o ConnectTimeout=5"
USER="bootstrap"
if ssh $SSH_OPTS "admin@$IP" true 2>/dev/null; then USER="admin"; fi

# 8. Генерируем inventory (в git не коммитится)
ABS_KEY="$(realpath "$KEY")"
ABS_KH="$(realpath "$LAB_DIR/known_hosts")"
mkdir -p infra/ansible/inventories/lab/group_vars
cat > infra/ansible/inventories/lab/hosts.yml <<EOF
all:
  hosts:
    $VM_NAME:
      ansible_host: $IP
      ansible_user: $USER
      ansible_ssh_private_key_file: $ABS_KEY
      ansible_ssh_common_args: "-o UserKnownHostsFile=$ABS_KH -o StrictHostKeyChecking=yes"
EOF
cat > infra/ansible/inventories/lab/group_vars/all.yml <<EOF
lab_key_file: $ABS_KEY
lab_known_hosts: $ABS_KH
lab_pub_key: "$PUBKEY"
EOF