# Production-Oriented Configuration

> **This session is now delivered as a short, hands-on modular arc.**
>
> **→ Start here: [`session-03/README.md`](session-03/README.md)**

## The three modules

1. [Install model and high availability](session-03/01-install-model-and-ha.md) — multi-tenant vs Core, HA per component, "who deploys the deployer"; count what HA adds via `helm template`.
2. [Onboarding repositories and clusters](session-03/02-onboarding-repos-and-clusters.md) — the three labeled Secrets and the cluster-registration trust chain; read the onboarding Secrets.
3. [Least privilege and change detection](session-03/03-least-privilege-and-change-detection.md) — least *write* privilege, `respectRBAC`, webhooks vs polling; inspect the wide-open `default` project.

*(This replaces the previous single-file version of Session 3. All diagrams (V-10, V-11, V-12, V-13), the install checklist, screenshots, Quick Checks, and takeaways are preserved across the three modules above.)*
