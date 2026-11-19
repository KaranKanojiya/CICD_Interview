# Setup on a Mac

```bash
brew install --cask temurin@21     # JDK 21 (Gradle's toolchain resolver can also download it)
brew install --cask docker         # Docker Desktop, needed for the Jenkins lab and image builds
brew install actionlint gh         # optional: lint workflows, GitHub CLI for releases
```

Check:

```bash
java -version                      # 21.x
docker info >/dev/null && echo docker ok
./gradlew test                     # 2 tests, no Docker needed
bash scripts/test-release-scripts.sh
actionlint                         # needs the repo to be a git repo
```

## Jenkins lab

Jenkins checks out the **committed** `main` branch of this folder (mounted read-only), so commit first.

```bash
./jenkins/up.sh                    # builds the image (plugins baked in), starts http://localhost:8081
./jenkins/run-pipeline.sh          # triggers cicd-demo and prints the result
./jenkins/down.sh                  # stop (add --wipe to delete builds and caches)
```

Login: `admin`, password in `jenkins/.admin-password` (generated, git-ignored) or whatever you exported as `JENKINS_ADMIN_PASSWORD`.

First build takes a few minutes: Gradle and Maven dependencies download inside the container. Later builds reuse the `jenkins_home` volume.

## Releasing for real on GitHub

```bash
git commit -m "feat: something users notice"
./scripts/release.sh --dry-run
./scripts/release.sh
git push origin main --follow-tags  # release.yml builds, publishes image + GitHub Release
```

Requirements on GitHub: Actions enabled; for GHCR the package becomes private by default on first push (change visibility in the package settings); `attestations` needs a public repo or a plan that supports them on private repos.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Plugin download stalls during `up.sh` | The mirror you were redirected to is slow; pin one from the list at `https://get.jenkins.io/plugins/git/` (any `.hpi` → "mirrors"), e.g. `JENKINS_UC_DOWNLOAD_URL=https://ftp.belnet.be/mirror/jenkins/plugins ./jenkins/up.sh`. Avoid `archives.jenkins.io`: complete but slow |
| Port 8081 in use | Change the host port in `jenkins/docker-compose.yml` and `location.url` in `casc.yaml` |
| Job fails at checkout with "not allowed" | `ALLOW_LOCAL_CHECKOUT` flag missing from `JAVA_OPTS`; recreate the container |
| `release.sh` says working tree not clean | Commit or stash first; it refuses to tag uncommitted state |
