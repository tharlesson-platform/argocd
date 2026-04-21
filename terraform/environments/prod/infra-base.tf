locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Platform    = "gitops"
  })
}

module "vpc" {
  source = "../../modules/vpc"

  name                = "${var.cluster_name}-vpc"
  cidr                = var.vpc_cidr
  azs                 = var.azs
  private_subnets     = var.private_subnets
  public_subnets      = var.public_subnets
  karpenter_discovery = var.cluster_name

  tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  public_subnet_ids  = module.vpc.public_subnets

  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size

  tags = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  repositories = var.ecr_repositories
  tags         = local.common_tags
}
