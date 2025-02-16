resource "aws_cloudwatch_log_group" "ecs" {
  name = "/${var.company_prefix}-sandbox/ecs/"
}

resource "aws_cloudwatch_log_group" "lambda_proxy" {
  name = "/${var.company_prefix}-sandbox/lambda/proxy/"
}

resource "aws_cloudwatch_log_group" "lambda_initial_create" {
  name = "/${var.company_prefix}-sandbox/lambda/initial_create/"
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name = "/${var.company_prefix}-sandbox/api_gateway/"
}