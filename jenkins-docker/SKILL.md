---
name: jenkins-docker
description: Use when setting up, validating, or troubleshooting the end-to-end Jenkins + container-registry + Kubernetes environment for CI/CD pipelines that build a Maven Java project, build a Docker image, and deploy to a local cluster. Detects what is already installed on the host and inside Jenkins, prompts before overriding existing state, and lines up Jenkins plugins, credentials, minikube, and a container registry into a working E2E chain. Replaces the basic `docker run jenkins` recipe with an idempotent, gid-aware approach.
---

# Jenkins Docker (E2E setup, with detection)

## What this skill does

A working E2E Jenkins pipeline for a Java project needs four pieces wired together:

1. **Jenkins container** with the right plugins and credentials
2. **minikube** (or another k8s cluster) as the deploy target
3. **Container registry** (aliyun ACR, GHCR, DockerHub) for the built image
4. **Agent wiring** — `~/.kube` and `~/.minikube` mounted so `kubectl` inside the container works

Installing any one of them is well-documented. The hard part is making sure all four are present, version-compatible, and using the same credentials. This skill does that as a guided setup: **detect → prompt → apply → verify**. It does not blindly install on top of a working setup.

## Workflow

```
1. scripts/detect-env.sh         →  inventory of what's already on this host
                                     (and inside Jenkins, if JENKINS_USER/TOKEN set)
2. scripts/setup-env.sh          →  per-component prompt: reuse / gap-fill / override / skip
3. scripts/verify-e2e.sh         →  post-setup smoke test: agent has docker+kubectl,
                                     Jenkins has plugins+creds, agent reaches minikube
```

Always run `detect-env.sh` first. Then `setup-env.sh` walks through each component interactively, asking what to do for each. `verify-e2e.sh` prints ✓/✗ for every leg of the chain.

For one-time ops like "just start the Jenkins container", use `scripts/start-jenkins.sh` directly — it's the idempotent, gid-aware `docker run` recipe that the rest of the skill assumes.

## Detection: `scripts/detect-env.sh`

Safe, read-only inventory script. Reports:

- **Host tools**: `docker`, `kubectl`, `minikube` (with running state), `mvn`, `git`
- **Jenkins container**: presence, http reachability, active plugin count, configured credential IDs

Pass `--json` for machine-readable output (used by `setup-env.sh` and agents that want to act on the inventory programmatically).

```bash
./scripts/detect-env.sh            # human-readable table
JENKINS_USER=… JENKINS_TOKEN=… \
  ./scripts/detect-env.sh --json   # includes plugin + credential inventory
```

If `JENKINS_USER` / `JENKINS_TOKEN` are not set, the plugin and credential lines will read `(set JENKINS_USER+JENKINS_TOKEN to query)`. Setting them unlocks the gap-fill and override options in `setup-env.sh`.

## Setup: `scripts/setup-env.sh`

Walks through each component (docker, kubectl, minikube, mvn, Jenkins) and prompts:

| Choice | Meaning |
|---|---|
| `r` | **Reuse** as-is (skip — already good) |
| `g` | **Gap-fill** (add only what's missing — e.g. install the plugins you don't have, create the credentials that aren't there). Existing jobs, builds, and credentials are **not** touched. |
| `o` | **Override** — recreate from scratch. **Destructive.** Requires typing `YES` to confirm. Loses all existing Jenkins jobs, builds, and credentials. |
| `s` | **Skip** (do nothing) |

Gap-fill is the default for "I have a Jenkins already, just add what I'm missing". It compares the current plugin set and credential IDs against the skill's required baseline and installs/creates only the deltas. Override is the right answer when a Jenkins instance is so stale or mis-configured that rebuilding it is faster than patching it.

After the prompts, the script re-runs detection and prints the new state.

## Verification: `scripts/verify-e2e.sh`

Read-only smoke test. Confirms the chain is actually wired:

- Host has docker / kubectl / minikube / mvn / git
- minikube is running
- Jenkins container is present and `http://localhost:8080` is up
- Required plugins are installed (`git`, `workflow-aggregator`, `credentials`, `credentials-binding`, `docker-workflow`, `pipeline-model-definition`)
- Required credentials are configured (`git-cred`, `aliyun-docker-login`)
- The agent inside the container has `docker` and `kubectl` in its PATH
- The agent's `kubectl` can reach the minikube cluster

Exits 0 if all checks pass, non-zero otherwise. Use it as the gate before declaring the env "ready for a pipeline run".

## Reference docs

Step-by-step setup for the two surrounding pieces. Each starts with a "Detection" step that flows into `setup-env.sh`:

- [`references/aliyun-acr-setup.md`](references/aliyun-acr-setup.md) — create an Aliyun Container Registry, generate access credentials, wire them into Jenkins as `aliyun-docker-login`, and call them from a pipeline.
- [`references/minikube-setup.md`](references/minikube-setup.md) — install minikube, start it on the host, and mount `~/.minikube` + `~/.kube` into the Jenkins container so `kubectl` inside the agent talks to the same cluster the host sees.

## Why not just `docker run jenkins`?

Most snippets break in three ways on a real project:

1. **Hardcoded docker gid** — fails the moment the host's docker gid changes (re-install, group reorder, host rebuild).
2. **No socket/binary binds** — agent can't `docker build/push`; CI/CD pipelines fail at the first `docker` step.
3. **Not idempotent** — re-running the recipe silently creates duplicate containers, or fails outright.

`scripts/start-jenkins.sh` (used by `setup-env.sh`) handles all three. See its header comments for the gid-resolution and idempotency contract.

## Useful commands

```bash
docker logs -f jenkins                                          # Watch startup
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword  # First-run password
docker exec -u root jenkins bash                                # Debug as root inside

./scripts/detect-env.sh                                         # What's installed
JENKINS_USER=… JENKINS_TOKEN=… ./scripts/detect-env.sh --json   # Same, with Jenkins internals
./scripts/setup-env.sh                                          # Interactive setup
./scripts/verify-e2e.sh                                         # Smoke test
JENKINS_USER=… JENKINS_TOKEN=… ./scripts/verify-e2e.sh          # Smoke test with credential checks
```

## Common mistakes

- **Skipping detection.** Installing on top of a stale Jenkins wastes time and can clobber state. Always `detect-env.sh` first.
- **Choosing "override" reflexively.** It destroys every job, build, and credential. Use "gap-fill" unless the instance is genuinely broken.
- **Hardcoding the docker gid.** If the host's docker gid changes, the container loses socket access. `start-jenkins.sh` looks it up at runtime.
- **Mounting only the docker socket, not the binary.** Socket present, no CLI → "permission denied" or "executable file not found". Bind both.
- **Mounting `$HOME/.kube` writable.** A careless agent step can clobber your kubeconfig. Use `:ro`.
- **Forgetting to set `JENKINS_USER` + `JENKINS_TOKEN` before setup-env.sh.** Without them, the wizard can't query or create Jenkins credentials and the gap-fill option is unavailable.
- **Treating verify-e2e.sh as optional.** It catches the most common "I forgot to mount X" or "I never added credential Y" mistakes before a 5-minute pipeline build fails.
