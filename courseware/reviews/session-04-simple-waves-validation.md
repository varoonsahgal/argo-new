# Integration and verification notes

This is a proposed replacement activity for Session 4 Module 1.5. The helper is included under courseware/environment/lab-files/session-04/sync-waves-simple; bootstrap-vm.sh already copies the entire lab-files tree into the VM course directory. Existing installations must refresh that folder before following the updated guide.

- The original guide and its two teammate-change manifests were read through the GitHub connection on 2026-09-15, from varoonsahgal/argo-new main at commit e1b374cdd21fba1eab40ea4fead298797c6eead3.
- The Job and ConfigMap retain the original resource names, dependency, image, command, and starting waves. The package renames their files for readability.
- The former eight-resource baseline is removed. This isolates one lesson: a later-wave ConfigMap blocks an earlier-wave Job.
- The helper creates a branch and uniquely named Application/source folder/namespace for each run. It requires permission to push practice branches to the existing Gitea repository. The cloned branch inherits main, but the Application reads only its new two-file folder.
- The helper reads the client Git URL from ~/hello-reconcile, supporting existing Mac URL configuration. SOURCE_REPO can override that checkout path. ARGO_REPO_URL can override the default internal Argo CD source URL.
- The helper checks CLI access but is not a replacement for the shared session checkpoint. CP-lab-03 was inspected in courseware/environment/scripts/reset-lab.sh: it expects hello-reconcile healthy, storefront-dev present, storefront AppProject, and workload registration. It does not prepare this two-resource exercise.
- The canonical module path is unchanged. The session index is updated. SVG images live under courseware/assets/diagrams/session-04. No bootstrap/checkpoint script changes are needed.
- The previous sync-order-lab and teammate-change fixtures are retained for existing references. This module now uses only the isolated two-resource fixtures.
- Diagrams are authored explanatory images, not screenshots of a tested cluster. The repository uses the editable SVG images directly.
- Shell syntax, manifest parsing, image rendering, and an isolated helper test using real local Git plus mocked Kubernetes/Argo CD commands were checked. A live Argo CD end-to-end run remains required before claiming the updated package is classroom-validated.
- The helper leaves remote branches and local checkouts after cleanup for inspection. These can be removed separately when no longer wanted.

Sources:

- https://github.com/varoonsahgal/argo-new/blob/main/courseware/day-1/session-04/01b-sync-order-phases-waves-kinds-names.md
- https://github.com/varoonsahgal/argo-new/tree/main/courseware/environment/lab-files/session-04/teammate-change
- https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/
