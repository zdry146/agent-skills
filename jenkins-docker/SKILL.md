---
name: jenkins-docker
description: Use when installing, starting, or managing a Jenkins Docker container that needs to survive host reboots and host docker gid changes, persist state, or run docker/kubectl inside pipelines. Also covers the full E2E setup: aliyun ACR (or any private registry) for image push and minikube as the deploy target for a Maven Java project. Replaces the basic `docker run jenkins` recipe with an idempotent, gid-aware approach.
---

# Jenkins Docker (idempotent + build-agent capable)

## Why not just `docker run jenkins`?

Most snippets break in three ways on a real project:

1. **Hardcoded docker gid** — fails the moment the host's docker gid changes (re-install, group reorder, host rebuild).
2. **No socket/binary binds** — agent can't `docker build/push`; CI/CD pipelines fail at the first `docker` step.
3. **Not idempotent** — re-running the recipe silently creates duplicate containers, or fails outright.

This skill gives you a small, idempotent `start-jenkins.sh` pattern with the run-args that cover the common cases.

## Prerequisites

- Docker on the host
- A persistent host directory for `JENKINS_HOME` (e.g. `/home/<user>/jenkins_home`)
- Ports 8080 (UI) and 50000 (JNLP) free
- For build-agent capabilities: docker, kubectl, and (optionally) a kubeconfig + minikube profile installed on the host

## Run-args reference

| Flag | Why |
|---|---|
| `-v $HOST_JENKINS_HOME:/var/jenkins_home` | Persist plugins, jobs, secrets across container recreation |
| `-p 8080:8080 -p 50000:50000` | Web UI + JNLP agents |
| `--restart=always` | Survive host reboots |
| `--group-add $(getent group docker \| cut -d: -f3)` | Let the `jenkins` user in the container talk to the host docker socket — **look up at runtime** |
| `-v /var/run/docker.sock:/var/run/docker.sock` | (agent) docker-in-docker for builds |
| `-v /usr/bin/docker:/usr/bin/docker` | (agent) docker CLI binary |
| `-v /usr/local/bin/kubectl:/usr/local/bin/kubectl:ro` | (agent) kubectl for k8s deploys |
| `-v $HOME/.kube:/home/jenkins/.kube:ro` | (agent) kube context — read-only |
| `-v $HOME/.minikube:/home/jenkins/.minikube:ro` | (agent) minikube profile — read-only |

## Idempotency contract

1. Look up the host docker gid **at runtime** (`getent group docker | cut -d: -f3`), not at script-write time.
2. If the named container exists and its `HostConfig.GroupAdd` contains the current gid → `docker start` and exit.
3. If the container exists with a stale gid → `docker rm -f` and recreate.
4. If the container doesn't exist → create it.

Safe to re-run after a host reboot, a host docker gid change, or a manual `docker rm jenkins`.

## Script: `scripts/start-jenkins.sh`

A generalized, drop-in version. Override any of the `HOST_*` / `IMAGE` / `NAME` variables at the top of the file to match your project.

## After the container is up

A fresh Jenkins is blank. Before any pipeline can `credentials('...')`, run `docker build/push`, or check out a Git repo, install the plugin baseline and add the credential baseline below.

Install plugins via **Manage Jenkins → Plugins → Available plugins** (UI), or use the CLI the `lts` image ships at `/usr/bin/jenkins-plugin-cli --plugins <list>`. Reference credentials in pipelines with `credentials('id')` or via `withCredentials { ... }`.

### Plugin baseline

The minimum for a "checkout → build → push image → deploy to k8s" pipeline:

| Category | Plugins |
|---|---|
| **Pipeline core** | `pipeline-model-definition` (Declarative), `workflow-aggregator`, `workflow-cps`, `workflow-job`, `workflow-multibranch`, `workflow-scm-step` |
| **SCM** | `git`, `git-client`, `scm-api` |
| **Credentials** | `credentials`, `credentials-binding`, `plain-credentials`, `ssh-credentials` |
| **Scripting** | `script-security` (required for Groovy sandbox; pre-installed with the lts image) |
| **Docker** | `docker-workflow`, `docker-commons` (needed only if pipelines call `docker.build/push` or hit the docker socket directly) |
| **GitHub (optional)** | `github`, `github-api`, `github-branch-source`, `pipeline-github-lib` (only for GitHub repos + multibranch) |
| **UI** | `pipeline-graph-view`, `pipeline-stage-view`, `timestamper`, `ws-cleanup`, `dark-theme` |

