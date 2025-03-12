resource "aws_cloudwatch_log_group" "ecs" {
  name = "/${var.company_prefix}-sandbox/ecs/"
}

resource "aws_cloudwatch_log_group" "proxy_request_lambda" {
  name = "/${var.company_prefix}-sandbox/lambda/proxy/"
}

resource "aws_cloudwatch_log_group" "provision_sandbox_lambda" {
  name = "/${var.company_prefix}-sandbox/lambda/privsion-sandbox/"
}

resource "aws_cloudwatch_log_group" "shutdown_sandbox_lambda" {
  name = "/${var.company_prefix}-sandbox/lambda/shutdown-sandbox/"
}

resource "aws_cloudwatch_log_group" "restart_sandbox_lambda" {
  name = "/${var.company_prefix}-sandbox/lambda/restart-sandbox/"
}

resource "aws_cloudwatch_log_group" "monitor_sandbox_lambda" {
  name = "/${var.company_prefix}-sandbox/lambda/monitor-sandbox/"
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name = "/${var.company_prefix}-sandbox/api_gateway/"
}

resource "aws_cloudwatch_log_group" "ecs_access_logs" {
  name = "/${var.company_prefix}-sandbox/ecs/access_logs/"
}