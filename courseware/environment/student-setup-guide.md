# Student setup guide — Intermediate Argo CD Operations

Welcome. Before Day 1 you need to connect to your lab virtual machine (VM), open
the Argo CD web interface, and run one quick check that everything is healthy.
This guide walks through every step and assumes you have only ever used a
terminal and a web browser. Follow it top to bottom; it takes about ten minutes.

Some quick definitions, so nothing is a surprise:

- **VM (virtual machine):** a remote Linux computer your instructor created for
  you. You connect to it with SSH.
- **SSH:** a secure way to log in to a remote computer from your terminal.
- **Argo CD:** the tool this course is about. It keeps applications running in
  Kubernetes in sync with what is stored in Git. You will use its web interface.
- **Gitea:** a small Git service running on your VM that holds the course's
  example repositories.

---

## 1. What your instructor gave you

You should have received three things over a secure channel:

1. Your VM's **public IP address**, e.g. `203.0.113.11`.
2. A **private key file**, e.g. `argocd-course-student-03.pem`.
3. Your personal **tunnel command** (also shown below).

If you are missing any of these, ask your instructor before continuing.

Move the key file somewhere you can find it, and lock down its permissions.
SSH refuses to use a key that other users could read.

```bash
# macOS/Linux: from the folder where you saved the key
chmod 600 argocd-course-student-03.pem
```

> **Windows users:** use Windows Subsystem for Linux (WSL), Git Bash, or
> PowerShell's built-in `ssh`. The commands below are the same. If `chmod` is
> unavailable, right-click the key file → Properties → Security and remove all
> users except yourself.

---

## 2. Connect with the SSH tunnel

You will connect using a **tunnel**. A tunnel is a normal SSH login that *also*
forwards two ports from the VM to your laptop, so you can open the VM's Argo CD
and Gitea web pages in your own browser as if they were running locally.

Run your personal tunnel command (substitute your key file name and IP):

```bash
ssh -i argocd-course-student-03.pem -L 8443:localhost:8443 -L 3000:localhost:3000 student@203.0.113.11
```

What each part means:

- `-i argocd-course-student-03.pem` — use your private key to log in.
- `-L 8443:localhost:8443` — forward the Argo CD web interface to your laptop.
- `-L 3000:localhost:3000` — forward the Gitea web interface to your laptop.
- `student@203.0.113.11` — log in as the `student` user on your VM.

The **first** time you connect, SSH asks whether to trust the VM:

```text
The authenticity of host '203.0.113.11' can't be established.
...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type `yes` and press Enter. You should land at a shell prompt on the VM:

```text
student@argocd-course-student-03:~$
```

**Keep this terminal open** for the whole lab session — the tunnel only works
while it is connected. To do other terminal work, open a *second* terminal (and,
if you like, SSH in again there without the `-L` options).

---

## 3. Find your Argo CD admin password

Your admin password was generated on your VM. Read it in the SSH session:

```bash
cat ~/course/credentials/argocd-admin.txt
```

It prints a random password on one line. Copy it — you will paste it in the next
step. (Your other credential files live in the same folder:
`gitea-student.txt` and `team-a-dev.txt`.)

---

## 4. Open the Argo CD web interface

With the tunnel still running, open this address in your browser:

```text
https://localhost:8443
```

### 4.1 Accept the self-signed certificate warning

Argo CD uses a **self-signed certificate** (a certificate it created itself
rather than buying from a public authority). Your browser cannot automatically
verify it, so it shows a warning. This is expected in the lab and is safe here
because you are only talking to your own VM through your own tunnel.

- **Chrome/Edge:** click **Advanced** → **Proceed to localhost (unsafe)**.
- **Firefox:** click **Advanced…** → **Accept the Risk and Continue**.
- **Safari:** click **Show Details** → **visit this website** → **Visit Website**.

### 4.2 Log in

At the Argo CD login page, enter:

- **Username:** `admin`
- **Password:** the value you copied from `argocd-admin.txt` in step 3.

Click **Sign In**. You should see the **Applications** list.

> **Screenshot — SS-ENV-01** *(capture pending live sandbox; see
> [`scripts/screenshots/screenshot-manifest.yaml`](scripts/screenshots/screenshot-manifest.yaml),
> ID `SS-ENV-01`).*
> **Shows:** the Applications list right after first login, at checkpoint
> `CP-baseline`. **Highlighted:** the `hello-reconcile` tile showing **Synced**
> and **Healthy**. **File:** `assets/screenshots/day-1/env-01-applications-baseline.png`.
> **What to notice:** exactly one Application, `hello-reconcile`, with a green
> **Synced** badge and a green **Healthy** badge. That is what "ready for Day 1"
> looks like.

### 4.3 (Optional) Look at the course repositories in Gitea

Open Gitea in your browser (through the same tunnel):

```text
http://localhost:3000
```

If prompted to log in, use username `student` and the password from
`~/course/credentials/gitea-student.txt`. Navigate to the `course` organization.

> **Screenshot — SS-ENV-02** *(capture pending live sandbox; see
> `screenshot-manifest.yaml`, ID `SS-ENV-02`).*
> **Shows:** the Gitea `course` organization repository list at `CP-baseline`.
> **Highlighted:** the **five** seeded repositories. **File:**
> `assets/screenshots/day-1/env-02-gitea-course-repos.png`.
> **What to notice:** five repositories — `hello-reconcile`, `storefront-gitops`,
> `platform-config`, `platform-components`, and `team-a-apps`.

---

## 5. Log in to the Argo CD command line

Some labs use the `argocd` command-line tool as well as the web interface. Log
in to it from your SSH session (the pinned `argocd` tool is already installed and
on your `PATH`):

```bash
argocd login localhost:8443 \
  --username admin \
  --password "$(cat ~/course/credentials/argocd-admin.txt)" \
  --insecure
