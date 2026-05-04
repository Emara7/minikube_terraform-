resource "terraform_data" "cluster" {
  input = {
    cluster_name = var.cluster_name
    driver       = var.driver
    cpus         = var.cpus
    memory       = var.memory
  }

  provisioner "local-exec" {
    command = <<-EOT
      minikube start \
        --profile='${var.cluster_name}' \
        --driver='${var.driver}' \
        --cpus='${var.cpus}' \
        --memory='${var.memory}' \
        --addons=ingress,metrics-server
      kubectl config use-context '${var.cluster_name}'
    EOT
  }
}
