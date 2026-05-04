# EKS module extension point

This directory is intentionally reserved for the production EKS implementation. The rest of the repository is structured so the root Terraform can swap `modules/minikube-cluster` for this module while preserving the same platform add-ons and Helm/GitOps workflow.

Recommended production implementation:

- Use the community `terraform-aws-modules/eks/aws` module.
- Create private subnets across at least three availability zones.
- Enable IRSA, managed node groups, KMS secrets encryption, and cluster logging.
- Replace local Minikube context variables with remote state outputs for cluster endpoint, CA data, and auth token.
- Keep ArgoCD and observability installation in `modules/platform-addons` to avoid duplicating platform bootstrapping.
