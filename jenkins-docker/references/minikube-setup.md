# Minikube setup for Jenkins pipeline deploys

## What it is

A single-node Kubernetes cluster running in a Docker container (or VM) on your host. For local CI/CD, it's the typical "deploy target" — the agent runs `kubectl apply` against it the same way it would against a real cluster.

## Install

Pick one:

```bash
# Linux (direct download)
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# macOS
brew install minikube
```

Verify:

```bash
minikube version
```

You'll also need `kubectl`. The `start-jenkins.sh` script in this skill mounts the host's kubectl binary into the container, so kubectl just needs to exist on the host.

## Start

The driver matters. For a CI/CD agent that needs to share the host's docker daemon, `--driver=docker` is the simplest and most reproducible:

```bash
minikube start --driver=docker
```

Other drivers (`kvm2`, `virtualbox`, `hyperkit`, `podman`) work too but need extra host setup. Don't use `--driver=none` on a multi-user host — it runs the kubelet directly on the host with no isolation.

Verify:

```bash
minikube status
kubectl get nodes      # should show the minikube node as Ready
```

## Give the Jenkins agent access

The agent runs inside the Jenkins Docker container, not on the host. To let `kubectl` inside the agent talk to the minikube cluster, mount the host's `~/.kube` and `~/.minikube` into the container. Both binds are already in `scripts/start-jenkins.sh`:

```bash
-v $HOST_KUBE:/home/jenkins/.kube:ro
-v $HOST_MINIKUBE:/home/jenkins/.minikube:ro
```

Inside the agent, `kubectl` resolves the default context the same way it does on the host — it points at minikube. No extra config needed.

Quick check from inside the container:

```bash
docker exec -u jenkins jenkins kubectl get nodes
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   1h    v1.31.0
```

## Two ways to ship the image into minikube

| Option | How | Trade-offs |
|---|---|---|
| **A. Push to a registry, minikube pulls** (recommended for shared clusters) | Pipeline `docker push`es to aliyun ACR; minikube pulls from there on pod start | Image is shareable across clusters; survives `minikube delete`; works with multiple agents |
| **B. Build inside minikube's docker daemon** | Pipeline runs `eval $(minikube docker-env) && docker build` | No registry needed; image is **lost on `minikube delete`**; minikube-only |

For the typical pipeline flow this skill supports (build → push to ACR → `kubectl apply`), use **Option A**. See `aliyun-acr-setup.md` for the registry side. The k8s manifest's `image:` field must be the full registry path so the kubelet can pull:

```yaml
spec:
  containers:
    - name: app
      image: crpi-XXXXX.cn-hangzhou.personal.cr.aliyuncs.com/mike-docker-registry/myapp:1.0.0
```

## Useful commands

```bash
minikube status
minikube start
minikube stop
minikube delete                # nukes everything; capture YAML first if you need it back
minikube dashboard             # opens the k8s web UI
minikube service <name> --url # port-forwards a service and prints the URL
minikube ssh                   # shell into the minikube node
minikube addons enable registry   # addons: registry, metrics-server, dashboard, ingress, …
```

## Common mistakes

- **Forgetting to mount `~/.minikube` and `~/.kube`.** The agent has `kubectl` but no kubeconfig → `kubectl get nodes` returns "connection refused" or "no context exists with the name minikube".
- **`minikube start` requires root or docker group membership.** Same constraint as `docker run`; the Jenkins container already gets `--group-add $(getent group docker | cut -d: -f3)` in `start-jenkins.sh`.
- **`minikube delete` wipes all workloads, secrets, and PVCs.** No confirmation prompt. If you want a clean state for re-tests, capture the YAML first or use a separate test namespace (`kubectl create ns test` and set `NAMESPACE=test` in the Jenkins job).
- **Using `latest` as the only tag in the manifest.** Combined with `imagePullPolicy: IfNotPresent` (the default), kubelet won't re-pull a renamed image. Either pin a version (`myapp:1.0.0`) or set `imagePullPolicy: Always` for the dev namespace.
- **Region/endpoint mismatch between ACR and minikube's network.** If ACR is on a private VPC and minikube is on a public host, the kubelet can't reach the registry endpoint. Toggle the registry's "internet access" in the aliyun console, or expose a local registry.
- **Running pipelines as the wrong user inside the agent.** If the manifest is owned by root but the agent runs as `jenkins`, `kubectl apply` reads it fine but `kubectl delete` later can fail. `chmod 644 k8s/*.yaml` in the repo.