```

- `--insecure` tells the CLI to accept the same self-signed certificate the
  browser warned about — expected in the lab.

Expected output:

```text
'admin:login' logged in successfully
Context 'localhost:8443' updated
```

---

## 6. Final smoke test — confirm you are ready for Day 1

Run these two checks in your SSH session. They confirm Argo CD's own components
are running and the course's first application is healthy.

**Check 1 — Argo CD's pods are running on the management cluster:**

```bash
kubectl --context k3d-mgmt -n argocd get pods
```

Expected: every pod shows `Running` and its containers **Ready** (the `READY`
column shows all containers ready, e.g. `1/1`). Names include the API/UI server,
the repo-server, the application controller, Redis, and the ApplicationSet and
notifications controllers:

```text
NAME                                  READY   STATUS    RESTARTS   AGE
argocd-application-controller-0       1/1     Running   0          9m
argocd-applicationset-controller-...  1/1     Running   0          9m
argocd-notifications-controller-...   1/1     Running   0          9m
argocd-redis-...                      1/1     Running   0          9m
argocd-repo-server-...                1/1     Running   0          9m
argocd-server-...                     1/1     Running   0          9m
```

(Exact suffixes and the number of rows vary; what matters is that all are
`Running` and Ready.)

**Check 2 — the first application is Synced and Healthy:**

```bash
argocd app list
```

Expected: a row for `hello-reconcile` whose status is `Synced` and `Healthy`:

```text
NAME                    CLUSTER                         NAMESPACE  ...  STATUS  HEALTH
argocd/hello-reconcile  https://kubernetes.default.svc  hello      ...  Synced  Healthy
```

If both checks look like the above, **you are ready for Day 1.** 🎉

---

## 7. What to do if something looks wrong

| What you see | What it usually means | What to do |
|---|---|---|
| `ssh: connect to host ... port 22: Operation timed out` | Your network is not allowed, or the IP is wrong | Double-check the IP; tell your instructor your public IP so they can allow it |
| `Permission denied (publickey)` | Wrong key file, or key permissions too open | Confirm you used the exact `.pem` your instructor sent; run `chmod 600 <key>.pem` |
| Browser: "This site can't be reached" at `https://localhost:8443` | The SSH tunnel is not running | Return to the tunnel terminal; if it closed, run the tunnel command again |
| `bind: Address already in use` when starting the tunnel | Port 8443 or 3000 is already used on your laptop | Change the left-hand port, e.g. `-L 9443:localhost:8443`, then open `https://localhost:9443` |
| Argo CD login fails | Wrong password | Re-copy it with `cat ~/course/credentials/argocd-admin.txt` (no extra spaces) |
| A pod is `Pending` or `CrashLoopBackOff`, or `hello-reconcile` is not Synced/Healthy | The VM may still be finishing first-boot setup | Wait 2-3 minutes and re-run the smoke test; if it persists, tell your instructor (they can check `/var/log/course-bootstrap.log`) |

When you are set up, open the course welcome guide and agenda,
`day-1/00-welcome-and-agenda.md`, then work through the hands-on refresher in
`day-1/refresher/README.md`, and you are on your way.
