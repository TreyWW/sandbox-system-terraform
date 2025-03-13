variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "prefix" {
  description = "Prefix to be used on resources as identifier"
  type        = string
  default     = "sandbox-system"
}

variable "lambda_name" {
  description = "Name of the lambda function"
  type        = string
  default     = "lambda"
}

variable "lambda_log_level" {
  description = "Log level for the lambda function"
  type        = string
  default     = "INFO"
}

variable "lambda_memory_size" {
  description = "Amount of memory in MB the lambda function can use"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "The amount of time the lambda Function has to run in seconds"
  type        = number
  default     = 3
}

variable "lambda_runtime" {
  description = "The runtime environment for the lambda function. E.g. 'python3.8'"
  type        = string
  default     = "python3.8"
}

variable "lambda_handler" {
  description = "The name of the executable for the lambda function"
  type        = string
  default     = "main.lambda_handler"
}

variable "vpc_id" {
  description = "The id of the VPC the lambda function will be deployed to"
  type        = string
  default     = ""

  validation {
    condition     = var.lambda_in_vpc == false || (var.lambda_in_vpc == true && var.vpc_id != "")
    error_message = "If 'lambda_in_vpc' is set to true, you must specify a 'vpc_id'."
  }
}

variable "lambda_role_execution_policy" {
  description = "The IAM policy for the lambda function"
  type        = any
  default = {}
}

variable "lambda_source_file_path" {
  description = "The path to the lambda source code"
  type        = string
  default     = ""
}

variable "lambda_output_file_path" {
  description = "Where the ZIP file will be created"
  type        = string
  default     = ""
}

variable "environment_variables" {
  description = "Environment variables for the lambda function"
  type = map(string)
  default = {}
}

variable "log_group_name" {
  description = "Name of the log group for the lambda function"
  type        = string
  default     = ""
}

variable "lambda_depends_on" {
  description = "Resources that the lambda function depends on"
  type = list(any)
  default = []
}

variable "lambda_apigateway_source_arn" {
  description = "The source arn for the lambda function"
  type        = string
  default     = ""  # "${aws_api_gateway_rest_api.user_service_endpoint.execution_arn}/*/*"
}

variable "lambda_in_vpc" {
  description = "Whether the lambda function is in a VPC"
  type        = bool
  default     = false
}

variable "vpc_subnet_ids" {
  description = "The security group ids for the lambda function"
  type = list(string)
  default = []
}

variable "vpc_security_group_ids" {
  description = "The security group ids for the lambda function"
  type = list(string)
  default = []
}

variable "security_group_description" {
  description = "The description of the security group"
  type        = string
  default     = ""
}

variable "sg_ingress_rules" {
  description = "Ingress rules for the lambda function"
  type = list(
    object({
      description = optional(string)
      from_port                    = number
      to_port                      = number
      protocol                     = string
      cidr_ipv4 = optional(string)
      referenced_security_group_id = string
    })
  )
  default = []
}

variable "sg_egress_rules" {
  description = "Egress rules for the lambda function"
  type = list(
    object({
      description = optional(string)
      from_port = optional(number)
      to_port = optional(number)
      protocol = optional(string)
      cidr_ipv4 = optional(string)
      referenced_security_group_id = string
    })
  )
  default = []
}

variable "lambda_dependencies_zip_path" {
  description = "The path to the lambda dependencies ZIP file"
  type        = string
  default     = ""
}