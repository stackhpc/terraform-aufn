#!/usr/bin/env bash
set -euo pipefail

# AU_FROM_SEED="false"
# OS_IMAGE="Rocky9"
# TAINT_REBUILD="false"

echo "Starting AUFN test action with:"
echo "AU_FROM_SEED: $AU_FROM_SEED"
echo "OS Image: $OS_IMAGE"

if [[ "$OS_IMAGE" == "Ubuntu" ]]; then
  export LAB_IMAGE_USER="ubuntu"
elif [[ "$OS_IMAGE" == "Rocky9" ]]; then
  export LAB_IMAGE_USER="rocky"
else
  echo "Unsupported OS image: $OS_IMAGE"
  exit 1
fi

function check_lab_vm_connections() {
  echo "Checking VM connections..."
  cat ssh_list.txt
  while IFS= read -r line; do
    ip=$(echo "$line" | awk '{print $3}')
    name=$(echo "$line" | awk '{print $2}')
    password=$(echo "$line" | awk '{print $5}')

    echo "Connecting to $name ($password) at $ip ..."
    sshpass -p "$password" ssh -o StrictHostKeyChecking=no \
      "lab@${ip}" 'echo "Connected to $(hostname)"'
  done < ssh_list.txt
}

function validate_lab_vms() {
  echo "Validating Lab VMs setup..."
  index=0
  rm -f failed-labs.txt

  while IFS= read -r line; do
    ip=$(echo "$line" | awk '{print $3}')
    name=$(echo "$line" | awk '{print $2}')
    password=$(echo "$line" | awk '{print $5}')

    echo "Validating $name at $ip..."

    sshpass -p "$password" ssh -o StrictHostKeyChecking=no \
      "lab@${ip}" <<'EOF'
    output=$(sudo virsh list --all)
    echo "$output"
    if ! echo "$output" | grep -q 'seed.*running'; then echo "'seed' not running"; fi
    if ! echo "$output" | grep -q 'compute0.*shut off'; then echo "'compute0' not shut off"; fi
    if ! echo "$output" | grep -q 'controller0.*shut off'; then echo "'controller0' not shut off"; fi

    echo "$(ssh stack@192.168.33.5 'sudo docker ps')"
    if ! ssh stack@192.168.33.5 'sudo docker ps' | grep -q bifrost_deploy; then echo "Bifrost container isn't deployed"; fi
    if ! tail -n 10 a-seed-from-nothing.out | grep -q 'PLAY RECAP.*failed=0'; then echo "There was an error in running 'a-seed-from-nothing'"; fi
EOF

set +e

   sshpass -p "$password" ssh -o StrictHostKeyChecking=no \
      "lab@${ip}" <<'EOF'
    output=$(sudo virsh list --all)
    if ! echo "$output" | grep -q 'seed.*running'; then exit 1; fi
    if ! echo "$output" | grep -q 'compute0.*shut off'; then exit 1; fi
    if ! echo "$output" | grep -q 'controller0.*shut off'; then exit 1; fi

    if ! ssh stack@192.168.33.5 'sudo docker ps' | grep -q bifrost_deploy; then exit 1; fi
    if ! tail -n 10 a-seed-from-nothing.out | grep -q 'PLAY RECAP.*failed=0'; then exit 1; fi

    exit 0
EOF
    taint_res=$?
    echo "exit error is -> $taint_res"
    if [ $taint_res -gt 0 ]; then echo "$index" >> failed-labs.txt ; fi
    index=$((index + 1))
    set -euo pipefail
  done < ssh_list.txt
}

function taint_and_reapply() {
  if [ ! -s failed-labs.txt ]; then
    echo "No failed VMs detected"
    return
  fi

  echo "Tainting failed VMs..."
  while IFS= read -r line; do
    idx=$(echo "$line" | tr -d '\r')
    echo "Tainting VM at index $idx"
    terraform taint openstack_compute_instance_v2.lab[$idx]
  done < failed-labs.txt
  echo "Rebuilding tainted Lab VMs..."
  terraform apply -auto-approve
  wait
}

# function run_universe_from_seed() {
#   if [[ "$AU_FROM_SEED" != "true" ]]; then return; fi
#   echo "Launching a-universe-from-seed..."
#   mapfile -t ssh_lines < ssh_list.txt
#   for i in "${!ssh_lines[@]}"; do
#     line="${ssh_lines[$i]}"
#     ip=$(echo "$line" | awk '{print $3}')
#     name=$(echo "$line" | awk '{print $2}')
#     password=$(echo "$line" | awk '{print $5}')

#     sshpass -p "$password" ssh -o StrictHostKeyChecking=no \
#       "lab@${ip}" \
#       "tmux new-session -d -s aus-run './a-universe-from-seed.sh'"
#   done
# }

function run_universe_from_seed() {
  if [[ "$AU_FROM_SEED" != "true" ]]; then return; fi
  echo "Launching a-universe-from-seed..."
  while IFS= read -r line; do
    ip=$(echo "$line" | awk '{print $3}')
    name=$(echo "$line" | awk '{print $2}')
    password=$(echo "$line" | awk '{print $5}')

    sshpass -p "$password" ssh -o StrictHostKeyChecking=no \
      "lab@${ip}" \
      "tmux new-session -d -s aus-run './a-universe-from-seed.sh'"
  done < ssh_list.txt
}

# === RUN STEPS ===
sleep 90 # Wait for VMs to be ready

check_lab_vm_connections
validate_lab_vms


if [[ "$TAINT_REBUILD" = "true" ]]; then
  taint_and_reapply
  terraform output -json > tf-outputs.json
  terraform output -raw labs > ssh_list.txt
  validate_lab_vms
else
  echo "Tainting and rebuilding is disabled, skipping..."
fi

run_universe_from_seed

echo "AUFN Test completed successfully!"