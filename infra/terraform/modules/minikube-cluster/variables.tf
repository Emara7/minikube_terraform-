variable "cluster_name" {
  description = "Name of the Minikube cluster/profile."
  type        = string
}

variable "driver" {
  description = "Minikube driver."
  type        = string
}

variable "cpus" {
  description = "CPU count."
  type        = number
}

variable "memory" {
  description = "Memory allocation."
  type        = string
}
