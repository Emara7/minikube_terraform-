output "cluster_name" {
  description = "Provisioned cluster name."
  value       = module.minikube_cluster.cluster_name
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed."
  value       = try(module.platform_addons[0].argocd_namespace, null)
}

output "grafana_namespace" {
  description = "Namespace where Grafana and monitoring stack are installed."
  value       = try(module.platform_addons[0].monitoring_namespace, null)
}
