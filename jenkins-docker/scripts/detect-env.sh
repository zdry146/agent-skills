#!/usr/bin/env bash
# Inventory the current E2E environment for the Jenkins pipeline workflow.
# Prints a human-readable table by default; pass --json for machine output.
#
# Safe: read-only. Does not start, stop, install, or modify anything.
#
# To query the Jenkins plugin/credential inventory, export JENKINS_USER and
# JENKINS_TOKEN (e.g. from your .env). The script will not prompt for them.
set -uo pipefail

JSON=0
[[ "${1:-}" == "--json" ]] && JSON=1

# Strip ANSI escapes and fold newlines so the value is safe to embed in JSON
# and reads as a single line in the human table.
clean() { sed -E 's/\x1b\[[0-9;]*[mGKHF]//g; s/\r$//' | tr '\n\t' '  ' | sed 's/  */ /g; s/^ //; s/ $//'; }

# ---------- Host tools ----------
DOCKER_PRESENT="absent"
if command -v docker >/dev/null 2>&1; then
  DOCKER_PRESENT="$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'present but not responding')"
fi

KUBECTL_PRESENT="absent"
if command -v kubectl >/dev/null 2>&1; then
  KUBECTL_PRESENT="$(kubectl version --client -o json 2>/dev/null \
    | python3 -c 'import json,sys;print(json.load(sys.stdin)["clientVersion"]["gitVersion"])' 2>/dev/null \
    || echo 'present but not responding')"
fi

MINIKUBE_PRESENT="absent"
MINIKUBE_RUNNING="no"
if command -v minikube >/dev/null 2>&1; then
  # `minikube version --short` isn't supported on older versions; fold any
  # newlines to spaces so the result is one line and safe for JSON.
  MINIKUBE_PRESENT="$(minikube version 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g')"
  if minikube status --format='{{.Host}}' 2>/dev/null | grep -q Running; then
    MINIKUBE_RUNNING="yes (driver=$(minikube status --format='{{.Driver}}' 2>/dev/null))"
  fi
fi

MVN_PRESENT="absent"
if command -v mvn >/dev/null 2>&1; then
  MVN_PRESENT="$(mvn -v 2>/dev/null | head -1 | awk '{print $3}' | clean)"
fi

GIT_PRESENT="absent"
if command -v git >/dev/null 2>&1; then
  GIT_PRESENT="$(git --version | awk '{print $3}')"
fi

# ---------- Jenkins container ----------
JENKINS_PRESENT="absent"
JENKINS_URL_OK="no"
JENKINS_PLUGIN_COUNT=""
JENKINS_CRED_IDS=""
if docker ps -a --filter "name=jenkins" --format '{{.Names}}' 2>/dev/null | grep -q '^jenkins$'; then
  STATUS=$(docker ps --filter "name=jenkins" --format '{{.Status}}' 2>/dev/null | clean)
  IMAGE=$(docker ps --filter "name=jenkins" --format '{{.Image}}' 2>/dev/null | clean)
  JENKINS_PRESENT="present ($STATUS, image=$IMAGE)"
  if curl -sf -o /dev/null --connect-timeout 2 http://localhost:8080/login 2>/dev/null; then
    JENKINS_URL_OK="yes (http://localhost:8080)"
    if [[ -n "${JENKINS_USER:-}" && -n "${JENKINS_TOKEN:-}" ]]; then
      auth=$(printf '%s:%s' "$JENKINS_USER" "$JENKINS_TOKEN" | base64)
      JENKINS_PLUGIN_COUNT=$(curl -sf -H "Authorization: Basic $auth" \
        "http://localhost:8080/pluginManager/api/json?depth=1" 2>/dev/null \
        | python3 -c 'import json,sys;d=json.load(sys.stdin);print(sum(1 for p in d["plugins"] if p.get("active")))' 2>/dev/null \
        || echo '?')
      JENKINS_CRED_IDS=$(curl -sf -H "Authorization: Basic $auth" \
        "http://localhost:8080/credentials/api/json?depth=4" 2>/dev/null \
        | python3 -c '
import json,sys
d=json.load(sys.stdin)
ids=[]
for s in d["stores"].values():
    for dom in s["domains"].values():
        for c in (dom.get("credentials") or []):
            ids.append(c["id"])
print(",".join(sorted(set(ids))))' 2>/dev/null \
        || echo '?')
    else
      JENKINS_PLUGIN_COUNT="(set JENKINS_USER+JENKINS_TOKEN to query)"
      JENKINS_CRED_IDS="(set JENKINS_USER+JENKINS_TOKEN to query)"
    fi
  fi
fi

# ---------- Output ----------
if [[ $JSON -eq 1 ]]; then
  cat <<EOF
{
  "host": {
    "docker":   "$DOCKER_PRESENT",
    "kubectl":  "$KUBECTL_PRESENT",
    "minikube": "$MINIKUBE_PRESENT",
    "minikube_running": "$MINIKUBE_RUNNING",
    "mvn":      "$MVN_PRESENT",
    "git":      "$GIT_PRESENT"
  },
  "jenkins": {
    "container":  "$JENKINS_PRESENT",
    "http":       "$JENKINS_URL_OK",
    "plugins":    "$JENKINS_PLUGIN_COUNT",
    "credentials":"$JENKINS_CRED_IDS"
  }
}
EOF
else
  echo "=== Host tools ==="
  printf "  %-15s %s\n" "docker"   "$DOCKER_PRESENT"
  printf "  %-15s %s\n" "kubectl"  "$KUBECTL_PRESENT"
  printf "  %-15s %s\n" "minikube" "$MINIKUBE_PRESENT"
  printf "  %-15s %s\n" ""         "  running: $MINIKUBE_RUNNING"
  printf "  %-15s %s\n" "mvn"      "$MVN_PRESENT"
  printf "  %-15s %s\n" "git"      "$GIT_PRESENT"
  echo
  echo "=== Jenkins container ==="
  printf "  %-15s %s\n" "container"  "$JENKINS_PRESENT"
  printf "  %-15s %s\n" "http"       "$JENKINS_URL_OK"
  printf "  %-15s %s\n" "plugins"    "$JENKINS_PLUGIN_COUNT"
  printf "  %-15s %s\n" "credentials" "$JENKINS_CRED_IDS"
fi
