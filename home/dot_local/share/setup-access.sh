export VAULT_ADDR=https://active-vault.query.consul:8200
export VAULT_CACERT=$HOME/.local/share/pki/root/deepgram.pem
export NOMAD_ADDR=https://nomad.query.consul:4646
export NOMAD_CACERT=$HOME/.local/share/pki/root/deepgram.pem
export CONSUL_HTTP_ADDR=https://consul.query.consul:8501

export NOMAD_CREDENTIALS=$HOME/.nomad/credentials
export CONSUL_CREDENTIALS=$HOME/.consul/credentials

mkdir -p $HOME/.nomad

if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi


sign-cert() {
    local role="${1:-devops-plus}"
    export VAULT_SIGNED_CERT=$HOME/.ssh/dg-prod-cert.pub
    pubkey="$(cat $HOME/.ssh/dg-prod.pub)"
    echo "signing pubkey"
    echo $pubkey
    echo
    vault-login $role || exit 1
    rm -rf $VAULT_SIGNED_CERT
    vault write -field=signed_key ssh-client-signer/sign/production valid_principals=michael-steele public_key="$(cat $HOME/.ssh/dg-prod.pub)" > $VAULT_SIGNED_CERT || exit 1
    echo "${VAULT_SIGNED_CERT} successfully signed"
}

load_creds() {
    source $NOMAD_CREDENTIALS
    source $CONSUL_CREDENTIALS
}

pymake() {
    # Usage: pymake [venv_dir] [python_version]
    # Examples:
    #   pymake                                    # Uses defaults
    #   pymake ~/.venv/my-project                # Custom venv location
    #   pymake ~/.venv/my-project python3.12     # Custom venv + Python version
    
    local PROJECT_DIR="${PWD}"
    local PROJECT_NAME="$(basename $PROJECT_DIR)"
    local VENV_DIR="$HOME/.venv/${1:-$PROJECT_NAME}"
    local PYTHON="${2:-python3}"
    local PRIVATE_REPO_URL="https://pypi.org/simple"

    echo "--- Setting up virtual environment ---"
    echo "Venv location: $VENV_DIR"
    echo "Using Python: $PYTHON"
    
    # Verify Python exists
    if ! command -v "$PYTHON" >/dev/null 2>&1; then
        echo "Error: $PYTHON not found. Please install it or specify a different version."
        echo "Example: vw-setup ~/.venv/my-project python3.12"
        return 1
    fi
    
    # Show Python version
    echo "Python version: $($PYTHON --version)"
    
    # Create venv if it doesn't exist
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating virtual environment at $VENV_DIR"
        "$PYTHON" -m venv "$VENV_DIR"
    fi
    
    # Upgrade pip
    "$VENV_DIR/bin/pip" install --upgrade pip
    
    # Install dependencies
    echo "--- Installing dependencies ---"
    
    if command -v uv >/dev/null 2>&1; then
        echo "Using system uv for installation"
        uv pip install --python "$VENV_DIR/bin/python" --extra-index-url "$PRIVATE_REPO_URL" -e ".[test]"
    else
        echo "uv not found, installing uv into virtual environment"
        "$VENV_DIR/bin/pip" install uv
        echo "Using venv uv for installation"
        "$VENV_DIR/bin/uv" pip install --python "$VENV_DIR/bin/python" --extra-index-url "$PRIVATE_REPO_URL" -e ".[test]"
    fi || {
        echo "uv installation failed, falling back to pip"
        "$VENV_DIR/bin/pip" install --extra-index-url "$PRIVATE_REPO_URL" -e ".[test]"
    }
    
    echo ""
    echo "✅ Setup complete."
    echo "Run 'source $VENV_DIR/bin/activate' to activate"
    echo "Or run: vw-activate $VENV_DIR"
}

# Activate function that also takes venv path as argument
pyswitch() {
    local PROJECT_DIR="${PWD}"
    local PROJECT_NAME="$(basename $PROJECT_DIR)"
    local VENV_DIR="$HOME/.venv/${1:-$PROJECT_NAME}"
    
    if [ -d "$VENV_DIR" ]; then
        source "$VENV_DIR/bin/activate"
        echo "✅ Activated venv: $VENV_DIR"
    else
        echo "❌ Venv not found at $VENV_DIR"
        echo "Run 'vw-setup $VENV_DIR' first"
        return 1
    fi
}

