#!/bin/bash
set -e

echo "=== Deploying Dev EKS Cluster ==="

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Apply configuration
echo "Applying Terraform configuration..."
terraform apply -var-file="dev.tfvars" -auto-approve

# Get outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region)
ECR_URL=$(terraform output -raw ecr_repository_url)

echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo "ECR URL: $ECR_URL"

# Configure kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Deploy application manifests
echo "Deploying application..."
# Replace variables in manifests
for file in k8s/*.yaml; do
  sed -i.bak \
    -e "s/\${var.app_name}/$APP_NAME/g" \
    -e "s/\${var.app_namespace}/$APP_NAMESPACE/g" \
    -e "s|\${aws_ecr_repository.dev_app.repository_url}|$ECR_URL|g" \
    -e "s/\${var.app_replicas}/1/g" \
    $file
done

# Apply manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/

# Display cluster info
echo "=== Cluster Information ==="
kubectl get nodes
kubectl get pods -n $APP_NAMESPACE

echo "=== Cost Estimation ==="
terraform output cost_estimation

echo "=== Next Steps ==="
terraform output next_steps

echo "=== Deployment Complete! ==="
echo "Estimated monthly cost: $20-50"
echo "To destroy: ./scripts/destroy.sh"