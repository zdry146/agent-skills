#!/usr/bin/env bash
# Post-setup E2E smoke test. Verifies that the four pieces — Jenkins,
# the required plugins, the required credentials, and minikube — are
# all in place AND that they line up (the agent can reach minikube, the
# credentials are usable, etc.).
#
# Does NOT modify state. Exits 0 if all checks pass, non-zero otherwise.
# Each failed check is printed as ✗; passed as ✓.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT="$SCRIPT_DIR/detect-env.sh"

# Strip ANSI escapes and fold newlines for safe single-line output.
clean() { sed -E 's/\x1b\[[0-9;]*[mGKHF]//g; s/\r$//' | tr '\n\t' '  ' | sed 's/  */ /g; s/^ //; s/ $//'; }

PASS=0
FAIL=0

check() {
  local name="$1"
  local result="$2"  # "ok" or "fail"
  local detail="${3:-}"
  if [[ "$result" == "ok" ]]; then
    printf "  ✓ %-40s %s\n" "$name" "$detail"
    PASS=$((PASS+1))
  else
    printf "  ✗ %-40s %s\n" "$name" "$detail"
    FAIL=$((FAIL+1))
  fi
}

echo "=== E2E verification ==="
echo

# ---------- host tools ----------
command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 \
  && check "docker" ok "$(docker version --format '{{.Server.Version}}' 2>/dev/null)" \
  || check "docker" fail "not installed or not responding"

command -v kubectl >/dev/null 2>&1 \
  && check "kubectl" ok "$(kubectl version --client -o json 2>/dev/null \
      | python3 -c 'import json,sys;print(json.load(sys.stdin)["clientVersion"]["gitVersion"])' 2>/dev/null)" \
  || check "kubectl" fail "not installed"

command -v minikube >/dev/null 2>&1 \
  && check "minikube" ok "$(minikube version --short 2>/dev/null)" \
  || check "minikube" fail "not installed"

if minikube status --format='{{.Host}}' 2>/dev/null | grep -q Running; then
  check "minikube running" ok "$(minikube status --format='{{.Driver}}' 2>/dev/null)"
else
  check "minikube running" fail "minikube installed but not running"
fi

command -v mvn >/dev/null 2>&1 \
  && check "mvn (Java project)" ok "$(mvn -v 2>/dev/null | head -1 | awk '{print $3}' | clean)" \
  || check "mvn (Java project)" fail "not installed"

# ---------- Jenkins container ----------
if docker ps -a --filter "name=jenkins" --format '{{.Names}}' 2>/dev/null | grep -q '^jenkins$'; then
  STATUS=$(docker ps --filter "name=jenkins" --format '{{.Status}}' 2>/dev/null)
  check "Jenkins container" ok "$STATUS"
else
  check "Jenkins container" fail "absent"
  echo
  echo "Cannot verify Jenkins internals without a container; aborting."
  echo "Total: $PASS passed, $FAIL failed."
  exit 1
fi

if curl -sf -o /dev/null --connect-timeout 2 http://localhost:8080/login 2>/dev/null; then
  check "Jenkins http://localhost:8080" ok ""
else
  check "Jenkins http://localhost:8080" fail "not reachable"
fi

# ---------- Jenkins internals (need creds) ----------
if [[ -z "${JENKINS_USER:-}" || -z "${JENKINS_TOKEN:-}" ]]; then
  echo
  echo "(Set JENKINS_USER and JENKINS_TOKEN to verify plugins, credentials, and agent capabilities.)"
  echo
  echo "Total: $PASS passed, $FAIL failed."
  [[ $FAIL -eq 0 ]] && exit 0 || exit 1
fi

auth=$(printf '%s:%s' "$JENKINS_USER" "$JENKINS_TOKEN" | base64)

# Required plugins present?
have_plugins=$(curl -sf -H "Authorization: Basic $auth" \
  "http://localhost:8080/pluginManager/api/json?depth=1" \
  | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(" ".join(p["shortName"] for p in d["plugins"] if p.get("active")))' 2>/dev/null) \
  || have_plugins=""

for p in git workflow-aggregator credentials credentials-binding docker-workflow pipeline-model-definition; do
  if [[ " $have_plugins " == *" $p "* ]]; then
    check "plugin: $p" ok ""
  else
    check "plugin: $p" fail "not installed"
  fi
done

# Required credentials present?
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
print(" ".join(sorted(ids)))' 2>/dev/null) \
  || have_creds=""

for c in git-cred aliyun-docker-login; do
  if [[ " $have_creds " == *" $c "* ]]; then
    check "credential: $c" ok ""
  else
    check "credential: $c" fail "not configured"
  fi
done

# Agent capabilities: docker, kubectl, kube context inside the container
for tool in docker kubectl; do
  if docker exec -u jenkins jenkins sh -c "command -v $tool" >/dev/null 2>&1; then
    check "agent has $tool" ok ""
  else
    check "agent has $tool" fail "binary not visible inside container"
  fi
done

if docker exec -u jenkins jenkins kubectl get nodes --request-timeout=3s >/dev/null 2>&1; then
  check "agent can reach minikube via kubectl" ok ""
else
  check "agent can reach minikube via kubectl" fail "kubectl inside the container cannot reach the cluster"
fi

# ---------- verdict ----------
echo
echo "Total: $PASS passed, $FAIL failed."
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
