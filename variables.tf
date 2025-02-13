

variable "company_prefix" {
  type        = string
  description = "Company prefix to be used for resource names"
  default     = "sandbox-system"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository name"
  default     = "TreyWW/sandbox-system-terraform"
}

variable "github_autodeploy_enabled" {
  type        = bool
  description = "Whether to enable GitHub auto-deploy"
  default     = false
}

### ---- VPC ----

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the VPC"
  default     = "10.16.0.0/16"  # VPC spans 10.16.0.0 -> 10.16.255.255 (65,536 IPs)
}

variable "region" {
  type        = string
  description = "Main deployed AWS Region. MUST SUPPORT AT LEAST 3 AVAILABILITY ZONES"
  default     = "eu-west-2"
}

# ---- PEER VPC

variable "peer_vpc_enabled" {
  type        = bool
  description = "Whether to peer VPC with another for any resources (such as shared NAT)"
  default     = false
}

variable "peer_vpc_cidr" {
  type        = string
  description = "CIDR for the VPC"
  default     = "10.17.0.0/16"  # VPC spans 10.17.0.0 -> 10.17.255.255 (65,536 IPs)
}

variable "peer_owner_id" {
  type        = string
  description = "AWS Account ID of the VPC owner"
  default     = "123456789012"
}

variable "peer_vpc_region" {
  type        = string
  description = "Region of the VPC owner"
  default     = "eu-west-2"
}

variable "peer_vpc_id" {
  type        = string
  description = "VPC ID of the VPC owner"
  default     = "vpc-12345678901234567"
}

# ---- PUBLIC SUBNETS ----

variable "sn_cidr_public_1a" {
  type        = string
  description = "CIDR for VPC Subnet in public 1a"
  default     = "10.16.0.0/20" # 10.16.0.0 -> 10.16.15.255 (4,096 IPs)
}
variable "sn_cidr_public_1b" {
  type        = string
  description = "CIDR for VPC Subnet in public 1b"
  default     = "10.16.16.0/20" # 10.16.16.0 -> 10.16.31.255 (4,096 IPs)
}
variable "sn_cidr_public_1c" {
  type        = string
  description = "CIDR for VPC Subnet in public 1c"
  default     = "10.16.32.0/20" # 10.16.32.0 -> 10.16.47.255 (4,096 IPs)
}

# ---- PRIVATE SUBNETS ----

variable "sn_cidr_private_1a" {
  type        = string
  description = "CIDR for VPC Subnet in private 1a"
  default     = "10.16.128.0/20" # 10.16.128.0 -> 10.16.143.255 (4,096 IPs)
}
variable "sn_cidr_private_1b" {
  type        = string
  description = "CIDR for VPC Subnet in private 1b"
  default     = "10.16.144.0/20" # 10.16.144.0 -> 10.16.159.255 (4,096 IPs)
}
variable "sn_cidr_private_1c" {
  type        = string
  description = "CIDR for VPC Subnet in private 1c"
  default     = "10.16.160.0/20" # 10.16.160.0 -> 10.16.175.255 (4,096 IPs)
}


# ---- PRIVATE SUBNETS WITH NAT ----

variable "sn_cidr_private_1a_with_nat" {
  type        = string
  description = "CIDR for VPC Subnet in private 1a with NAT outbound"
  default     = "10.16.176.0/20" # 10.16.176.0 -> 10.16.191.255 (4,096 IPs)
}
variable "sn_cidr_private_1b_with_nat" {
  type        = string
  description = "CIDR for VPC Subnet in private 1b with NAT outbound"
  default     = "10.16.192.0/20" # 10.16.192.0 -> 10.16.207.255 (4,096 IPs)
}
variable "sn_cidr_private_1c_with_nat" {
  type        = string
  description = "CIDR for VPC Subnet in private 1c with NAT outbound"
  default     = "10.16.208.0/20" # 10.16.208.0 -> 10.16.223.255 (4,096 IPs)
}