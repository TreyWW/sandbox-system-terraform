resource "aws_security_group" "lambda_sg" {
  count = var.lambda_in_vpc == true ? 1 : 0
  name        = "${var.prefix}-${var.lambda_name}-lambda"
  description = length(var.security_group_description) > 0 ? var.security_group_description : "Security group for ${var
  .lambda_name} lambda"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ingress" {
  count = length(var.sg_ingress_rules)
  description = var.sg_ingress_rules[count.index].description
  security_group_id = aws_security_group.lambda_sg[0].id
  referenced_security_group_id = var.sg_ingress_rules[count.index].referenced_security_group_id
  cidr_ipv4   = var.sg_ingress_rules[count.index].cidr_ipv4
  from_port   = var.sg_ingress_rules[count.index].to_port
  to_port     = var.sg_ingress_rules[count.index].from_port
  ip_protocol = var.sg_ingress_rules[count.index].protocol
}

resource "aws_vpc_security_group_egress_rule" "egress" {
  count = length(var.sg_egress_rules)
  description = var.sg_egress_rules[count.index].description
  security_group_id = aws_security_group.lambda_sg[0].id
  referenced_security_group_id = var.sg_egress_rules[count.index].referenced_security_group_id
  cidr_ipv4   = var.sg_egress_rules[count.index].cidr_ipv4
  from_port   = var.sg_egress_rules[count.index].to_port
  to_port     = var.sg_egress_rules[count.index].from_port
  ip_protocol = var.sg_egress_rules[count.index].protocol
}

resource "aws_iam_role" "execution_role" {
  name = "${var.prefix}-${var.lambda_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "execution_role_policy" {
  name = "${var.prefix}-${var.lambda_name}-lambda-execution-role-policy"

  policy = var.lambda_role_execution_policy
}

resource "aws_iam_role_policy_attachment" "execution_role_policy_attachment" {
  role       = aws_iam_role.execution_role.id
  policy_arn = aws_iam_policy.execution_role_policy.arn
}

resource "aws_lambda_layer_version" "dependencies" {
  filename   = var.lambda_dependencies_zip_path
  layer_name = "${var.prefix}-${var.lambda_name}-dependencies"

  compatible_runtimes = [var.lambda_runtime]
}

data "archive_file" "lambda_code" {
  type        = "zip"
  source_file = var.lambda_source_file_path
  output_path = var.lambda_output_file_path
}

resource "aws_lambda_function" "lambda" {
  filename      = var.lambda_output_file_path
  source_code_hash = data.archive_file.lambda_code.output_base64sha256
  function_name = "${var.prefix}-${var.lambda_name}"

  handler = "lambda_function.lambda_handler"
  role    = aws_iam_role.execution_role.arn
  runtime = var.lambda_runtime
  timeout = var.lambda_timeout


  dynamic "vpc_config" {
    for_each = var.lambda_in_vpc ? [1] : []

    content {
      security_group_ids = [aws_security_group.lambda_sg[0].id]
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = var.environment_variables
  }

  logging_config {
    log_group  = var.log_group_name
    log_format = "Text"
  }

  layers = [
    aws_lambda_layer_version.dependencies.arn
  ]
}

resource "aws_lambda_permission" "apigw_perm" {
  count = var.lambda_apigateway_source_arn != "" ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = var.lambda_apigateway_source_arn
}