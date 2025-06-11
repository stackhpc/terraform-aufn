#!/usr/bin/env bash
set -euo pipefail

AU_FROM_SEED="$1"
OS_IMAGE="$2"

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
  while IFS= read -r line; do
    ip=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | awk '{print $3}')
    password=$(echo "$line" | awk '{print $5}')
    echo "::add-mask::$password"

    echo "Connecting to $name at $ip via bastion..."
    sshpass -p "$password" ssh -o StrictHostKeyChecking=no \
      "${LAB_IMAGE_USER}@${ip}" 'echo "Connected to $(hostname)"'
  done < ssh_list.txt
}

function validate_lab_vms() {
  echo "Validating Lab VMs setup..."
  index=0
  failed_indexes=()
  while IFS= read -r line; do
    ip=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | awk '{print $3}')
    password=$(echo "$line" | awk '{print $5}') > /dev/null

    echo "Validating $name at $ip..."

    taint="false"

    sshpass -p "$password" ssh -o StrictHostKeyChecking=no "${LAB_IMAGE_USER}@${ip}" <<'EOF'
    output=$(sudo virsh list --all)
    echo "$output"
    if ! echo "$output" | grep -q 'seed.*running'; then echo "'seed' not running"; exit 1; fi
    if ! echo "$output" | grep -q 'compute0.*shut off'; then echo "'compute0' not shut off"; exit 1; fi
    if ! echo "$output" | grep -q 'controller0.*shut off'; then echo "'controller0' not shut off"; exit 1; fi

    if ! ssh stack@192.168.33.5 'sudo docker ps' | grep -q bifrost_deploy; then exit 1; fi
    if ! ssh stack@192.168.33.5 'sudo dnf info openssh' | grep -q 'Repository *: *@System'; then exit 1; fi
    if ! tail -n 10 a-seed-from-nothing.out | grep -q 'PLAY RECAP.*failed=0'; then exit 1; fi
EOF
    if [[ $? -ne 0 ]]; then failed_indexes+=($index); fi
    index=$((index + 1))
  done < ssh_list.txt

  echo "FAILED_VM_INDEXES=${failed_indexes[*]}" >> "$GITHUB_ENV"
}

function taint_and_reapply() {
  if [ -z "${FAILED_VM_INDEXES:-}" ]; then
    echo "✅ No failed VMs detected"
    return
  fi

  echo "Tainting failed VMs..."
  for idx in $FAILED_VM_INDEXES; do
    terraform taint "openstack_compute_instance_v2.lab[$idx]"
  done
  terraform apply -auto-approve
}

function post_redeploy_checks() {
  echo "Re-testing failed VMs after redeploy..."
  mapfile -t ssh_lines < ssh_list.txt
  for idx in $FAILED_VM_INDEXES; do
    line="${ssh_lines[$idx]}"
    ip=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | awk '{print $3}')
    password=$(echo "$line" | awk '{print $5}') > /dev/null


    sshpass -p "$password" ssh -o StrictHostKeyChecking=no "${LAB_IMAGE_USER}@${ip}" <<'EOF' || {
      terraform destroy -auto-approve
      exit 1
    }
    output=$(sudo virsh list --all)
    echo "$output"
    if ! echo "$output" | grep -q 'seed.*running'; then exit 1; fi
    if ! echo "$output" | grep -q 'compute0.*shut off'; then exit 1; fi
    if ! echo "$output" | grep -q 'controller0.*shut off'; then exit 1; fi
    if ! ssh stack@192.168.33.5 'sudo docker ps' | grep -q bifrost_deploy; then exit 1; fi
    if ! ssh stack@192.168.33.5 'sudo dnf info openssh' | grep -q 'Repository *: *@System'; then exit 1; fi
    if ! tail -n 20 a-seed-from-nothing.out | grep -q 'PLAY RECAP.*failed=0'; then exit 1; fi
EOF
  done
}

function run_universe_from_seed() {
  if [[ "$AU_FROM_SEED" != "true" ]]; then return; fi
  echo "🌌 Launching a-universe-from-seed..."
  mapfile -t ssh_lines < ssh_list.txt
  for i in "${!ssh_lines[@]}"; do
    line="${ssh_lines[$i]}"
    ip=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | awk '{print $3}')
    password=$(echo "$line" | awk '{print $5}') > /dev/null

    sshpass -p "$password" ssh -o StrictHostKeyChecking=no \
      "${LAB_IMAGE_USER}@${ip}" \
      "tmux new-session -d -s aus-run './a-universe-from-seed.sh'"
  done
}

# === RUN STEPS ===
check_lab_vm_connections
validate_lab_vms
taint_and_reapply
terraform output -json > tf-outputs.json
terraform output -raw labs > ssh_list.txt
post_redeploy_checks
run_universe_from_seed

echo "AUFN Test completed successfully!"