asg-list() {
  local profile=""
  local asg="research-preview-asg"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        profile="$2"
        shift 2
        ;;
      --asg)
        asg="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        echo "Usage: asg-list [--profile <profile>] [--asg [asg-name]" >&2
        return 1
        ;;
    esac
  done

  profile=${profile:-$AWS_PROFILE}
  profile=${profile:-default}

  echo "Using AWS profile: $profile"
  echo ""
  echo "Listing instances in ASG: $asg"

  aws ec2 describe-instances \
    --profile "${profile}" \
    --region us-west-2 \
    --filters "Name=tag:Name,Values=${asg}" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,LaunchTime]' \
    --output table \
    --no-cli-pager
}

asg-connect() {
  local profile=""
  local use_ssh=false
  local instance_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        profile="$2"
        shift 2
        ;;
      --ssh)
        use_ssh=true
        shift
        ;;
      -*)
        echo "Unknown option: $1" >&2
        echo "Usage: asg-connect [--profile <profile>] [--ssh] <instance-id>" >&2
        return 1
        ;;
      *)
        instance_id="$1"
        shift
        ;;
    esac
  done

  profile=${profile:-$AWS_PROFILE}
  profile=${profile:-default}

  if [[ -z "$instance_id" ]]; then
    echo "Error: Instance ID required" >&2
    echo "Usage: asg-connect [--profile <profile>] [--ssh] <instance-id>" >&2
    return 1
  fi

  echo "Using AWS profile: $profile"

  if [[ "$use_ssh" == true ]]; then
    echo "Starting SSH tunnel session to $instance_id..."
    aws ssm start-session \
      --profile "$profile" \
      --region us-west-2 \
      --target "$instance_id" \
      --document-name AWS-StartSSHSession \
      --parameters portNumber=22
  else
    echo "Starting SSM session to $instance_id..."
    aws ssm start-session \
      --profile "$profile" \
      --region us-west-2 \
      --target "$instance_id"
  fi
}


# -------- Config --------
DEEPGRAM_DIR="${HOME}/.deepgram"
VAULT_CREDS_FILE="${DEEPGRAM_DIR}/vault.json"
NOMAD_CREDS_FILE="${DEEPGRAM_DIR}/nomad.json"

# used when needing to source credentials into environment
VAULT_ENV_FILE="${HOME}/.local/vault.credentials"
NOMAD_ENV_FILE="${HOME}/.local/nomad.credentials"

DEFAULT_TTL_SECONDS=""   # e.g. "43200" for 12h; leave empty for "no-expiry if ttl missing"

# -------- Helpers --------
_need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    return 1
  }
}

_ensure_store() {
  local file="$1"
  mkdir -p "$DEEPGRAM_DIR"
  if [ ! -f "$file" ]; then
    printf '{}' > "$file"
  fi
}

# Returns 0 if role entry exists and is NOT expired; prints "ENVVAR<TAB>VALUE"
# for requested key if present.
_get_valid_cached_value() {
  local file="$1" role="$2" key="$3"

  [ -f "$file" ] || return 1

  # Role must exist and contain key
  local has
  has="$(jq -r --arg role "$role" --arg key "$key" '
    (has($role) and .[$role] != null and (.[$role] | has($key))) // false
  ' "$file")"
  [ "$has" = "true" ] || return 1

  local now ts ttl expires value
  now="$(date +%s)"

  ts="$(jq -r --arg role "$role" '.[$role].timestamp // empty' "$file")"
  ttl="$(jq -r --arg role "$role" '.[$role].ttl // empty' "$file")"
  value="$(jq -r --arg role "$role" --arg key "$key" '.[$role][$key] // empty' "$file")"

  [ -n "$value" ] || return 1

  # If we have both timestamp and ttl (numeric), enforce expiry
  if [[ "$ts" =~ ^[0-9]+$ ]] && [[ "$ttl" =~ ^[0-9]+$ ]]; then
    expires=$((ts + ttl))
    if [ "$now" -ge "$expires" ]; then
      return 1
    fi
  else
    # Missing ttl -> either treat as non-expiring, or apply DEFAULT_TTL_SECONDS if set
    if [ -n "${DEFAULT_TTL_SECONDS}" ] && [[ "$ts" =~ ^[0-9]+$ ]] && [[ "$DEFAULT_TTL_SECONDS" =~ ^[0-9]+$ ]]; then
      expires=$((ts + DEFAULT_TTL_SECONDS))
      if [ "$now" -ge "$expires" ]; then
        return 1
      fi
    fi
  fi

  printf '%s\t%s\n' "$key" "$value"
  return 0
}

