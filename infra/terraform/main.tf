module "minikube_cluster" {
  source = "./modules/minikube-cluster"

  cluster_name = var.cluster_name
  driver       = var.minikube_driver
  cpus         = var.minikube_cpus
  memory       = var.minikube_memory
}

module "platform_addons" {
  count  = var.enable_platform_addons ? 1 : 0
  source = "./modules/platform-addons"

  depends_on = [module.minikube_cluster]
}
