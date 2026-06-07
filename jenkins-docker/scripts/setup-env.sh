#!/usr/bin/env bash
# Interactive E2E environment setup for the Jenkins pipeline workflow.
#
# Workflow:
#   1. Run detect-env.sh and show the current state.
#   2. For each component, present the current state and prompt:
#        r = reuse (skip — already good)
#        g = gap-fill (add only what's missing)
#        o = override (recreate from scratch — destructive)
#        s = skip (do nothing, don't ask again)
#   3. Apply the chosen action.
#   4. Re-run detect to show the new state.
#
# The script is idempotent at the component level: re-running it just shows
# the current state and lets you tweak it.
#
# For Jenkins plugin/credential APIs, export JENKINS_USER and JENKINS_TOKEN.
# For adding the aliyun ACR credential, the script will prompt for the
# registry username and password at the appropriate moment.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT="$SCRIPT_DIR/detect-env.sh"
START_JENKINS="$SCRIPT_DIR/start-jenkins.sh"

REQUIRED_CREDS=(git-cred aliyun-docker-login)
REQUIRED_PLUGINS=(
  git git-client scm-api
  workflow-aggregator workflow-cps workflow-job workflow-multibranch workflow-scm-step
  pipeline-model-definition
  credentials credentials-binding plain-credentials ssh-credentials
  script-security
  docker-workflow docker-commons
)

# ---------- helpers ----------

# Strip ANSI escapes and fold newlines for safe single-line output.
clean() { sed -E 's/\x1b\[[0-9;]*[mGKHF]//g; s/\r$//' | tr '\n\t' '  ' | sed 's/  */ /g; s/^ //; s/ $//'; }

prompt_choice() {
  local prompt="$1"; shift
  local default="${1:-r}"
  local ans
  read -r -p "$prompt [$default] " ans || true
  echo "${ans:-$default}"
}

confirm_destructive() {
  local what="$1"
  echo
  echo "*** WARNING: '$what' will destroy existing state. ***"
  local ans
  read -r -p "Type YES (in capitals) to confirm: " ans
  [[ "$ans" == "YES" ]]
}

# ---------- per-component handlers ----------

setup_docker() {
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "  docker: present, OK"
    return
  fi
  echo "  docker: not present or not responding"
  echo "  Install docker via your distro's package manager, then re-run."
}

setup_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then
    echo "  kubectl: present ($(kubectl version --client -o json 2>/dev/null \
      | python3 -c 'import json,sys;print(json.load(sys.stdin)["clientVersion"]["gitVersion"])' 2>/dev/null))"
    return
  fi
  echo "  kubectl: not installed"
  echo "  Install: https://kubernetes.io/docs/tasks/tools/  (or: sudo apt-get install -y kubectl)"
}

setup_minikube() {
  if ! command -v minikube >/dev/null 2>&1; then
    echo "  minikube: not installed"
    echo "  Install: curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
    echo "           sudo install minikube-linux-amd64 /usr/local/bin/minikube"
    return
  fi
  if minikube status --format='{{.Host}}' 2>/dev/null | grep -q Running; then
    echo "  minikube: running"
    return
  fi
  echo "  minikube: installed, not running"
  echo "  Start with: minikube start --driver=docker"
}

setup_maven() {
  if command -v mvn >/dev/null 2>&1; then
    echo "  mvn: present ($(mvn -v 2>/dev/null | head -1 | awk '{print $3}' | clean))"
    return
  fi
  echo "  mvn: not installed (needed only for Maven Java projects)"
  echo "  Install: sudo apt-get install -y maven  (or use sdkman / a docker image)"
}

# Jenkins container handler.
# Actions:
#   r = reuse as-is
#   g = gap-fill (add missing plugins + credentials)
#   o = override (recreate — destructive, loses all jobs/credentials)
#   s = skip
setup_jenkins() {
  local state="$JENKINS_PRESENT"
  local url_state="$JENKINS_URL_OK"
  echo "  container: $state"
  echo "  http:      $url_state"
  echo "  plugins:   ${JENKINS_PLUGIN_COUNT:-?}"
  echo "  creds:     ${JENKINS_CRED_IDS:-?}"

  if [[ "$state" == "absent" ]]; then
    local choice
    choice=$(prompt_choice "  Jenkins container is absent. Install now? (y/n)" "y")
    case "$choice" in
      y|Y) "$START_JENKINS" ;;
      *)   echo "  skipped" ;;
    esac
    return
  fi

  if [[ "$url_state" != yes* ]]; then
    echo "  container present but http://localhost:8080 unreachable; trying to start it"
    docker start jenkins >/dev/null 2>&1 || true
    sleep 2
  fi

  if [[ -z "${JENKINS_USER:-}" || -z "${JENKINS_TOKEN:-}" ]]; then
    echo "  set JENKINS_USER and JENKINS_TOKEN to enable gap-fill / override prompts"
    return
  fi

  local choice
  choice=$(prompt_choice "  Action (r=reuse, g=gap-fill plugins+creds, o=override, s=skip)" "r")
  case "$choice" in
    r|R) echo "  reused as-is" ;;
    s|S) echo "  skipped" ;;
    g|G) gap_fill_jenkins ;;
    o|O)
      if confirm_destructive "recreate Jenkins container"; then
        "$START_JENKINS"
      else
        echo "  cancelled"
      fi
      ;;
    *) echo "  unknown choice, skipped" ;;
  esac
}

