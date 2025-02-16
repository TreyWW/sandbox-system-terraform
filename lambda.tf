# Lambda for creating initial service e.g. from github


resource "aws_security_group" "initial_service_lambda" {
  name        = "${var.company_prefix}-initial-service-lambda"
  description = "Security group for lambda function to create initial services"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "initial_service_lambda_egress_fcknat" {
  security_group_id = aws_security_group.initial_service_lambda.id

  referenced_security_group_id = aws_security_group.fck_nat_sg.id

  ip_protocol = "-1"
}

resource "aws_iam_role" "initial_service_lambda_execution_role" {
  name = "${var.company_prefix}-initial-service-lambda-execution-role"

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

resource "aws_iam_policy" "initial_service_lambda_execution_role_policy" {
  name = "${var.company_prefix}-initial-service-lambda-execution-role-policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid": "EventBridgeScheduler",
        "Effect" : "Allow",
        "Action" : [
          "scheduler:CreateSchedule"
        ],
        "Resource" : "arn:aws:scheduler:${var.region}:${local.account_id}:schedule/${aws_scheduler_schedule_group.default.name}/*"
      },
      {
        "Sid": "ECS"
        "Effect" : "Allow",
        "Action" : [
          "ecs:CreateService",
          "ecs:RegisterTaskDefinition",
          "ecs:TagResource"
        ],
        "Resource" : [
          "arn:aws:ecs:${var.region}:${local.account_id}:service/${var.company_prefix}-*",
          "arn:aws:ecs:${var.region}:${local.account_id}:task-definition/${var.company_prefix}-*",
          "arn:aws:ecs:${var.region}:${local.account_id}:service/demo-sandbox-system-sandbox-cluster/demo-sandbox-system-*"
        ]
      },
      {
        "Sid": "CloudMap"
        "Effect" : "Allow",
        "Action" : [
          "servicediscovery:RegisterInstance",
          "servicediscovery:CreateService",
          "servicediscovery:GetService"
        ],
        "Resource" : [
          "arn:aws:servicediscovery:${var.region}:${local.account_id}:service/*",
          "arn:aws:servicediscovery:${var.region}:${local.account_id}:namespace/${aws_service_discovery_http_namespace.main_api_namespace.id}"
        ]
      },
      {
        "Sid": "CloudWatch",
        "Effect" : "Allow",
        "Action" : [
          "events:PutRule",
          "events:PutTargets",
          "events:DescribeRule",
          "events:ListRules",
          "events:ListTargetsByRule"
        ],
        "Resource" : [
          "arn:aws:events:${var.region}:${local.account_id}:rule/${var.company_prefix}-*"
        ]
      },
      {
        "Sid": "DynamoDB",
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:PutItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ],
        "Resource" : "arn:aws:dynamodb:${var.region}:${local.account_id}:table/${aws_dynamodb_table.metadata_table.name}"
      },
      {
        "Sid" : "AWSLambdaVPCAccessExecutionPermissions",
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ],
        "Resource" : "*"
      },
      {
        "Sid": "PassRoleECSTaskRoles",
        "Effect": "Allow",
        "Action": "iam:PassRole",
        "Resource": [
          aws_iam_role.ecs_task_role.arn,
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.scheduler_role_invoke_shutdown_lambda.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "initial_service_lambda_execution_role_policy_attachment" {
  role       = aws_iam_role.initial_service_lambda_execution_role.id
  policy_arn = aws_iam_policy.initial_service_lambda_execution_role_policy.arn
}

resource "aws_lambda_layer_version" "initial_service_dependencies" {
  filename   = "lambdas/initial-upload/python.zip"
  layer_name = "${var.company_prefix}-initial-service-dependencies"

  compatible_runtimes = ["python3.9"]
}

data "archive_file" "initial_service_lambda_code" {
  type        = "zip"
  source_file = "lambdas/initial-upload/lambda_function.py"
  output_path = "lambdas/initial-upload/lambda_function.zip"
}

resource "aws_lambda_function" "initial_service_lambda" {
  # code is in lambdas/initial-upload/lambda_function.py
  filename      = "lambdas/initial-upload/lambda_function.zip"
  source_code_hash = data.archive_file.initial_service_lambda_code.output_base64sha256
  function_name = "${var.company_prefix}-initial-upload"

  handler = "lambda_function.lambda_handler"
  role    = aws_iam_role.initial_service_lambda_execution_role.arn
  runtime = "python3.9"
  timeout = 20

  vpc_config {
    security_group_ids = [
      aws_security_group.initial_service_lambda.id
    ]
    subnet_ids = [
      aws_subnet.private_1a_with_nat.id,
      aws_subnet.private_1b_with_nat.id,
      aws_subnet.private_1c_with_nat.id
    ]
  }

  environment {
    variables = {
      "company_prefix"        = var.company_prefix
      "domain"                = var.domain
      "metadata_ddb_table"    = aws_dynamodb_table.metadata_table.name
      "cloudmap_namespace_id" = aws_service_discovery_http_namespace.main_api_namespace.id
      "ecs_task_role_arn" = aws_iam_role.ecs_task_role.arn
      "ecs_execution_role_arn" = aws_iam_role.ecs_execution_role.arn
      "ecs_log_group_arn"     = aws_cloudwatch_log_group.ecs.name
      "ecs_log_group_region"  = var.region,
      "ecs_access_log_group_name"   = aws_cloudwatch_log_group.ecs_access_logs.name
      "ecs_cluster_arn"       = aws_ecs_cluster.main.arn
      "ecs_subnets"           = "${aws_subnet.private_1a_with_nat.id},${aws_subnet.private_1b_with_nat.id},${aws_subnet.private_1c_with_nat.id}"
      "ecs_security_groups"   = "${aws_security_group.ecs.id}"
      "shutdown_lambda_arn" = aws_lambda_function.shutdown_instance_lambda.arn
      "scheduler_role_arn"    = aws_iam_role.scheduler_role_invoke_shutdown_lambda.arn
      "scheduler_group_name" = aws_scheduler_schedule_group.default.name
    }
  }

  logging_config {
    log_group  = aws_cloudwatch_log_group.lambda_initial_create.name
    log_format = "Text"
  }

  layers = [
    aws_lambda_layer_version.initial_service_dependencies.arn
  ]

  depends_on = [
    aws_iam_role_policy_attachment.initial_service_lambda_execution_role_policy_attachment,
    aws_lambda_layer_version.initial_service_dependencies,
    aws_iam_role.ecs_task_role,
    aws_iam_role.ecs_execution_role,
    aws_cloudwatch_log_group.ecs_access_logs,
    aws_cloudwatch_log_group.lambda_initial_create,
    aws_cloudwatch_log_group.ecs,
    aws_dynamodb_table.metadata_table,
    aws_ecs_cluster.main,
    aws_vpc.main
  ]
}

/* Lambda for shutdown the instance */

resource "aws_security_group" "shutdown_instance_lambda" {
  name        = "${var.company_prefix}-shutdown-instance-lambda"
  description = "Security group for lambda function to shutdown the ECS service"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "shutdown_instance_lambda_egress_fcknat" {
  security_group_id = aws_security_group.shutdown_instance_lambda.id

  referenced_security_group_id = aws_security_group.fck_nat_sg.id

  ip_protocol = "-1"
}

resource "aws_iam_role" "shutdown_instance_lambda_execution_role" {
  name = "${var.company_prefix}-shutdown-instance-lambda-execution-role"

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

resource "aws_iam_policy" "shutdown_instance_lambda_execution_role_policy" {
  name = "${var.company_prefix}-shutdown-instance-lambda-execution-role-policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid": "ECS"
        "Effect" : "Allow",
        "Action" : [
          "ecs:UpdateService",
        ],
        "Resource" : [
          "arn:aws:ecs:${var.region}:${local.account_id}:service/${var.company_prefix}-*",
          "arn:aws:ecs:${var.region}:${local.account_id}:service/demo-sandbox-system-sandbox-cluster/demo-sandbox-system-*"
        ]
      },
      {
        "Sid": "CloudWatch",
        "Effect" : "Allow",
        "Action" : [
          "logs:FilterLogEvents",
          "logs:PutMetricFilter",
          "logs:DeleteMetricFilter",
          "logs:DescribeMetricFilters"
        ],
        "Resource" : [
          "arn:aws:logs:${var.region}:${local.account_id}:log-group:${aws_cloudwatch_log_group.ecs_access_logs.name}:log-stream:*",
          "arn:aws:logs:${var.region}:${local.account_id}:log-group:${aws_cloudwatch_log_group.ecs_access_logs.name}"
        ]
      },
      {
        "Sid": "DynamoDB",
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ],
        "Resource" : "arn:aws:dynamodb:${var.region}:${local.account_id}:table/${aws_dynamodb_table.metadata_table.name}"
      },
      {
        "Sid" : "AWSLambdaVPCAccessExecutionPermissions",
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ],
        "Resource" : "*"
      },
      {
        "Sid": "PassRoleECSTaskRoles",
        "Effect": "Allow",
        "Action": "iam:PassRole",
        "Resource": [
          aws_iam_role.ecs_task_role.arn,
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.scheduler_role_invoke_shutdown_lambda.arn
        ]
      },
      {
        "Sid": "EventBridgeGetSchedule",
        "Effect": "Allow",
        "Action": [
          "scheduler:GetSchedule",
          "scheduler:UpdateSchedule"
        ],
        "Resource": "arn:aws:scheduler:${var.region}:${local.account_id}:schedule/${aws_scheduler_schedule_group.default.name}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "shutdown_instance_lambda_execution_role_policy_attachment" {
  role       = aws_iam_role.shutdown_instance_lambda_execution_role.id
  policy_arn = aws_iam_policy.shutdown_instance_lambda_execution_role_policy.arn
}

resource "aws_lambda_layer_version" "shutdown_instance_dependencies" {
  filename   = "lambdas/shutdown-task/python.zip"
  layer_name = "${var.company_prefix}-shutdown-instance-dependencies"

  compatible_runtimes = ["python3.9"]
}

data "archive_file" "shutdown_instance_lambda_code" {
  type        = "zip"
  source_file = "lambdas/shutdown-task/lambda_function.py"
  output_path = "lambdas/shutdown-task/lambda_function.zip"
}

resource "aws_lambda_function" "shutdown_instance_lambda" {
  # code is in lambdas/initial-upload/lambda_function.py
  filename      = "lambdas/shutdown-task/lambda_function.zip"
  source_code_hash = data.archive_file.shutdown_instance_lambda_code.output_base64sha256
  function_name = "${var.company_prefix}-shutdown-instance"

  handler = "lambda_function.lambda_handler"
  role    = aws_iam_role.shutdown_instance_lambda_execution_role.arn
  runtime = "python3.9"
  timeout = 20

  environment {
    variables = {
      "company_prefix"        = var.company_prefix
      "domain"                = var.domain
      "metadata_ddb_table"    = aws_dynamodb_table.metadata_table.name
      "ecs_cluster_arn"       = aws_ecs_cluster.main.arn,
      "ecs_access_log_group_name" = aws_cloudwatch_log_group.ecs_access_logs.name
      "scheduler_group_name" = aws_scheduler_schedule_group.default.name
    }
  }

  logging_config {
    log_group  = aws_cloudwatch_log_group.lambda_shutdown_instance.name
    log_format = "Text"
  }

  layers = [
    aws_lambda_layer_version.shutdown_instance_dependencies.arn
  ]

  depends_on = [
    aws_iam_role_policy_attachment.shutdown_instance_lambda_execution_role_policy_attachment,
    aws_lambda_layer_version.shutdown_instance_dependencies,
    aws_iam_role.ecs_task_role,
    aws_iam_role.ecs_execution_role,
    aws_cloudwatch_log_group.lambda_shutdown_instance,
    aws_cloudwatch_log_group.ecs,
    aws_dynamodb_table.metadata_table,
    aws_ecs_cluster.main,
    aws_vpc.main
  ]
}


# attach layer




# Lambda proxy normal requests to their respective ECS service

resource "aws_security_group" "lambda_proxy" {
  name        = "${var.company_prefix}-lambda-proxy"
  description = "Security group for lambda proxy"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "lambda_proxy_egress_ecs_80" {
  security_group_id = aws_security_group.lambda_proxy.id

  referenced_security_group_id = aws_security_group.ecs.id

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "lambda_proxy_egress_ecs_443" {
  security_group_id = aws_security_group.lambda_proxy.id

  referenced_security_group_id = aws_security_group.ecs.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "lambda_proxy_egress_fcknat" {
  security_group_id = aws_security_group.lambda_proxy.id

  referenced_security_group_id = aws_security_group.fck_nat_sg.id

  ip_protocol = "-1"
}

resource "aws_iam_role" "lambda_proxy_execution_role" {
  name = "${var.company_prefix}-lambda-proxy-execution-role"

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

resource "aws_iam_policy" "lambda_proxy_execution_role_policy" {
  name = "${var.company_prefix}-lambda-proxy-execution-role-policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition"
        ],
        "Resource" : [
          "arn:aws:ecs:${var.region}:${local.account_id}:service/${var.company_prefix}-*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "servicediscovery:GetInstance",
        ],
        "Resource" : "arn:aws:servicediscovery:${var.region}:${local.account_id}:service/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "servicediscovery:DiscoverInstances"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ],
        "Resource" : [
          "arn:aws:dynamodb:${var.region}:${local.account_id}:table/${aws_dynamodb_table.metadata_table.name}",
          "arn:aws:dynamodb:${var.region}:${local.account_id}:table/${aws_dynamodb_table.metadata_table.name}/index/DomainIndex"
        ]
      },
      {
        "Sid" : "AWSLambdaVPCAccessExecutionPermissions",
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_proxy_execution_role_policy_attachment" {
  role       = aws_iam_role.lambda_proxy_execution_role.id
  policy_arn = aws_iam_policy.lambda_proxy_execution_role_policy.arn
}

resource "aws_lambda_layer_version" "lambda_proxy_dependencies" {
  filename   = "lambdas/proxy/python.zip"
  layer_name = "${var.company_prefix}-lambda-proxy-dependencies"

  compatible_runtimes = ["python3.9"]
}

data "archive_file" "proxy_lambda_code" {
  type        = "zip"
  source_file = "lambdas/proxy/lambda_function.py"
  output_path = "lambdas/proxy/lambda_function.zip"
}

resource "aws_lambda_function" "lambda_proxy" {
  # code is in lambdas/lambda-proxy/lambda_function.py
  filename      = "lambdas/proxy/lambda_function.zip"
  source_code_hash = data.archive_file.proxy_lambda_code.output_base64sha256
  function_name = "${var.company_prefix}-lambda-proxy"

  handler = "lambda_function.lambda_handler"
  role    = aws_iam_role.lambda_proxy_execution_role.arn
  runtime = "python3.9"
  timeout = 20

  vpc_config {
    security_group_ids = [
      aws_security_group.lambda_proxy.id
    ]
    subnet_ids = [
      aws_subnet.private_1a_with_nat.id,
      aws_subnet.private_1b_with_nat.id,
      aws_subnet.private_1c_with_nat.id
    ]
  }

  environment {
    variables = {
      "cloudmap_namespace" = aws_service_discovery_http_namespace.main_api_namespace.name,
      "ecs_access_log_group_name" = aws_cloudwatch_log_group.ecs_access_logs.name,
      "metadata_ddb_table_name" = aws_dynamodb_table.metadata_table.name,
    }
  }

  logging_config {
    log_group  = aws_cloudwatch_log_group.lambda_proxy.name
    log_format = "Text"
  }

  layers = [
    aws_lambda_layer_version.lambda_proxy_dependencies.arn
  ]

  depends_on = [
    aws_iam_role_policy_attachment.lambda_proxy_execution_role_policy_attachment,
    aws_cloudwatch_log_group.ecs_access_logs,
    aws_lambda_layer_version.lambda_proxy_dependencies,
    aws_cloudwatch_log_group.lambda_proxy,
    aws_dynamodb_table.metadata_table,
    aws_ecs_cluster.main,
    aws_vpc.main
  ]
}

resource "aws_lambda_permission" "lambda_proxy_apigw_perm" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_proxy.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.user_service_endpoint.execution_arn}/*/*"
}