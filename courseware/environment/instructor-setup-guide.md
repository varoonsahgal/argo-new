# Instructor setup guide — Intermediate Argo CD Operations

This guide walks you, the instructor, through provisioning the lab fleet for a
cohort, distributing access, validating the environment before class, estimating
cost, and tearing everything down afterward. It assumes **no prior Terraform or
cloud experience** and explains each term the first time it appears.

> **Safety first (read this).** The automation in this repository **never**
> creates, changes, or destroys real cloud infrastructure on its own. Every
> `terraform apply` and `terraform destroy` in this guide is an action **you**
> run deliberately, after reading what it will do. The default configuration
> uses a "null" compute adapter that provisions *nothing* — it only renders
> files locally — so you can practice the whole workflow at zero cost and zero
> risk before you ever touch a cloud account.

---

## 1. What you are building

Each participant gets **one Linux virtual machine (VM)** — a computer you rent
from a cloud provider by the hour. On that VM, a bootstrap script builds two
small Kubernetes clusters and installs Argo CD, Gitea (a self-hosted Git
service), and the sample applications the labs use.

- **Management cluster** (`k3d-mgmt`): runs Argo CD.
- **Workload cluster** (`k3d-workload`): where applications get deployed.

Both clusters run inside the single VM using **k3d** (k3d runs lightweight
Kubernetes clusters as Docker containers). One VM, two clusters.

### 1.1 How the lab maps to a real production platform (§8.3)

The lab uses two small local clusters to stand in for a real, separated
production topology. Explain this mapping to students so they understand what
they are practicing for:

| In the lab (one VM) | In production (Rancher/RKE2) |
|---|---|
| `k3d-mgmt` cluster running Argo CD | A Rancher-managed **RKE2 management cluster** that hosts Argo CD |
| `k3d-workload` cluster | A separately registered **RKE2 downstream workload cluster** |
| Pre-created workload namespaces (`storefront-dev`, `team-a`, …) | Namespaces owned by **Rancher Projects** |
| The `lab-gitea` container | The organization's real **Git service** (GitHub, GitLab, Bitbucket, …) |

The lab deliberately keeps Gitea *outside* both clusters, exactly as production
Git lives outside Argo CD's cluster — so the Session 7 "we lost the management
cluster" recovery story is realistic.

### 1.2 The instructor/reference VM

By default you also get **one larger instructor VM** (`instructor_vm_enabled = true`).
It runs everything a student VM runs, plus an extra `ha-demo` cluster used for
the high-availability demonstration in guide `03`. Keep it enabled unless you
have a specific reason not to.

---

## 2. Prerequisites

### 2.1 On your own laptop (the "control machine")

Install these command-line tools. The versions below are the ones this course
was built and verified against on 2026-09-10.

| Tool | Minimum version | What it is | Install |
|---|---|---|---|
| Terraform | **>= 1.12** (built with 1.12.2) | Defines and creates infrastructure from text files | https://developer.hashicorp.com/terraform/install |
| `jq` | any recent | Reads JSON from the command line (used to extract SSH keys) | `brew install jq` / `apt install jq` |
| An SSH client | any recent | Connects to the VMs | Preinstalled on macOS/Linux |

Verify Terraform is installed:

```bash
terraform version
```

Expected output (your patch number may be newer):

```text
Terraform v1.12.2
on darwin_arm64
```

### 2.2 A cloud account with quota

You need an account with **one** cloud provider (AWS, Azure, Google Cloud,
Hetzner, etc.) and enough **quota** (the provider's cap on how many resources
you may create) for your class size.

For a class of `N` students with the instructor VM enabled, you provision
`N + 1` VMs. Each student VM needs **4 vCPU / 16 GiB RAM / 60 GiB disk**; the
instructor VM needs **8 vCPU / 32 GiB RAM / 120 GiB disk** (blueprint §8.10).

> **Quota math example.** A class of 20 needs `20 × 4 = 80` student vCPUs plus
> `8` instructor vCPUs = **88 vCPUs** and roughly **352 GiB RAM**. New cloud
> accounts often default to a 32-vCPU regional limit — request a quota increase
> a few days before class.

### 2.3 The course payload location

Each VM fetches this repository and runs `bootstrap-vm.sh` from it during first
boot. Host this repository somewhere the VMs can `git clone` from (a private Git
server or a public mirror), and note the URL and branch/tag. You will set this
as `course_payload_ref` in section 4.

---

## 3. Understand the compute adapter (why `apply` is safe to learn)

