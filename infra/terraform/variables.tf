variable "cluster_name" {
  description = "Name of the local Minikube cluster."
  type        = string
  default     = "cloud-native-demo"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig used by Terraform providers."
  type        = string
  default     = null
}

variable "kube_context" {
  description = "Kubernetes context for the target cluster."
  type        = string
  default     = "cloud-native-demo"
}

variable "minikube_driver" {
  description = "Minikube driver, for example docker, qemu, or hyperkit."
  type        = string
  default     = "docker"
}

variable "minikube_cpus" {
  description = "CPU count for Minikube."
  type        = number
  default     = 4
}

variable "minikube_memory" {
  description = "Memory allocated to Minikube."
  type        = string
  default     = "6144mb"
}

variable "enable_platform_addons" {
  description = "Install ArgoCD, Grafana, Prometheus, Loki, and Promtail."
  type        = bool
  default     = true
}
