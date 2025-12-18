output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.dev_app.repository_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "node_group_id" {
  description = "Node group ID"
  value       = try(module.eks.eks_managed_node_groups["dev-nodes"].id, "No node group (Karpenter enabled)")
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost"
  value       = "Approximately $20-50/month (with scheduled scaling)"
}

output "cost_saving_tips" {
  description = "Cost saving tips"
  value       = <<EOT
Cost Saving Features Enabled:
1. Spot Instances: ${var.enable_spot_instances}
2. Scheduled Scaling: ${var.enable_scheduled_scaling}
3. Weekend Shutdown: ${var.scale_to_zero_weekends}
4. Karpenter: ${var.enable_karpenter}

To save more:
- Run 'scripts/destroy.sh' when not using cluster
- Monitor costs in AWS Cost Explorer
EOT
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<EOT
Next Steps:
1. Configure kubectl: aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}
2. Deploy application: kubectl apply -f k8s/
3. Check cluster: kubectl get nodes
4. Get service: kubectl get svc -n ${var.app_namespace}
EOT
}