The Terraform in `terraform/` is **provider-agnostic**: the root configuration
generates VM names, per-VM SSH keys, and each VM's first-boot script, then hands
them to a swappable **compute adapter** module. The adapter is the only piece
that talks to a specific cloud.

- **Default adapter: `modules/compute-null`.** Creates no real VMs. It writes
  each VM's rendered first-boot script, public key, and a fleet inventory to
  `terraform/.local-render/`. This lets you run `init`, `validate`, and `plan`
  — and even `apply` — with **no cloud credentials and no cost**.
- **To provision real VMs**, you add a cloud adapter that implements the same
  interface and change one line (`source = ...`) in `main.tf`. The exact
  interface is documented in
  [`terraform/modules/compute-adapter-contract.md`](terraform/modules/compute-adapter-contract.md).

You will first practice the workflow against the null adapter (sections 4-6),
then, when you are ready to provision, swap in your cloud adapter (section 7).

---

## 4. Configure your variables

Move into the Terraform directory and create your variables file from the
example:

```bash
cd courseware/environment/terraform
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` in a text editor and set these values.

| Variable | What to set it to |
|---|---|
| `student_count` | Number of students (1-20). |
| `instructor_vm_enabled` | Keep `true` unless you have a reason not to. |
| `allowed_ssh_cidrs` | **Required.** The network(s) allowed to SSH in. Use `["<your-office-or-home-IP>/32"]`. A `/32` means exactly one address. **Never** use `0.0.0.0/0` (that opens SSH to the whole internet). |
| `allowed_ui_cidrs` | Leave `[]` (recommended). Students reach the UI through an SSH tunnel, so no extra ports need opening. |
| `name_prefix` | A short label for this cohort, e.g. `argo-jan2027`. Every VM and tag gets this prefix so cleanup is easy. |
| `course_payload_ref` | The `git_url`, `git_ref`, and `subdir` where the VMs fetch this repository (section 2.3). |
| `tags` | Optional key/value labels for cost tracking, e.g. `{ owner = "you", cost-center = "training" }`. |

Find your own public IP for `allowed_ssh_cidrs` with:

```bash
curl -s https://checkip.amazonaws.com
```

### 4.1 The firewall this creates (least privilege)

The adapter contract requires every cloud adapter to open **only**:

- **TCP 22 (SSH)** from `allowed_ssh_cidrs`, and
- **TCP 8443 (Argo CD) and 3000 (Gitea)** from `allowed_ui_cidrs` *only if you
  set that list* — by default it is empty, so those ports stay closed and the
  SSH tunnel is the single way in.

Nothing else is opened inbound.

---

## 5. Initialize and preview (safe, no cloud calls)

### 5.1 `terraform init` — download the providers

`init` prepares the working directory and downloads the small helper providers
(null, local, tls, random). Run it with `-backend=false` so it does not try to
configure remote state:

```bash
terraform init -backend=false
```

Expected output ends with:

```text
Terraform has been successfully initialized!
```

### 5.2 `terraform validate` — check for mistakes

`validate` checks the configuration is internally consistent (no typos, all
types line up). It makes no cloud calls.

```bash
terraform validate
```

Expected output:

```text
Success! The configuration is valid.
```

### 5.3 `terraform plan` — preview what would happen

`plan` shows exactly what Terraform would create, without creating anything.

```bash
terraform plan
```

With the null adapter and `student_count = 6`, the summary line reads:

```text
Plan: 23 to add, 0 to change, 0 to destroy.
```

(That is one SSH key + one first-boot file + one public-key file per VM, plus
one inventory file per adapter call. No real infrastructure.)

Scroll up and confirm the `student_vms` output shows one entry per student with
a `tunnel_command`. This is the same command students will use.

---

## 6. Pre-class validation checklist (do this once, before the null → cloud swap)

Before you provision real VMs for a cohort, prove the environment builds
correctly by running the **local sandbox** on a machine with Docker. This uses
the exact same scripts the VMs run.

> This requires Docker (Docker Desktop on macOS, or Docker Engine on Linux).
> It builds the two clusters locally; it does **not** touch any cloud.

1. **Bootstrap the local sandbox** (installs pinned tools, builds both clusters,
   installs Argo CD, seeds repos, reaches `CP-baseline`):

   ```bash
   export COURSE_TOOLS_DIR="$HOME/.argocd-course/bin"
   cd courseware/environment/scripts
   ./bootstrap-vm.sh --local
   ```

   It ends with a **CP-baseline smoke test**. Look for `hello-reconcile
   Synced/Healthy`.

