# Lab 0 — Prepare Your VM for Lab 1

**Goal:** Build the course environment on your existing Ubuntu VM and confirm that `hello-reconcile` is ready for Lab 1.

**Planning allowance:** 20–30 minutes, with additional time if downloads or image pulls are slow. This is an estimate, not a measured completion time on the supplied VM.

Use **MATE Terminal inside the Linux remote desktop** for every command. Open web pages in **Firefox inside that same desktop**. Run each command block separately and check its result before continuing.

## 1. Understand what you will create

The setup script creates two Kubernetes clusters inside Docker on your existing VM. It also installs Argo CD, starts a local Gitea Git server, creates accounts and repositories, and deploys the sample application.

| Component | Purpose |
|---|---|
| `mgmt` cluster / `k3d-mgmt` context | Runs Argo CD and the Lab 1 application |
| `workload` cluster / `k3d-workload` context | Used in later labs |
| Argo CD | Reads the application configuration from Git and deploys it |
| Gitea | Stores your VM’s independent exercise repositories |
| `hello-reconcile` | Application used to observe reconciliation in Lab 1 |

No Terraform or new VM provisioning is required. Do not manually create the two clusters before running bootstrap; the script creates them with the networking and ports required by the course.

## 2. Check the VM

```bash
whoami
```

Expected account: `training`.

```bash
docker info
```

Expected: Docker client and server information, with no permission or connection error. An empty list from `docker ps` is normal before setup.

```bash
df -h /
free -h
```

Record the available disk space and memory. Setup downloads container images and stores Kubernetes data. If a command reports that the disk is full, stop and report it.

## 3. Check prerequisites

```bash
k3d version
```

The course requires k3d v5.9.0 or newer. If it is already installed at a suitable version, skip the k3d installation below.

Ensure the supporting packages are installed:

```bash
sudo apt-get update
```

```bash
sudo apt-get install -y curl git openssl ca-certificates tar gzip
```

If sudo asks for a password, use your VM account password. If administrator access is unavailable, ask the lab facilitator to arrange the prerequisite installation.

**Only if k3d is missing or needs updating:**

```bash
curl -fL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh -o /tmp/install-k3d.sh
```

After the download succeeds:

```bash
bash /tmp/install-k3d.sh
```

```bash
k3d version
```

You do not need to install Helm or the Argo CD CLI separately. Bootstrap downloads the course’s pinned kubectl, Helm, Argo CD CLI, and yq into your account’s course directory. Existing system installations can remain in place.

## 4. Download the course materials

Choose **one** of the following paths.

### A. If you have not cloned the repository

```bash
cd ~
git clone --branch argo-cd-course-build --single-branch https://github.com/varoonsahgal/argo-cd-material.git
cd ~/argo-cd-material
```

### B. If `~/argo-cd-material` already exists

```bash
cd ~/argo-cd-material
git status --short
```

If this prints changed files, stop before updating and have those changes reviewed. Do not discard them or force a reset. A local edit from an earlier setup attempt may overlap the updated chart.

If the working tree is clean:

```bash
git fetch origin
git switch argo-cd-course-build
git pull --ff-only origin argo-cd-course-build
```

### Confirm the branch and updated chart

```bash
git branch --show-current
git rev-parse --short HEAD
```

Expected branch: `argo-cd-course-build`. Record the commit ID for troubleshooting.

```bash
grep -n 'course.message:' courseware/environment/repos/hello-reconcile/chart/templates/deployment.yaml
```

Expected: a line containing:

```yaml
course.message: {{ .Values.message | quote }}
```

This annotation makes a message change trigger a Pod rollout. It is already included in the updated repository; no manual YAML edit is needed. If it is missing, stop and check that you downloaded the correct branch and latest changes.

## 5. Configure the course paths

The scripts’ default VM layout assumes a Linux account named `student`. Your VM uses `training`. The following settings use your actual home directory and the scripts’ supported `--local` mode.

Copy this entire block, including the final `EOF` line:

```bash
cat > ~/argo-lab-env.sh <<'EOF'
export COURSE_HOME="$HOME/.argocd-course"
export COURSE_TOOLS_DIR="$COURSE_HOME/bin"
export COURSE_USER_HOME="$HOME"
export COURSE_CRED_DIR="$HOME/course/credentials"
export COURSE_SECRET_DIR="$COURSE_HOME/secrets"
export PATH="$COURSE_TOOLS_DIR:$HOME/argo-cd-material/courseware/environment/scripts:$PATH"
EOF
```

Load the settings:

```bash
source ~/argo-lab-env.sh
```

**Run `source ~/argo-lab-env.sh` in every new terminal used for the course.** The file sets paths; it does not start or recreate the environment.

## 6. Build the environment

```bash
cd ~/argo-cd-material/courseware/environment/scripts
```

```bash
set -o pipefail
bash bootstrap-vm.sh --local 2>&1 | tee ~/argo-lab-bootstrap.log
```

Run bootstrap as your normal account, **without sudo**. Do not add `--rebuild`.

The command keeps running while it downloads tools and images, creates clusters, starts services, and seeds the repositories. Leave the terminal open and wait for completion. The log is also saved to `~/argo-lab-bootstrap.log`.

