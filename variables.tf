variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "nodejs-dev-cluster"
}

variable "region" {
  description = "AWS region (choose cheaper regions)"
  type        = string
  default     = "us-east-2" # Ohio is often cheaper than N. Virginia
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Instance Configuration
variable "spot_instance_types" {
  description = "Spot instance types for maximum savings"
  type        = list(string)
  default     = ["t3.small", "t3a.small", "t2.small"] # Smallest instance types
}

variable "on_demand_instance_types" {
  description = "On-demand instance types"
  type        = list(string)
  default     = ["t3.small"] # Single on-demand fallback
}

# Scaling Configuration
variable "min_nodes" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1 # Minimum for HA
}

variable "max_nodes" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3 # Small limit for dev
}

variable "desired_nodes" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 1 # Start with 1 node
}

variable "node_disk_size" {
  description = "Disk size for worker nodes in GB"
  type        = number
  default     = 20 # Minimum for EKS
}

# Cost Optimization Flags
variable "enable_spot_instances" {
  description = "Enable spot instances (recommended for dev)"
  type        = bool
  default     = true
}

variable "enable_scheduled_scaling" {
  description = "Scale down to zero during off-hours"
  type        = bool
  default     = false
}

variable "off_hours_start" {
  description = "When to scale down (24h format)"
  type        = string
  default     = "19:00" # 7 PM
}

variable "off_hours_end" {
  description = "When to scale up (24h format)"
  type        = string
  default     = "07:00" # 7 AM
}

variable "scale_to_zero_weekends" {
  description = "Scale to zero on weekends"
  type        = bool
  default     = true
}

variable "enable_karpenter" {
  description = "Use Karpenter for better bin-packing"
  type        = bool
  default     = false
}

# Application Configuration
variable "app_name" {
  description = "Node.js application name"
  type        = string
  default     = "nodejs-app"
}

variable "app_replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 1 # Single replica for dev
}

variable "app_namespace" {
  description = "Kubernetes namespace for the app"
  type        = string
  default     = "nodejs-app"
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment  = "dev"
    Purpose      = "testing"
    ManagedBy    = "terraform"
    CostCenter   = "engineering-dev"
    AutoShutdown = "true" # For cost tracking
  }
}