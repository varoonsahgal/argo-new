# storefront-gitops

The GitOps repository for the **storefront** application (Labs 2–4 and the
capstone). It holds one Helm chart plus per-environment values and generator
config for `dev`, `staging`, and `prod`.

This repository is **private** in Gitea. Argo CD reads it through a repository
Secret that Lab 2 creates from a template (the password is injected from a
credential file that is never committed).

## Layout

```text
charts/storefront/        # the Helm chart Argo CD renders with `helm template`
  Chart.yaml
  values.yaml             # safe defaults; every env overrides image.tag, ui.*, namespace
  templates/
    _helpers.tpl
    configmap.yaml        # sync-wave "-1" (created before the Deployment)
    migration-job.yaml    # PreSync hook (runs before the Sync phase)
    deployment.yaml       # sync-wave "0"; image.tag is REQUIRED (fails render if blank)
    service.yaml          # sync-wave "0"
    hpa.yaml              # only rendered when hpa.enabled is true
envs/
  dev/values.yaml     dev/config.yaml
  staging/values.yaml staging/config.yaml
  prod/values.yaml    prod/config.yaml     # config.yaml pins targetRevision to a Git tag
```

## Tags

- `storefront-1.0.0` — the current released version. `prod` is pinned to this tag
  so production never tracks a moving branch.

Releases are cut as Git tags, one per chart version. `git tag -l` lists every tag
this repository currently has.

## Chart rule (Helm 4)

This chart never uses `null` to delete a default, and has no nullable defaults.
Helm 4 (the version bundled in the Argo CD 3.5 repo-server) changed how `null`
is handled during rendering, so the sample charts avoid the pattern entirely.
