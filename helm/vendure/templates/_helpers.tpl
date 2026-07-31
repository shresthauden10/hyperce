{{- define "vendure.labels" -}}
app.kubernetes.io/name: vendure-app
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/part-of: vendure
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "vendure.selectorLabels" -}}
app.kubernetes.io/name: vendure-app
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "vendure.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ .Values.serviceAccount.name | default "vendure-app" }}
{{- else -}}
default
{{- end -}}
{{- end }}