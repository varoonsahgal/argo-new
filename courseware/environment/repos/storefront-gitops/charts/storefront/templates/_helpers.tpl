{{/*
Common helpers for the storefront chart. Kept intentionally small.
*/}}

{{- define "storefront.name" -}}
storefront
{{- end -}}

{{- define "storefront.labels" -}}
app.kubernetes.io/name: storefront
app.kubernetes.io/managed-by: argocd
{{- end -}}

{{- define "storefront.selectorLabels" -}}
app.kubernetes.io/name: storefront
{{- end -}}
