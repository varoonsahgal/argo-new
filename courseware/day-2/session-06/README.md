# Session 6 — Security, Multi-Tenancy, and Governance (modular arc)

> **Day 2 · Session 6 · Concept + hands-on · ~45 minutes**
> **Argo CD version this course targets: `v3.5.2`** (Helm chart `10.8.4`; repo-server renders with **Helm v4.2.1**).
> **Before this:** [Session 5](../session-05/README.md) and Lab 4. **Lab 5** builds a real fence around a new tenant and tries to walk through it; this session makes Lab 5's error messages readable.

Session 5 taught you to *scale* the deployment path — and leverage is exactly what makes governance urgent: the more an action can do, the more it matters *who* can take it and *what* it may touch. This session is about the fences that keep scale from becoming blast radius.

> **One promise up front:** there are **three** independent fences in Argo CD, and almost every "Argo CD security" question is really "which of the three fences is this?"

Delivered as **three short modules**, each with a live ▶ action:

| Module | You will understand... | Hands-on | ~Time |
|---|---|---|---|
| [01 — The three fences](01-the-three-fences.md) | The three fences, the one diagnostic question, and each fence's error signature | — | ~15 min |
| [02 — AppProjects and RBAC, up close](02-appprojects-and-rbac.md) | The real AppProject and RBAC policy, least privilege, the shared ServiceAccount | Unit-test an RBAC policy offline | ~18 min |
| [03 — SSO, secrets, and governance](03-sso-secrets-and-governance.md) | Group→role mapping, secret patterns, tokens, sync windows | Read the fences in the UI | ~12 min |

**→ Start:** [01 — The three fences](01-the-three-fences.md)
