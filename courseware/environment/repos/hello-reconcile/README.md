# hello-reconcile

The Lab 1 sample application. A single [podinfo](https://github.com/stefanprodan/podinfo)
web server whose displayed **message** and **color** come from a ConfigMap that
this Helm chart renders. Changing `chart/values.yaml` and pushing the commit is
how Lab 1 makes reconciliation observable: the new message appears in the app's
HTTP response once Argo CD syncs.

This repository is **public-read** in Gitea, so the Argo CD Application that
points at it needs no repository credentials. Lab 2 contrasts this with the
private `storefront-gitops` repository.

## Layout

```text
argocd/hello-reconcile-app.yaml   # the Argo CD Application (applied by bootstrap; read in Lab 1)
chart/                            # a minimal Helm chart
  Chart.yaml
  values.yaml
  templates/configmap.yaml        # message/color -> podinfo env vars
  templates/deployment.yaml       # podinfo 6.15.0, readiness probe on /readyz
  templates/service.yaml          # ClusterIP on port 9898
```
