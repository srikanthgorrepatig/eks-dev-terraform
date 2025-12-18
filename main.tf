# Providers
provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

# Data Sources
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Locals for calculations
locals {
  # Use only 2 AZs for dev to save on NAT gateway costs
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Instance selection - prioritize cheapest
  instance_types = var.enable_spot_instances ? var.spot_instance_types : var.on_demand_instance_types

  # Spot percentage - 100% for dev if enabled
  spot_percentage = var.enable_spot_instances ? 100 : 0
}

# Minimal VPC for dev
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # Only 2 AZs for dev
  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # Cost-saving VPC configuration
  enable_nat_gateway     = true
  single_nat_gateway     = true # One NAT for both AZs
  one_nat_gateway_per_az = false

  # No VPN gateway for dev
  enable_vpn_gateway = false

  # Essential settings for EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.cluster_name
  }

  tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# Minimal EKS Cluster for Dev
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.28" # Latest stable

  # Public access only for dev (no private endpoint)
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false # Save costs

  # Minimal logging for dev
  cloudwatch_log_group_retention_in_days = 3                # Keep logs for only 3 days
  cluster_enabled_log_types              = ["api", "audit"] # Only essential logs

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Create node group only if Karpenter is disabled
  eks_managed_node_groups = var.enable_karpenter ? {} : {
    dev-nodes = {
      name = "dev-node-group"

    # ====== CRITICAL ADDITION ======
    ami_type = "AL2_x86_64"  # Amazon Linux 2 for EKS 1.28
    
    # Use cheapest instances
    instance_types = var.enable_spot_instances ? var.spot_instance_types : var.on_demand_instance_types

    # Spot instances configuration
    capacity_type = var.enable_spot_instances ? "SPOT" : "ON_DEMAND"

      # Minimal scaling
      min_size     = var.min_nodes
      max_size     = var.max_nodes
      desired_size = var.desired_nodes

      # Minimal disk
      disk_size = var.node_disk_size
      disk_type = "gp3" # Cheaper and better

      # Required for EBS CSI driver to work
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # Fast updates for dev
      update_config = {
        max_unavailable_percentage = 50 # Fast updates
      }

      # Labels for cost tracking
      labels = {
        Environment = "dev"
        SpotAllowed = var.enable_spot_instances ? "true" : "false"
      }

      tags = merge(var.tags, {
        "k8s.io/cluster-autoscaler/enabled" = "true"
      })
    }
  }

  # Only essential add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        replicaCount = 2 # TWO replicas for HA (was 1)
        resources = {
          limits = {
            memory = "170Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "70Mi"
          }
        }
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          # Optimize for cost
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
          WARM_IP_TARGET           = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Enable IRSA for add-ons
  enable_irsa = true

  tags = var.tags
}

# Karpenter for Dev (Better cost optimization)
module "karpenter" {
  count = var.enable_karpenter ? 1 : 0
  
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 19.0"

  cluster_name = module.eks.cluster_name

  # IAM Role for Karpenter IRSA - the module handles OIDC automatically
  create_irsa = true
  irsa_name   = "karpenter-controller"

  # Node IAM Role - create a separate one for Karpenter
  create_iam_role = true
  iam_role_name   = "${module.eks.cluster_name}-karpenter-node"
  
  # REMOVED: oidc_provider_arn = module.eks.oidc_provider_arn (not needed)
}

# Fix Karpenter IAM role trust policy
resource "aws_iam_role_policy_attachment" "karpenter_irsa_fix" {
  count = var.enable_karpenter ? 1 : 0

  role       = module.karpenter[0].irsa_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "helm_release" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  namespace  = "kube-system"
  version    = "0.32.1"

  set {
    name  = "controller.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "controller.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter[0].irsa_arn
  }

  depends_on = [
    module.eks,
    module.karpenter
  ]
}

# Karpenter Provisioner for Dev
resource "kubectl_manifest" "karpenter_provisioner" {
  count = var.enable_karpenter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1alpha5"
    kind       = "Provisioner"
    metadata = {
      name = "dev-provisioner"
    }
    spec = {
      requirements = [
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = var.enable_spot_instances ? ["spot"] : ["on-demand"]
        },
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"]
        },
        {
          key      = "node.kubernetes.io/instance-type"
          operator = "In"
          values   = var.spot_instance_types
        },
        {
          key      = "topology.kubernetes.io/zone"
          operator = "In"
          values   = local.azs
        }
      ]

      limits = {
        resources = {
          cpu    = 4
          memory = "8Gi"
        }
      }

      consolidation = {
        enabled = true
      }

      ttlSecondsAfterEmpty = 30

      startupTaints = [{
        key    = "initial"
        value  = "true"
        effect = "NoSchedule"
      }]
    }
  })

  depends_on = [helm_release.karpenter]
}

# Scheduled Scaling for Dev (Scale to zero at night)
resource "aws_autoscaling_schedule" "scale_down_night" {
  count = var.enable_scheduled_scaling && !var.enable_karpenter ? 1 : 0

  scheduled_action_name  = "scale-down-night"
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 ${split(":", var.off_hours_start)[0]} * * *"
  autoscaling_group_name = module.eks.eks_managed_node_groups["dev-nodes"].autoscaling_group_names[0]
}

resource "aws_autoscaling_schedule" "scale_up_morning" {
  count = var.enable_scheduled_scaling && !var.enable_karpenter ? 1 : 0

  scheduled_action_name  = "scale-up-morning"
  min_size               = var.min_nodes
  max_size               = var.max_nodes
  desired_capacity       = var.desired_nodes
  recurrence             = "0 ${split(":", var.off_hours_end)[0]} * * *"
  autoscaling_group_name = module.eks.eks_managed_node_groups["dev-nodes"].autoscaling_group_names[0]
}

# Weekend shutdown (Scale to zero)
resource "aws_autoscaling_schedule" "weekend_shutdown" {
  count = var.enable_scheduled_scaling && var.scale_to_zero_weekends && !var.enable_karpenter ? 1 : 0

  scheduled_action_name  = "weekend-shutdown"
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 18 * * 5"
  autoscaling_group_name = module.eks.eks_managed_node_groups["dev-nodes"].autoscaling_group_names[0]
}

resource "aws_autoscaling_schedule" "weekend_startup" {
  count = var.enable_scheduled_scaling && var.scale_to_zero_weekends && !var.enable_karpenter ? 1 : 0

  scheduled_action_name  = "weekend-startup"
  min_size               = var.min_nodes
  max_size               = var.max_nodes
  desired_capacity       = var.desired_nodes
  recurrence             = "0 8 * * 1"
  autoscaling_group_name = module.eks.eks_managed_node_groups["dev-nodes"].autoscaling_group_names[0]
}

# ECR Repository for Dev
resource "aws_ecr_repository" "dev_app" {
  name                 = "${var.app_name}-dev"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = var.tags
}

# Corrected lifecycle policy resource
resource "aws_ecr_lifecycle_policy" "dev_app" {
  repository = aws_ecr_repository.dev_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Simple S3 bucket for Terraform state (cheapest option)
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.cluster_name}-terraform-state"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable bucket lifecycle to delete old states
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-states"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }
  }
}

# Budget for dev cluster
resource "aws_budgets_budget" "dev_cluster" {
  name         = "${var.cluster_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = "50"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["srikanthmecm@gmail.com"]
  }
}

data "aws_caller_identity" "current" {}