A working instance typically resolves to **80–100 active plugins** once transitive dependencies are pulled in. The plugin list at http://`<host>`:8080 → `pluginManager/api/json?depth=1` is the ground truth.

### Credential baseline

Add via **Manage Jenkins → Credentials → System → Global credentials**.

| ID (recommended) | Type | Purpose |
|---|---|---|
| `git-cred` | Username with password | SCM checkout (GitHub / GitLab PAT-as-password) |
| `aliyun-docker-login` | Username with password | Push to a private container registry (Aliyun ACR, GHCR, DockerHub) — username and password are both exposed as `${VAR_USR}` / `${VAR_PSW}` for `docker login -u ... --password-stdin` |
| `db-password` | Secret text | Database password surfaced as `DB_PASSWORD` to the app |
| `<kubeconfig>` (optional) | Secret file | A kubeconfig YAML the agent can mount if `~/.kube` isn't enough |

> Why "Username with password" (not "Secret text") for the registry? `docker login` needs a username. A username/password credential binding exposes both, while a Secret text gives you only the password.

Quick check of what's actually configured:

```bash
curl -s -u "$USER:$TOKEN" "$JENKINS_URL/credentials/api/json?depth=4" | \
  python3 -c "import json,sys; d=json.load(sys.stdin); \
  [print(f\"{c['id']:30s} {c.get('typeName','?'):25s} {c.get('displayName','')}\") \
   for s in d['stores'].values() \
   for dom in s['domains'].values() \
   for c in (dom.get('credentials') or [])]"
```

## End-to-end environment setup

The Jenkins container is the middle of a chain. Two surrounding pieces complete the loop:

1. **Image registry** (Aliyun ACR, GHCR, DockerHub, …) — where the agent `docker push`es the built image.
2. **Kubernetes cluster** (minikube for local dev, or a real cluster) — the deploy target.

The pipeline shape this skill supports end-to-end:

```
GitHub repo
   │  (git-cred)
   ▼
Jenkins agent  ──  mvn -B clean verify           ← builds the Maven Java project
   │             mvn help:evaluate               ← reads project.version
   │             docker build + docker push      ← pushes to aliyun ACR
   │                                            (aliyun-docker-login credential)
   ▼
Aliyun Container Registry   crpi-XXX.cn-hangzhou.personal.cr.aliyuncs.com/<ns>/<image>:<tag>
   │  (kubectl set image / kubectl apply, kubelet pulls the image)
   ▼
Minikube (or any k8s cluster)
```

Once the three pieces (Jenkins + registry + cluster) are configured, the pipeline itself is just the standard "checkout → test → image → deploy" shape. The hard part is the environment plumbing, which is what the reference docs cover.

## Reference docs

Step-by-step setup for the two surrounding pieces:

- [`references/aliyun-acr-setup.md`](references/aliyun-acr-setup.md) — create an Aliyun Container Registry, generate access credentials, wire them into Jenkins as `aliyun-docker-login`, and call them from a pipeline.
- [`references/minikube-setup.md`](references/minikube-setup.md) — install minikube, start it on the host, and mount `~/.minikube` + `~/.kube` into the Jenkins container so `kubectl` inside the agent talks to the same cluster the host sees.

## Common mistakes

- **Hardcoding the docker gid.** If the host's docker gid changes, the container loses socket access. Use the runtime lookup.
- **Mounting only the socket, not the binary.** Socket present, no CLI → "permission denied" or "executable file not found". Bind both.
- **Mounting `$HOME/.kube` writable.** A careless agent step can clobber your kubeconfig. Use `:ro`.
- **Setting `--group-add 999` once and forgetting.** It goes stale; the idempotency check above catches it.
- **Re-running the snippet on every CI run.** Keep the script; let it decide start vs recreate.

## Useful commands

```bash
docker logs -f jenkins            # Watch startup
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword  # First-run password
docker exec -u root jenkins bash  # Debug as root inside
docker rm -f jenkins && start-jenkins.sh   # Full reset
```
