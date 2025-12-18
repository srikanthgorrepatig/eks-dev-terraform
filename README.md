# EKS Development Environment - Terraform

## 📝 Overview
Terraform configuration for provisioning an EKS (Elastic Kubernetes Service) cluster for development environment.

## ⚙️ Prerequisites
- Terraform ≥ 1.0
- AWS CLI configured
- kubectl installed

## 🚀 Usage
1. Clone the repository:
   ```bash
   git clone https://github.com/YOUR-USERNAME/eks-dev-terraform.git

   Initialize Terraform:
   terraform init
   Plan the deployment:
   terraform plan -var-file="dev.tfvars"
   Apply the configuration:
   terraform apply -var-file="dev.tfvars"

🔐 Security Notes
Never commit .tfstate files - they contain sensitive data

Use dev.tfvars for environment-specific variables (add to .gitignore)

Store secrets in AWS Secrets Manager or similar service

📂 File Descriptions
main.tf: Core EKS cluster and node group configuration

variables.tf: Input variables for customization

outputs.tf: Output values like cluster endpoint, kubeconfig

dev.tfvars: Development environment variables (not tracked in git)

Maintenance
To update the cluster:

terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
   
