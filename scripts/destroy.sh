#!/bin/bash
set -e

echo "=== Destroying Dev EKS Cluster ==="

echo "Current monthly cost if left running: ~$135"
echo "Destroying will save approximately $20-50/month"

read -p "Are you sure you want to destroy the cluster? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# Destroy Kubernetes resources first
echo "Deleting Kubernetes resources..."
kubectl delete namespace ${var.app_namespace} --ignore-not-found=true || true

# Destroy Terraform resources
echo "Destroying Terraform resources..."
terraform destroy -var-file="dev.tfvars" -auto-approve

echo "=== Cluster Destroyed ==="
echo "Monthly cost savings: ~$20-50"
echo "To redeploy: ./scripts/deploy.sh"