variable "argocd_namespace" {
  description = "Namespace for ArgoCD."
  type        = string
  default     = "argocd"
}

variable "monitoring_namespace" {
  description = "Namespace for observability components."
  type        = string
  default     = "monitoring"
}