Successful completion includes:

```text
CP-baseline reached.
```

If bootstrap exits with an error, stop and inspect the final log lines:

```bash
tail -n 80 ~/argo-lab-bootstrap.log
```

Do not continue to Lab 1 until the failure is resolved. Bootstrap is not a routine “start the lab” command: rerunning it re-seeds the course repositories and can replace exercise changes.

## 7. Verify the starting state

```bash
kubectl --context k3d-mgmt get nodes
kubectl --context k3d-workload get nodes
```

Expected: nodes in both clusters show `Ready`.

```bash
kubectl --context k3d-mgmt -n argocd get pods
```

Expected: the long-running Argo CD components are running and ready, with no crash loops or image-pull errors.

```bash
argocd app get hello-reconcile
```

Expected: sync status `Synced` and health status `Healthy`. Bootstrap normally logs the CLI in automatically.

Run the course checkpoint verifier:

```bash
bash "$HOME/argo-cd-material/courseware/environment/scripts/reset-lab.sh" CP-lab-01 --verify-only --local
```

Expected: every verification row passes. The output may say `CP-baseline`; `CP-lab-01` is an alias for that checkpoint. The `--verify-only` option checks the environment without resetting it.

## 8. Open Argo CD and Gitea

Open Firefox **inside the VM desktop**. In that browser, `localhost` means the VM. In a browser on your own laptop, it means your laptop instead.

### Argo CD

Open [https://localhost:8443](https://localhost:8443).

Bootstrap already configures this port. Do not start an additional port-forward on port 8443.

The lab uses a self-signed HTTPS certificate. Accept the certificate exception for this local lab address if Firefox prompts you.

Display the password in your terminal:

```bash
cat ~/course/credentials/argocd-admin.txt
```

Sign in as `admin`. Confirm that the `hello-reconcile` application shows `Synced` and `Healthy`.

### Gitea

Open [http://localhost:3000](http://localhost:3000).

Display the password:

```bash
cat ~/course/credentials/gitea-student.txt
```

Sign in as `student`. The account was created automatically; no external registration is needed.

| Account | Username |
|---|---|
| Linux VM | `training` |
| Argo CD | `admin` |
| Local Gitea server | `student` |

Keep passwords private; do not include them in screenshots or troubleshooting messages.

## 9. Confirm Git access

```bash
git ls-remote http://lab-gitea:3000/course/hello-reconcile.git
```

Expected: commit hashes and branch/tag names. Read access does not require credentials. Bootstrap configures Git to rewrite this URL to localhost for commands on your VM; Argo CD resolves the Git server through the cluster’s DNS configuration.

Leave cloning the exercise repository and changing its message for Lab 1. The source repository at `~/argo-cd-material` contains course materials; the repository you edit during Lab 1 is a separate clone from Gitea.

## 10. Ready for Lab 1

Before proceeding, confirm:

- Both Kubernetes clusters have ready nodes.
- The baseline verifier passes every check.
- Argo CD opens in Firefox and displays `hello-reconcile` as `Synced`/`Healthy`.
- Gitea opens and accepts your login.
- `git ls-remote` succeeds.

When following Lab 1:

- Use VM terminal windows wherever the guide says “SSH session.”
- Load `source ~/argo-lab-env.sh` in each terminal.
- Include `--local` in course reset/verification commands. Use `bash` and the script’s full path as demonstrated above if needed.
- Expect a message change to affect both the ConfigMap and the Deployment annotation in the Argo CD diff.

**If the environment was already bootstrapped before the chart update:** pulling the course repository does not update the existing Gitea repository or its saved baseline. Stop and have the baseline refreshed before beginning the exercise; do not assume the downloaded correction is already deployed.

## Troubleshooting

| Symptom | Next action |
|---|---|
| Pasted command starts with `^[[200~` or ends in an extra `~` | Press Ctrl+C and type the command manually. |
| `docker info` reports permission denied | Ask for Docker access for the `training` account. |
| Download returns HTTP 404 | Record the exact download URL and version from the log; report it. Do not silently substitute versions. |
| Download times out | Check VM internet access and report the failing host. |
| `argocd` or `kubectl` not found in a new terminal | Run `source ~/argo-lab-env.sh`. |
| Argo CD CLI reports an authentication error | Run `argocd login localhost:8443 --username admin --insecure` and enter the password from the credentials file. |
| Firefox cannot reach port 8443 | Confirm Firefox is inside the VM, bootstrap succeeded, and the Argo CD Pods are ready. |
| Port already allocated during bootstrap | Run `docker ps` and `ss -ltn`; report the conflict instead of removing unfamiliar containers. |
| Pod has `ImagePullBackOff` | Run `kubectl --context k3d-mgmt -n argocd get events --sort-by=.metadata.creationTimestamp` and report the image error. |

## Reference

Based on the [course environment](https://github.com/varoonsahgal/argo-cd-material/tree/argo-cd-course-build/courseware/environment), including `bootstrap-vm.sh`, `scripts/lib/common.sh`, and `reset-lab.sh`. Repository update reviewed: `21a3fc8`, including the updated Deployment annotation. This handout is based on script inspection; installation timing and end-to-end execution on the provider VM still require rehearsal.
