variable "prefix" {
  description = "Prefix to be used on resources as identifier"
  type        = string
  default     = "sandbox-system"
}

variable "name" {
  description = "Name to be used on all resources"
  type        = string
}

variable "inline_iam_policies" {
  description = "Inline IAM policies to be attached to the role"
  type        = list(object({
    name        = string
    policy_json = string
  }))
  default     = []
}

variable "principal_services" {
  type = list(string)
  default = ["lambda.amazonaws.com"]
}