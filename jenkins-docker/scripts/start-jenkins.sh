#!/usr/bin/env bash
# Start (or recreate) a Jenkins Docker container with persistent storage,
# auto-restart, and host-side build-agent capabilities (docker socket,
# docker binary, kubectl, kubeconfig, minikube profile).
#
# Idempotent: if the named container already exists with the current host
# docker gid, it is left alone (just `docker start`). If it exists with a
# stale gid (e.g. host docker gid changed), it is removed and recreated.
# The --restart=always policy keeps it up across host reboots.
#
# The docker group gid is looked up at runtime via getent, so this script
# survives host gid changes.
#
# Usage:
#   start-jenkins.sh
#
# Override defaults by editing the variables below, or by exporting them
# in the calling shell.
set -euo pipefail

IMAGE="${IMAGE:-jenkins/jenkins:lts}"
NAME="${NAME:-jenkins}"
HOST_JENKINS_HOME="${HOST_JENKINS_HOME:-/home/$(id -un)/jenkins_home}"
HOST_KUBECTL="${HOST_KUBECTL:-/usr/local/bin/kubectl}"
HOST_KUBE="${HOST_KUBE:-$HOME/.kube}"
HOST_MINIKUBE="${HOST_MINIKUBE:-$HOME/.minikube}"
HOST_DOCKER_SOCK="${HOST_DOCKER_SOCK:-/var/run/docker.sock}"
HOST_DOCKER_BIN="${HOST_DOCKER_BIN:-/usr/bin/docker}"

DOCKER_GID="$(getent group docker | cut -d: -f3)"
if [ -z "$DOCKER_GID" ]; then
  echo "Error: 'docker' group not found on host" >&2
  exit 1
fi

RUN_ARGS=(
  -d
  --name "$NAME"
  --restart=always
  -p 8080:8080
  -p 50000:50000
  -v "$HOST_JENKINS_HOME":/var/jenkins_home
  -v "$HOST_DOCKER_SOCK":/var/run/docker.sock
  -v "$HOST_DOCKER_BIN":/usr/bin/docker
  -v "$HOST_KUBECTL":/usr/local/bin/kubectl:ro
  -v "$HOST_KUBE":/home/jenkins/.kube:ro
  -v "$HOST_MINIKUBE":/home/jenkins/.minikube:ro
  --group-add "$DOCKER_GID"
  "$IMAGE"
)

if docker inspect "$NAME" >/dev/null 2>&1; then
  CURRENT_GROUPS="$(docker inspect "$NAME" --format '{{range .HostConfig.GroupAdd}}{{.}} {{end}}')"
  if [[ " $CURRENT_GROUPS " == *" $DOCKER_GID "* ]]; then
    echo "Container '$NAME' already exists with docker group $DOCKER_GID. Ensuring it is running."
    docker start "$NAME" >/dev/null 2>&1 || true
    exit 0
  fi
  echo "Container '$NAME' exists but is missing docker group $DOCKER_GID. Recreating."
  docker rm -f "$NAME" >/dev/null
fi

echo "Starting '$NAME' (image=$IMAGE, docker gid=$DOCKER_GID) ..."
docker run "${RUN_ARGS[@]}"
echo "Done. Tail logs with: docker logs -f $NAME"
