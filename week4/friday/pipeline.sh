#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$ROOT_DIR/terraform"
ANSIBLE_DIR="$ROOT_DIR/ansible"
SSH_KEY_PATH="${HOME}/.ssh/kijani-admin-key.pem"
TF_VARS_FILE="$TF_DIR/terraform.tfvars"
BACKEND_HCL="$TF_DIR/backend.hcl"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

detect_public_ip() {
  local ip
  for url in "https://checkip.amazonaws.com" "https://api.ipify.org" "https://ifconfig.me/ip"; do
    ip="$(curl --connect-timeout 5 --max-time 10 -fsS "$url" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      printf '%s\n' "$ip"
      return 0
    fi
  done
  return 1
}

export_aws_session() {
  local attempt exports
  for attempt in 1 2 3; do
    exports="$(timeout 30 aws configure export-credentials --profile "$AWS_PROFILE_NAME" --format env 2>/dev/null || true)"
    if [[ -n "$exports" ]]; then
      eval "$exports"
      return 0
    fi
    log "Retrying AWS credential export (${attempt}/3)"
  done
  return 1
}

lookup_account_id() {
  local attempt account
  for attempt in 1 2 3; do
    account="$(timeout 30 aws sts get-caller-identity --region "$REGION" --query Account --output text 2>/dev/null || true)"
    if [[ "$account" =~ ^[0-9]{12}$ ]]; then
      printf '%s\n' "$account"
      return 0
    fi
    log "Retrying AWS identity check (${attempt}/3)"
  done
  return 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

require_cmd aws
require_cmd terraform
require_cmd ansible-playbook
require_cmd ansible-galaxy

mkdir -p "$ANSIBLE_DIR"
cp -f "$TF_DIR/terraform.tfvars.example" "$TF_VARS_FILE"

log "Detecting operator public IP for SSH allowlist"
OPERATOR_IP="$(detect_public_ip || true)"
if [[ -z "$OPERATOR_IP" ]]; then
  log "Falling back to the SSH CIDR already defined in terraform.tfvars.example"
  OPERATOR_IP="$(awk -F'"' '/^ssh_ingress_cidr/ {print $2}' "$TF_VARS_FILE" | cut -d/ -f1)"
fi

if [[ -z "$OPERATOR_IP" ]]; then
  echo "Could not determine operator public IP for SSH ingress." >&2
  exit 1
fi

sed -i "s|^ssh_ingress_cidr.*|ssh_ingress_cidr   = \"${OPERATOR_IP}/32\"|" "$TF_VARS_FILE"
sed -i "s|^private_key_path.*|private_key_path   = \"${SSH_KEY_PATH}\"|" "$TF_VARS_FILE"

AWS_PROFILE_NAME="$(awk -F'=' '/^aws_profile/ {gsub(/[ "\t]/, "", $2); print $2}' "$TF_VARS_FILE")"
REGION="$(awk -F'=' '/^region/ {gsub(/[ "\t]/, "", $2); print $2}' "$TF_VARS_FILE")"
export AWS_PROFILE="$AWS_PROFILE_NAME"
export AWS_SDK_LOAD_CONFIG=1
export AWS_PAGER=""
export AWS_RETRY_MODE=standard
export AWS_MAX_ATTEMPTS=10

log "Exporting AWS session credentials"
if export_aws_session; then
  log "Using exported AWS session credentials"
else
  log "Falling back to AWS CLI profile authentication"
fi

log "Validating AWS identity"
ACCOUNT_ID="$(awk -F'"' '/^bucket/ {print $2}' "$BACKEND_HCL" 2>/dev/null | sed -E 's/^kijanikiosk-tf-state-([0-9]{12})-.*/\1/' || true)"
if [[ -z "$ACCOUNT_ID" || ! "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  ACCOUNT_ID="$(lookup_account_id || true)"
fi

if [[ -z "$ACCOUNT_ID" || ! "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  echo "Could not determine the AWS account ID for the remote state bucket." >&2
  exit 1
fi

STATE_BUCKET="kijanikiosk-tf-state-${ACCOUNT_ID}-${REGION}"
LOCK_TABLE="kijanikiosk-terraform-locks"

aws_safe() {
  timeout 60 aws --region "$REGION" "$@"
}

log "Ensuring remote state resources exist"
if [[ -f "$BACKEND_HCL" ]] && grep -q 'kijanikiosk-tf-state-' "$BACKEND_HCL"; then
  log "Reusing existing backend bucket and lock table configuration"
else
  if ! aws_safe s3api head-bucket --bucket "$STATE_BUCKET" >/dev/null 2>&1; then
    if [[ "$REGION" == "us-east-1" ]]; then
      aws_safe s3api create-bucket --bucket "$STATE_BUCKET"
    else
      aws_safe s3api create-bucket --bucket "$STATE_BUCKET" --create-bucket-configuration LocationConstraint="$REGION"
    fi
  fi
  aws_safe s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled >/dev/null
  aws_safe s3api put-bucket-encryption --bucket "$STATE_BUCKET" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' >/dev/null

  if ! aws_safe dynamodb describe-table --table-name "$LOCK_TABLE" >/dev/null 2>&1; then
    aws_safe dynamodb create-table \
      --table-name "$LOCK_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST >/dev/null
  fi
fi

cat > "$BACKEND_HCL" <<EOF
bucket         = "$STATE_BUCKET"
key            = "week4/friday/terraform.tfstate"
region         = "$REGION"
dynamodb_table = "$LOCK_TABLE"
profile        = "$AWS_PROFILE_NAME"
encrypt        = true
EOF

log "Initializing Terraform"
terraform -chdir="$TF_DIR" init -reconfigure -input=false -backend-config="$BACKEND_HCL"
terraform -chdir="$TF_DIR" fmt -recursive

log "Planning infrastructure"
terraform -chdir="$TF_DIR" plan -input=false -var-file=terraform.tfvars -out=pipeline.tfplan

log "Applying infrastructure"
terraform -chdir="$TF_DIR" apply -input=false -auto-approve pipeline.tfplan

API_IP="$(terraform -chdir="$TF_DIR" output -raw api_server_ip)"
PAYMENTS_IP="$(terraform -chdir="$TF_DIR" output -raw payments_server_ip)"
LOGS_IP="$(terraform -chdir="$TF_DIR" output -raw logs_server_ip)"

log "Writing Ansible inventory from Terraform outputs"
cat > "$ANSIBLE_DIR/inventory.ini" <<EOF
[kijanikiosk]
api-staging ansible_host=${API_IP} ansible_user=ubuntu
payments-staging ansible_host=${PAYMENTS_IP} ansible_user=ubuntu
logs-staging ansible_host=${LOGS_IP} ansible_user=ubuntu

[kijanikiosk:vars]
ansible_ssh_private_key_file=${SSH_KEY_PATH}
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

log "Waiting for SSH connectivity"
for ip in "$API_IP" "$PAYMENTS_IP" "$LOGS_IP"; do
  until ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 ubuntu@"$ip" 'echo ready' >/dev/null 2>&1; do
    log "SSH not ready yet for $ip; retrying"
    sleep 5
  done
done

log "Installing required Ansible collections"
ansible-galaxy collection install -r "$ANSIBLE_DIR/requirements.yml" >/dev/null

log "Running Ansible playbook"
ansible-playbook -i "$ANSIBLE_DIR/inventory.ini" "$ANSIBLE_DIR/kijanikiosk.yml"

log "Pipeline complete"
