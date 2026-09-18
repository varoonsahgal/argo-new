# platform-config

The **platform team's** repository (Labs 2–5 and the capstone). It holds:

- `argocd/values.yaml` — the Helm values for the Argo CD release itself, applied
  by the platform's `apply-argocd-config` wrapper.
- `clusters/` — cluster registration Secrets (the in-cluster one has labels only;
  the workload one is a `*.template.yaml` with placeholders, completed in Lab 2).
- `repositories/` — repository connection Secrets as `*.template.yaml` templates.
- `projects/` — AppProjects (tenant guardrails).
- `applications/` — individual Argo CD Applications.
- `applicationsets/` — ApplicationSet definitions.
- `root/` and `apps/` — the App-of-Apps root Application and its children.
- `examples/` — sample ApplicationSets used only for dry-run demonstrations.

Files that start as **skeletons with `TODO` markers** are completed by
participants during the labs. Nothing secret is ever committed here: repository
and cluster Secrets exist only as `*.template.yaml` files with placeholders
(`<TOKEN>`, `<CA_DATA>`, `<PASSWORD>`).
