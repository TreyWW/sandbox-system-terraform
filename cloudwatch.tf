resource "aws_cloudwatch_log_group" "ecs" {
  name = "/${var.company_prefix}-sandbox/ecs/"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name = "/${var.company_prefix}-sandbox/lambda/"
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name = "/${var.company_prefix}-sandbox/api_gateway/"
}