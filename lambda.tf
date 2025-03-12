# Lambda for creating initial service e.g. from github

module "provision_sandbox_lambda" {
  source = "./modules/lambda"

  prefix = var.company_prefix

  lambda_name             = "provision-sandbox"
  lambda_source_file_path = "lambdas/provision-sandbox/lambda_function.py"
  lambda_output_file_path = "lambdas/provision-sandbox/lambda_function.zip"

  lambda_runtime = "python3.9"
  lambda_timeout = 20

  lambda_in_vpc = true
  vpc_subnet_ids = [
    aws_subnet.private_1a_with_nat.id,
    aws_subnet.private_1b_with_nat.id,
    aws_subnet.private_1c_with_nat.id
  ]

  lambda_role_execution_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "EventBridgeScheduler",
        "Effect" : "Allow",
        "Action" : [
          "scheduler:CreateSchedule"
        ],
        "Resource" : "arn:aws:scheduler:${var.region}:${local.account_id}:schedule/${aws_scheduler_schedule_group.default.name}/*"
      },
      {
        "Sid" : "ECS"
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
        "Sid" : "CloudMap"
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
        "Sid" : "CloudWatch",
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
        "Sid" : "DynamoDB",
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
        "Sid" : "PassRoleECSTaskRoles",
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : [
          aws_iam_role.ecs_task_role.arn,
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.scheduler_role_invoke_shutdown_lambda.arn
        ]
      }
    ]
  })

  environment_variables = {
    "company_prefix"            = var.company_prefix
    "domain"                    = var.domain
    "metadata_ddb_table"        = aws_dynamodb_table.metadata_table.name
    "cloudmap_namespace_id"     = aws_service_discovery_http_namespace.main_api_namespace.id
    "ecs_task_role_arn"         = aws_iam_role.ecs_task_role.arn
    "ecs_execution_role_arn"    = aws_iam_role.ecs_execution_role.arn
    "ecs_log_group_arn"         = aws_cloudwatch_log_group.ecs.name
    "ecs_log_group_region"      = var.region,
    "ecs_access_log_group_name" = aws_cloudwatch_log_group.ecs_access_logs.name
    "ecs_cluster_arn"           = aws_ecs_cluster.main.arn
    "ecs_subnets"               = "${aws_subnet.private_1a_with_nat.id},${aws_subnet.private_1b_with_nat.id},${aws_subnet.private_1c_with_nat.id}"
    "ecs_security_groups"       = "${aws_security_group.ecs.id}"
    "shutdown_lambda_arn"       = module.shutdown_sandbox_lambda.lambda_arn
    "scheduler_role_arn"        = aws_iam_role.scheduler_role_invoke_shutdown_lambda.arn
    "scheduler_group_name"      = aws_scheduler_schedule_group.default.name
  }

  log_group_name = aws_cloudwatch_log_group.provision_sandbox_lambda.name

  lambda_dependencies_zip_path = "lambdas/provision-sandbox/python.zip"

  vpc_id = aws_vpc.main.id

  security_group_description = "Security group for lambda function to create initial services"
  sg_egress_rules = [
    {
      description                  = "Nat Instance"
      from_port                    = -1
      to_port                      = -1
      protocol                     = "-1"
      referenced_security_group_id = aws_security_group.fck_nat_sg.id
    }
  ]
}

/* Lambda for shutdown the instance */

module "shutdown_sandbox_lambda" {
  source = "./modules/lambda"

  prefix = var.company_prefix

  lambda_name             = "shutdown-sandbox"
  lambda_source_file_path = "lambdas/shutdown-sandbox/lambda_function.py"
  lambda_output_file_path = "lambdas/shutdown-sandbox/lambda_function.zip"
  lambda_dependencies_zip_path = "lambdas/shutdown-sandbox/python.zip"

  lambda_runtime = "python3.9"
  lambda_timeout = 20

  lambda_in_vpc = false

  lambda_role_execution_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "ECS"
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
        "Sid" : "CloudWatch",
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
        "Sid" : "DynamoDB",
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
        "Sid" : "PassRoleECSTaskRoles",
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : [
          aws_iam_role.ecs_task_role.arn,
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.scheduler_role_invoke_shutdown_lambda.arn
        ]
      },
      {
        "Sid" : "EventBridgeGetSchedule",
        "Effect" : "Allow",
        "Action" : [
          "scheduler:GetSchedule",
          "scheduler:UpdateSchedule"
        ],
        "Resource" : "arn:aws:scheduler:${var.region}:${local.account_id}:schedule/${aws_scheduler_schedule_group.default.name}/*"
      }
    ]
  })

  environment_variables = {
      "company_prefix"            = var.company_prefix
      "domain"                    = var.domain
      "metadata_ddb_table"        = aws_dynamodb_table.metadata_table.name
      "ecs_cluster_arn"           = aws_ecs_cluster.main.arn,
      "ecs_access_log_group_name" = aws_cloudwatch_log_group.ecs_access_logs.name
      "scheduler_group_name"      = aws_scheduler_schedule_group.default.name
  }

  log_group_name = aws_cloudwatch_log_group.shutdown_sandbox_lambda.name
}

/* Re-Startup Task */

module "restart_sandbox_lambda" {
  source = "./modules/lambda"

  prefix = var.company_prefix

  lambda_name             = "restart-sandbox"
  lambda_source_file_path = "lambdas/restart-sandbox/lambda_function.py"
  lambda_output_file_path = "lambdas/restart-sandbox/lambda_function.zip"
  lambda_dependencies_zip_path = "lambdas/restart-sandbox/python.zip"

