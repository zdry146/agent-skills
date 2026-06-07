# Aliyun Container Registry (ACR) setup for Jenkins pipelines

## Detection (do this first)

Before creating anything, run the skill's detection script to see what's already in place:

```bash
JENKINS_USER=… JENKINS_TOKEN=… ./scripts/detect-env.sh
```

Look for the `credentials` line under "Jenkins container". If `aliyun-docker-login` is already listed, you can **skip this entire document** — the credential is already wired. If it's missing, the `setup-env.sh` wizard's "gap-fill" option will add it for you; this doc explains what's happening under the hood.

## What it is

Aliyun's managed Docker registry. The **personal edition** is free and is what the typical CI/CD pipeline on this skill uses. The agent `docker push`es built images here; minikube (or any k8s cluster) pulls from here on `kubectl apply`.

## Create the registry

1. Open https://cr.console.aliyun.com/
2. Pick a region (e.g. `cn-hangzhou`). Match the region to where minikube/your cluster runs to keep the pull path short.
3. **Namespaces** → create one (e.g. `example-docker-registry`). This becomes the second path segment in the image name.
4. **Instances** → create a **personal** registry instance in that region.
5. The registry endpoint looks like `crpi-<id>.cn-hangzhou.personal.cr.aliyuncs.com`. The `<id>` is shown in the instance details.

## Create access credentials

In the registry console → **访问凭证** (Access Credentials) → set a fixed password.

You'll get:
- **Username** — your aliyun account name (e.g. `your-username`).
- **Password** — the fixed password you just set (not your aliyun login password).

## Add the credential to Jenkins

**Manage Jenkins → Credentials → System → Global credentials → Add Credentials**:

| Field | Value |
|---|---|
| **Kind** | Username with password |
| **Username** | the aliyun username from the previous step |
| **Password** | the fixed registry password |
| **ID** | `aliyun-docker-login` (must match the pipeline's `credentials('aliyun-docker-login')` call) |
| **Description** | "Aliyun personal container registry" |

Why "Username with password" (not "Secret text")? A username/password credential binding exposes both as `${ID_USR}` and `${ID_PSW}`, which is what `docker login -u ... --password-stdin` needs. A Secret text gives you only the password.

## Use from a pipeline

```groovy
environment {
    ALIYUN_REGISTRY  = 'crpi-XXXXX.cn-hangzhou.personal.cr.aliyuncs.com'
    ALIYUN_NAMESPACE = 'example-docker-registry'
    ALIYUN_IMAGE     = 'myapp'
    FULL_IMAGE       = "${ALIYUN_REGISTRY}/${ALIYUN_NAMESPACE}/${ALIYUN_IMAGE}"
    ALIYUN_DOCKER_CREDS = credentials('aliyun-docker-login')
}
stage('Build & push image') {
    steps {
        sh '''
        set -euo pipefail
        echo "$ALIYUN_DOCKER_CREDS_PSW" | docker login \
            -u "$ALIYUN_DOCKER_CREDS_USR" --password-stdin "$ALIYUN_REGISTRY"
        docker build -t "$FULL_IMAGE:$BUILD_NUMBER" -t "$FULL_IMAGE:latest" .
        docker push "$FULL_IMAGE:$BUILD_NUMBER"
        docker push "$FULL_IMAGE:latest"
        '''
    }
}
```

The `credentials('id')` call in a declarative pipeline automatically:
- Exposes username as `${ID_USR}` and password as `${ID_PSW}`
- Masks the password in the console output

## Image naming convention

`crpi-<id>.<region>.personal.cr.aliyuncs.com/<namespace>/<image>:<tag>`

The same `<image>:<tag>` must appear in three places — `docker build`, `docker push`, and the k8s manifest's `image:` field. A mismatch is the most common `ImagePullBackOff` cause.

## Quick sanity check from the host

```bash
# log in
echo "$AL_PASS" | docker login crpi-XXXXX.cn-hangzhou.personal.cr.aliyuncs.com -u your-username --password-stdin

# push something tiny to confirm the credential works
docker pull hello-world
docker tag hello-world crpi-XXXXX.cn-hangzhou.personal.cr.aliyuncs.com/example-docker-registry/hello-world:test
docker push crpi-XXXXX.cn-hangzhou.personal.cr.aliyuncs.com/example-docker-registry/hello-world:test
```

If this works from the host, the same credential in Jenkins will work for the agent.

## Common mistakes

- **Using the wrong endpoint.** Public (`registry.cn-hangzhou.aliyuncs.com`) vs personal (`crpi-XXXXX.<region>.personal.cr.aliyuncs.com`) endpoints are different registries with different credentials. The `crpi-…personal.cr.aliyuncs.com` form is what the Jenkins credential unlocks.
- **Forgetting to enable internet/VPC access for the registry.** The default access policy is internal-only. The cluster needs to be able to reach the registry endpoint — toggle the access settings in the registry console if pulls time out.
- **Tag mismatch between push and the k8s manifest.** The `image:` field in the deployment must be the *full* path, not just the tag.
- **Storing the password in plaintext in the pipeline.** Use `credentials('id')`; the binding masks the value in console output automatically.
- **Region mismatch.** If the registry is in `cn-hangzhou` but minikube is in `cn-shanghai`, pulls cross regions and may be slow or blocked.