# Upserts: .[role] = {KEY: value, timestamp: now, ttl: ttl}
_put_role_entry() {
  local file="$1" role="$2" key="$3" value="$4" timestamp="$5" ttl="$6"

  # ttl may be empty/null; write JSON null when empty
  if [ -n "$ttl" ] && [[ "$ttl" =~ ^[0-9]+$ ]]; then
    jq --arg role "$role" \
       --arg key "$key" \
       --arg value "$value" \
       --argjson ts "$timestamp" \
       --argjson ttl "$ttl" \
       '
       .[$role] = (.[$role] // {})
       | .[$role][$key] = $value
       | .[$role].timestamp = $ts
       | .[$role].ttl = $ttl
       ' "$file" > "${file}.tmp" && command mv -f "${file}.tmp" "$file"
  else
    jq --arg role "$role" \
       --arg key "$key" \
       --arg value "$value" \
       --argjson ts "$timestamp" \
       '
       .[$role] = (.[$role] // {})
       | .[$role][$key] = $value
       | .[$role].timestamp = $ts
       | .[$role].ttl = null
       ' "$file" > "${file}.tmp" && command mv -f "${file}.tmp" "$file"
  fi
}

# -------- Public functions --------

vault-login() {
  _need_cmd vault
  _need_cmd jq
  _ensure_store "$VAULT_CREDS_FILE"

  local role="devops-plus"
  local force=false
  local skip_browser=false

  # --- arg parsing ---
  #   -f|--force         force re-login, ignore cache
  #   -b|--skip-browser  use the manual-callback flow (for remote SSH sessions
  #                      where Vault cannot open a local browser)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--force)
        force=true
        shift
        ;;
      -b|--skip-browser)
        skip_browser=true
        shift
        ;;
      *)
        role="$1"
        shift
        ;;
    esac
  done

  # Try cache first
  local cached
  if ! $force; then
    echo "Checking cached Vault token for role: $role in $VAULT_CREDS_FILE"
    if cached="$(_get_valid_cached_value "$VAULT_CREDS_FILE" "$role" "VAULT_TOKEN")"; then
      rm -rf "$VAULT_ENV_FILE"
      echo "export VAULT_TOKEN=\"${cached#*$'\t'}\"" > "$VAULT_ENV_FILE"
      export VAULT_TOKEN="${cached#*$'\t'}"
      echo "Using cached VAULT_TOKEN for role: $role"
      return 0
    fi
  else
    echo "Forcing Vault login (skipping cache) for role: $role"
  fi

  echo "Creating Vault access for role: $role"

  local login_json token ttl now
  if $skip_browser; then
    login_json="$(_vault_oidc_manual_callback "$role")" || return 1
  else
    if ! login_json="$(vault login -method=oidc role="$role" -format=json 2>/dev/null)"; then
      echo "Vault login failed" >&2
      vault login -method=oidc role="$role" 1>/dev/null
      return 1
    fi
  fi

  token="$(jq -r '.auth.client_token // empty' <<<"$login_json")"
  ttl="$(jq -r '.auth.lease_duration // empty' <<<"$login_json")"
  now="$(date +%s)"

  if [ -z "$token" ]; then
    echo "Failed to parse Vault token from JSON output" >&2
    return 1
  fi

  rm -rf "$VAULT_ENV_FILE"
  echo "export VAULT_TOKEN=\"${token}\"" > "$VAULT_ENV_FILE"
  export VAULT_TOKEN="${token}"
  _put_role_entry "$VAULT_CREDS_FILE" "$role" "VAULT_TOKEN" "$token" "$now" "$ttl"

  echo "VAULT_TOKEN set successfully for role: $role"
}