  lambda_runtime = "python3.10"
  lambda_timeout = 10

  lambda_in_vpc = false

  lambda_role_execution_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "ECS"
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
        "Sid" : "DynamoDB",
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ],
        "Resource" : "arn:aws:dynamodb:${var.region}:${local.account_id}:table/${aws_dynamodb_table.metadata_table.name}"
      },
      {
        "Sid" : "PassRoleECSTaskRoles",
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : [
          aws_iam_role.ecs_task_role.arn,
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.scheduler_role_invoke_shutdown_lambda.arn
        ]
      },
      {
        "Sid" : "AWSLambdaVPCAccessExecutionPermissions",
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : [
          aws_cloudwatch_log_group.restart_sandbox_lambda.arn,
          "${aws_cloudwatch_log_group.restart_sandbox_lambda.arn}:log-stream:*"
        ]
      },
      {
        "Sid" : "EventBridgeGetSchedule",
        "Effect" : "Allow",
        "Action" : [
          "scheduler:GetSchedule",
          "scheduler:UpdateSchedule"
        ],
        "Resource" : "arn:aws:scheduler:${var.region}:${local.account_id}:schedule/${aws_scheduler_schedule_group.default.name}/*"
      }
    ]
  })

  environment_variables = {
      "company_prefix"            = var.company_prefix
      "domain"                    = var.domain
      "metadata_ddb_table"        = aws_dynamodb_table.metadata_table.name
      "ecs_cluster_arn"           = aws_ecs_cluster.main.arn,
      "ecs_access_log_group_name" = aws_cloudwatch_log_group.ecs_access_logs.name
      "scheduler_group_name"      = aws_scheduler_schedule_group.default.name
  }

  log_group_name = aws_cloudwatch_log_group.restart_sandbox_lambda.name
}

/* Lambda for managing the instance */


module "monitor_sandbox_lambda" {
  source = "./modules/lambda"

  prefix = var.company_prefix

  lambda_name             = "monitor-sandbox"
  lambda_source_file_path = "lambdas/monitor-sandbox/lambda_function.py"
  lambda_output_file_path = "lambdas/monitor-sandbox/lambda_function.zip"
  lambda_dependencies_zip_path = "lambdas/monitor-sandbox/python.zip"

  lambda_runtime = "python3.9"
  lambda_timeout = 20

  lambda_in_vpc = false

  lambda_role_execution_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "ECS",
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
        "Sid" : "CloudWatch",
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
        "Sid" : "DynamoDB",
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
        "Sid" : "PassRoleECSTaskRoles",
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : [
          aws_iam_role.ecs_task_role.arn,
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.scheduler_role_invoke_shutdown_lambda.arn
        ]
      },
      {
        "Sid" : "EventBridgeGetSchedule",
        "Effect" : "Allow",
        "Action" : [
          "scheduler:GetSchedule",
          "scheduler:UpdateSchedule"
        ],
        "Resource" : "arn:aws:scheduler:${var.region}:${local.account_id}:schedule/${aws_scheduler_schedule_group.default.name}/*"
      }
    ]
  })

  environment_variables = {
      "company_prefix"            = var.company_prefix
      "domain"                    = var.domain
      "metadata_ddb_table"        = aws_dynamodb_table.metadata_table.name
      "ecs_cluster_arn"           = aws_ecs_cluster.main.arn,
      "ecs_access_log_group_name" = aws_cloudwatch_log_group.ecs_access_logs.name
      "scheduler_group_name"      = aws_scheduler_schedule_group.default.name
    }

  log_group_name = aws_cloudwatch_log_group.monitor_sandbox_lambda.name
}

# attach layer




# Lambda proxy-request normal requests to their respective ECS service

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
      },
      {
        "Sid" : "InvokeStartupLambda",
        "Effect" : "Allow",
        "Action" : "lambda:InvokeFunction",
        "Resource" : module.restart_sandbox_lambda.lambda_arn
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
  source_file = "lambdas/proxy-request/lambda_function.py"
  output_path = "lambdas/proxy-request/lambda_function.zip"
}

resource "aws_lambda_function" "lambda_proxy" {
  # code is in lambdas/lambda-proxy-request/lambda_function.py
  filename         = "lambdas/proxy-request/lambda_function.zip"
  source_code_hash = data.archive_file.proxy_lambda_code.output_base64sha256
  function_name    = "${var.company_prefix}-lambda-proxy"

  handler = "lambda_function.lambda_handler"
  role    = aws_iam_role.lambda_proxy_execution_role.arn
  runtime = "python3.10"
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
      "cloudmap_namespace"        = aws_service_discovery_http_namespace.main_api_namespace.name
      "ecs_access_log_group_name" = aws_cloudwatch_log_group.ecs_access_logs.name
      "metadata_ddb_table_name"   = aws_dynamodb_table.metadata_table.name
      "full_domain"               = var.domain
      "startup_task_lambda_arn"   = module.restart_sandbox_lambda.lambda_arn
    }
  }

  logging_config {
    log_group  = aws_cloudwatch_log_group.proxy_request_lambda.name
    log_format = "Text"
  }

  layers = [
    aws_lambda_layer_version.lambda_proxy_dependencies.arn
  ]

  depends_on = [
    aws_iam_role_policy_attachment.lambda_proxy_execution_role_policy_attachment,
    aws_cloudwatch_log_group.ecs_access_logs,
    aws_lambda_layer_version.lambda_proxy_dependencies,
    aws_cloudwatch_log_group.proxy_request_lambda,
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