2. **Verify a checkpoint without changing anything:**

   ```bash
   ./reset-lab.sh CP-baseline --verify-only --local
   ```

   Expected: a PASS/FAIL table with every row **PASS**.

3. **List all checkpoints** (confirms the full ladder is present):

   ```bash
   ./reset-lab.sh --list
   ```

   Expected: `CP-baseline`, `CP-lab-02`, `CP-lab-03`, `CP-lab-04`, `CP-lab-05`,
   `CP-capstone`, `CP-capstone-restored`.

4. **Exercise the capstone fault machinery** (inject, verify, then revert every
   fault, and confirm you can return to a clean checkpoint):

   ```bash
   ./inject-capstone-faults.sh inject all --local
   ./inject-capstone-faults.sh verify all --local
   ./inject-capstone-faults.sh revert all --local
   ./reset-lab.sh CP-capstone --verify-only --local
   ```

   Expected: `inject`/`verify` report each fault present; after `revert all`
   the `CP-capstone` verify table is all **PASS**.

5. **Tear the local sandbox down** when finished:

   ```bash
   ./bootstrap-vm.sh --local --rebuild   # or delete the k3d clusters/Gitea
   ```

If any step fails, fix it in the sandbox before provisioning a cohort. The
recorded results of the most recent end-to-end runs live in
[`courseware/reviews/`](../reviews/) — one `lab-0N-validation-<date>.md`
report per lab, plus `solution-validation-2026-09-13.md` for the instructor
walkthroughs.

---

## 7. Provision real VMs (your deliberate action)

When the checklist passes and you are ready to spend money on real VMs:

1. **Add a cloud adapter.** Create `terraform/adapters/<your-cloud>/` that
   implements the interface in
   [`modules/compute-adapter-contract.md`](terraform/modules/compute-adapter-contract.md)
   (it must accept the same inputs and return the same `vms` output). Add your
   cloud's provider to `versions.tf` and configure its credentials the normal
   Terraform way (usually environment variables).

2. **Point the fleet at it.** In `main.tf`, change both module blocks'
   `source = "./modules/compute-null"` to `source = "./adapters/<your-cloud>"`.

3. **Re-initialize and preview** (now with cloud credentials in your shell):

   ```bash
   terraform init -backend=false
   terraform plan
   ```

   Read the plan carefully. Confirm it creates `N + 1` VMs and the expected
   firewall rules, and nothing unexpected.

4. **Apply — this is the step that spends money.** Only you run this, and only
   after reading the plan:

   ```bash
   terraform apply
   ```

   Terraform prints the plan again and waits for you to type `yes`. VMs boot,
   run cloud-init, clone the payload, and run `bootstrap-vm.sh`. First boot
   takes several minutes while the clusters build.

---

## 8. Distribute access to students

Each student needs two things: their VM's **public IP** and their **private SSH
key**. Terraform holds both.

Show the non-secret connection info (names, IPs, ready-to-copy tunnel commands):

```bash
terraform output student_vms
```

The private keys are marked **sensitive**, so Terraform never prints them by
accident. Render one `.pem` key file per student with this loop:

```bash
umask 077   # new files are readable only by you
terraform output -json student_private_keys \
  | jq -r 'to_entries[] | .key + "\t" + .value' \
  | while IFS=$'\t' read -r name key; do
      printf '%s' "$key" > "${name}.pem"
      chmod 600 "${name}.pem"
      echo "wrote ${name}.pem"
    done
```

Then give **each student, over a secure channel** (not a public chat):

- their VM's public IP (from `terraform output student_vms`),
- their `*.pem` key file, and
- their personal tunnel command, which looks like:

  ```bash
  ssh -i <name>.pem -L 8443:localhost:8443 -L 3000:localhost:3000 student@<public-ip>
  ```

The Argo CD **admin password** is generated **on each VM** during bootstrap and
is not held by Terraform. Students read it on their own VM with:

```bash
cat ~/course/credentials/argocd-admin.txt
```

Where the credentials live on every VM (from `terraform output credentials_location`):

- `/home/student/course/credentials/` — `argocd-admin.txt`, `gitea-student.txt`,
  `team-a-dev.txt` (mode `0600`).
- `/opt/course/secrets/gitea-teammate.txt` — root-only; used by fault injection.

Point students at the [student setup guide](student-setup-guide.md).

---

