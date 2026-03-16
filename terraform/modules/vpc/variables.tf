variable "name" {
  description = "VPC name prefix"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway"
  type        = bool
  default     = true
}

variable "karpenter_discovery" {
  description = "Value for karpenter.sh/discovery subnet tag used by EC2NodeClass selectors"
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