# Add only the missing required plugins and credentials.
# Existing ones are left untouched.
gap_fill_jenkins() {
  local auth
  auth=$(printf '%s:%s' "$JENKINS_USER" "$JENKINS_TOKEN" | base64)

  # --- plugins ---
  echo "  -- plugins --"
  local have
  have=$(curl -sf -H "Authorization: Basic $auth" \
    "http://localhost:8080/pluginManager/api/json?depth=1" \
    | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(" ".join(p["shortName"] for p in d["plugins"] if p.get("active")))' 2>/dev/null) || {
    echo "  (could not query plugin list; check JENKINS_USER/JENKINS_TOKEN)"
    return
  }
  local missing=()
  for p in "${REQUIRED_PLUGINS[@]}"; do
    [[ " $have " == *" $p "* ]] || missing+=("$p")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "  all required plugins present"
  else
    echo "  installing missing plugins: ${missing[*]}"
    docker exec jenkins /usr/bin/jenkins-plugin-cli --plugins "${missing[*]}" \
      || echo "  (plugin-cli install failed; will require a restart to activate)"
  fi

  # --- credentials ---
  echo "  -- credentials --"
  local have_creds
  have_creds=$(curl -sf -H "Authorization: Basic $auth" \
    "http://localhost:8080/credentials/api/json?depth=4" \
    | python3 -c '
import json,sys
d=json.load(sys.stdin)
ids=set()
for s in d["stores"].values():
    for dom in s["domains"].values():
        for c in (dom.get("credentials") or []):
            ids.add(c["id"])
print(" ".join(sorted(ids)))' 2>/dev/null) || {
    echo "  (could not query credential list)"
    return
  }
  local missing_creds=()
  for c in "${REQUIRED_CREDS[@]}"; do
    [[ " $have_creds " == *" $c "* ]] || missing_creds+=("$c")
  done
  if [[ ${#missing_creds[@]} -eq 0 ]]; then
    echo "  all required credentials present"
  else
    for c in "${missing_creds[@]}"; do
      case "$c" in
        git-cred)
          add_credential_userpass "git-cred" "GitHub / GitLab SCM credential"
          ;;
        aliyun-docker-login)
          add_credential_userpass "aliyun-docker-login" "Aliyun container registry"
          ;;
      esac
    done
  fi
}

# Add a Username-with-password credential to the Jenkins system store.
# Prompts for username and password.
add_credential_userpass() {
  local id="$1" desc="$2"
  local user pass
  read -r -p "  username for $id: " user
  read -r -s -p "  password (input hidden): " pass; echo
  local auth
  auth=$(printf '%s:%s' "$JENKINS_USER" "$JENKINS_TOKEN" | base64)
  local xml
  xml=$(cat <<EOF
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>$id</id>
  <description>$desc</description>
  <username>$user</username>
  <password>$pass</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF
)
  if curl -sf -H "Authorization: Basic $auth" -H "Content-Type: application/xml" \
       --data-binary "$xml" \
       "http://localhost:8080/credentials/store/system/domain/_/createCredentials" \
       >/dev/null 2>&1; then
    echo "  created credential '$id'"
  else
    echo "  FAILED to create credential '$id' (id may already exist, or API path differs)"
  fi
}

# ---------- main ----------

echo
echo "================================================================"
echo " Jenkins Docker skill — E2E environment setup"
echo "================================================================"
echo
echo "Inventory:"
echo "----------"
"$DETECT"

# capture state into globals for setup_jenkins
JENKINS_PRESENT=$(docker ps -a --filter "name=jenkins" --format '{{.Names}}' 2>/dev/null | grep -q '^jenkins$' && echo present || echo absent)
JENKINS_URL_OK=$(curl -sf -o /dev/null --connect-timeout 2 http://localhost:8080/login 2>/dev/null && echo "yes" || echo "no")
JENKINS_PLUGIN_COUNT=$("$DETECT" --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["jenkins"]["plugins"])' 2>/dev/null || echo "")
JENKINS_CRED_IDS=$("$DETECT" --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["jenkins"]["credentials"])' 2>/dev/null || echo "")

echo
echo "Per-component actions:"
echo "----------------------"
echo
echo "1) docker"
setup_docker
echo
echo "2) kubectl"
setup_kubectl
echo
echo "3) minikube"
setup_minikube
echo
echo "4) mvn (only needed for Maven Java projects)"
setup_maven
echo
echo "5) Jenkins container"
setup_jenkins
echo
echo "================================================================"
echo " Final state"
echo "================================================================"
"$DETECT"
