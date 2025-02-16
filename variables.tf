

variable "company_prefix" {
  type        = string
  description = "Company prefix to be used for resource names"
  default     = "sandbox-system"
}

variable "domain" {
  type        = string
  description = "Domain name to be used for resource names"
  default     = "example.com"
}

### ---- VPC ----

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the VPC"
  default     = "10.16.0.0/16"  # VPC spans 10.16.0.0 -> 10.16.255.255 (65,536 IPs)
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

variable "region" {
  type        = string
  description = "Main deployed AWS Region. MUST SUPPORT AT LEAST 3 AVAILABILITY ZONES"
  default     = "eu-west-2"
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