## 9. Cost estimate

VM pricing changes constantly and varies by provider and region, so treat the
figures below as a **worked example, not a quote** — always confirm current
on-demand prices with your provider's calculator.

Using representative on-demand prices for general-purpose VMs:

| VM | Shape | Example price/hour | Count (class of 20) |
|---|---|---|---|
| Student | 4 vCPU / 16 GiB | ~$0.20 | 20 |
| Instructor | 8 vCPU / 32 GiB | ~$0.40 | 1 |

**Example two-day cost**, assuming VMs run only during the ~16 delivery hours:

```text
students:   20 × $0.20/hr × 16 hr = $64
instructor:  1 × $0.40/hr × 16 hr = $6.40
disk (60-120 GiB SSD × 21, 2 days): ~$5-10
--------------------------------------------
approx total: ~$75-85
```

If you leave the VMs running 24/7 across a two-day course (~48 hours) instead,
multiply the compute figures by three (~$210).

**Cost controls (strongly recommended):**

- Provision **immediately before** class and destroy **immediately** after (section 11).
- Set a cloud **budget alert** for the cohort's `name_prefix` tag.
- Consider a provider **auto-shutdown** schedule or a reminder to stop VMs
  overnight between Day 1 and Day 2.

---

## 10. Reset between labs and between cohorts

### 10.1 Between labs (on each VM)

Each checkpoint is a known-good state. To return a VM to the start of a lab:

```bash
reset-lab.sh CP-lab-03 --yes
```

`reset-lab.sh` is idempotent, runs **offline** (everything it needs is vendored
on the VM), targets under three minutes, and prints a PASS/FAIL table at the end.
Use `--verify-only` to check state without changing it, and `--list` to see the
checkpoints.

### 10.2 Between cohorts

The cleanest reset between cohorts is a **full teardown and re-provision**:

1. `terraform destroy` the old cohort (section 11).
2. Update `student_count`, `name_prefix`, and `course_payload_ref` for the new
   cohort in `terraform.tfvars`.
3. `terraform apply` to provision fresh VMs.

If you must reuse VMs without re-provisioning, run a full rebuild on each VM
(this recreates both clusters and Gitea from vendored assets, offline):

```bash
bootstrap-vm.sh --rebuild
```

---

## 11. Teardown

When the course is over, destroy the fleet so it stops costing money. **You**
run this; automation never does.

```bash
cd courseware/environment/terraform
terraform destroy
```

Terraform lists everything it will delete and waits for you to type `yes`.

Afterward, confirm in your cloud provider's console that no VMs, disks, or
security groups tagged with your `name_prefix` remain, and delete the local
`*.pem` key files you distributed:

```bash
rm -f *.pem
```

---

## 12. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `terraform init` fails downloading providers | No internet, or a corporate proxy | Set `HTTPS_PROXY`, or run `init` from a network that can reach `registry.terraform.io` |
| `plan` errors: `allowed_ssh_cidrs must contain at least one CIDR` | You left `allowed_ssh_cidrs` empty | Set it to your admin IP as `["x.x.x.x/32"]` |
| `plan` errors: `student_count must be between 1 and 20` | Out-of-range student count | Set `student_count` to 1-20 |
| A student cannot SSH in | Their IP is not in `allowed_ssh_cidrs`, or wrong key/IP | Add their network to `allowed_ssh_cidrs` and `apply`; re-check the IP and `.pem` you sent |
| Browser cannot open `https://localhost:8443` | Tunnel not running, or a local port already in use | Re-run the tunnel command; if 8443 is taken, change the left-hand port, e.g. `-L 9443:localhost:8443` |
| A VM never becomes healthy | cloud-init/bootstrap failed | SSH in and read `/var/log/course-bootstrap.log`; re-run `bootstrap-vm.sh` |
| `hello-reconcile` is not Synced/Healthy after bootstrap | Argo CD still settling, or an image pull issue | Wait and re-run the smoke test; check `kubectl --context k3d-mgmt -n argocd get pods` |

---

## 13. Quick reference

```bash
# Validate (no cloud, no cost)
cd courseware/environment/terraform
terraform init -backend=false && terraform validate && terraform plan

# Provision (real VMs — your deliberate action, after swapping in a cloud adapter)
terraform apply

# Distribute access
terraform output student_vms
terraform output -json student_private_keys | jq ...   # section 8

# Reset a VM between labs
reset-lab.sh CP-lab-03 --yes

# Tear down
terraform destroy
```