# Background-vault + paste-callback OIDC flow for SSH sessions where Vault
# cannot open a browser. The CLI listener stays bound to localhost:8250 on
# THIS host; the user's local browser cannot reach it, so we relay the
# callback URL via curl on this host instead of via SSH port forwarding.
# Writes the vault JSON token blob to stdout on success.
_vault_oidc_manual_callback() {
  _need_cmd curl
  local role="$1"
  local out_file err_file vault_pid auth_url callback_url waited

  out_file="$(mktemp)" || return 1
  err_file="$(mktemp)" || { rm -f "$out_file"; return 1; }

  # Clean up the background vault and temp files on Ctrl-C, error, or normal return
  trap '[ -n "${vault_pid:-}" ] && kill "$vault_pid" 2>/dev/null; rm -f "$out_file" "$err_file"; trap - INT TERM RETURN' INT TERM RETURN

  vault login -method=oidc -format=json role="$role" skip_browser=true \
      >"$out_file" 2>"$err_file" &
  vault_pid=$!

  # Vault prints the Keycloak auth URL on stderr almost immediately
  waited=0
  while ! grep -qE 'https?://' "$err_file" 2>/dev/null; do
    if ! kill -0 "$vault_pid" 2>/dev/null; then
      echo "vault login exited before printing the auth URL:" >&2
      cat "$err_file" >&2
      return 1
    fi
    sleep 0.1
    waited=$((waited + 1))
    if [ "$waited" -gt 100 ]; then
      echo "Timed out (10s) waiting for Vault to print the auth URL" >&2
      kill "$vault_pid" 2>/dev/null
      return 1
    fi
  done

  auth_url="$(grep -oE 'https?://[^[:space:]]+' "$err_file" | head -1)"

  cat >&2 <<EOF

────────────────────────────────────────────────────────────────────────
Vault OIDC login (manual callback relay — no SSH port forward needed).

1. Open this URL in your LOCAL browser:

   $auth_url

2. Authenticate via Keycloak.

3. Your browser will redirect to http://localhost:8250/oidc/callback?...
   That tab will fail to load (expected — the listener is on this host,
   not your laptop). Copy the FULL URL from your browser's address bar
   and paste it below.

   The OIDC code is short-lived (~60s), so paste promptly.
────────────────────────────────────────────────────────────────────────

EOF

  IFS= read -r -p "Callback URL: " callback_url
  if [ -z "$callback_url" ]; then
    echo "No callback URL provided; aborting" >&2
    kill "$vault_pid" 2>/dev/null
    return 1
  fi

  if ! curl -sf "$callback_url" > /dev/null; then
    echo "Failed to deliver callback to localhost:8250 (URL may have expired or been malformed)" >&2
    kill "$vault_pid" 2>/dev/null
    return 1
  fi

  # Vault now exchanges the code with Keycloak, prints JSON to out_file, exits
  if ! wait "$vault_pid"; then
    echo "vault login failed:" >&2
    cat "$err_file" >&2
    return 1
  fi

  cat "$out_file"
}

nomad-login() {
  _need_cmd vault
  _need_cmd jq
  _ensure_store "$NOMAD_CREDS_FILE"
  local role="devops-plus"
  local force=false

  # --- arg parsing ---
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--force)
        force=true
        shift
        ;;
      *)
        role="$1"
        shift
        ;;
    esac
  done

  # Try cache first
  local cached
  if ! $force; then
    if cached="$(_get_valid_cached_value "$NOMAD_CREDS_FILE" "$role" "NOMAD_TOKEN")"; then
      rm -rf $NOMAD_ENV_FILE
      echo "export NOMAD_TOKEN=\"${cached#*$'\t'}\"" > "$NOMAD_ENV_FILE"
      export NOMAD_TOKEN="${cached#*$'\t'}"
      echo "Using cached NOMAD_TOKEN for role: $role"
      return 0
    fi
  else
    echo "Forcing Nomad login (skipping cache) for role: $role"
  fi

  echo "Creating Nomad access for role: $role"

  vault-login "$role" || {
    echo "Cannot obtain Vault token; aborting Nomad login" >&2
    return 1
  }

  # Prefer JSON to capture lease_duration if the secret is leased
  local nomad_json token ttl now
  if ! nomad_json="$(vault read -format=json "nomad/creds/${role}" 2>/dev/null)"; then
    echo "Failed to retrieve Nomad token from Vault at nomad/creds/${role}" >&2
    return 1
  fi

  # Some setups return token in .data.secret_id (your original), others might differ.
  token="$(jq -r '.data.secret_id // empty' <<<"$nomad_json")"
  ttl="$(jq -r '.lease_duration // empty' <<<"$nomad_json")"
  now="$(date +%s)"

  if [ -z "$token" ]; then
    echo "Failed to parse NOMAD_TOKEN (expected .data.secret_id) from JSON output" >&2
    return 1
  fi

  rm -rf $NOMAD_ENV_FILE
  echo "export NOMAD_TOKEN=\"${token}\"" > "$NOMAD_ENV_FILE"
  export NOMAD_TOKEN="${token}"
  _put_role_entry "$NOMAD_CREDS_FILE" "$role" "NOMAD_TOKEN" "$token" "$now" "$ttl"

  echo "NOMAD_TOKEN set successfully for role: $role"
}

sync-staging() {
  rsync -az --progress --delete \
    --exclude='.git/' \
    --exclude='.claude/' \
    --exclude='*.md' \
    --exclude='terraform/**/.terraform/' \
    --exclude='terraform/**/.terraform.lock.hcl' \
    $HOME/workspace/nomad-jobs/ dg11:~/nomad-jobs/
}
