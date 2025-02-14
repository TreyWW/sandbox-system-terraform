# Lambda for creating initial service e.g. from github


resource "aws_security_group" "initial_service_lambda" {
  name        = "${var.company_prefix}-initial-service-lambda"
  description = "Security group for lambda function to create initial services"
  vpc_id      = aws_vpc.main.id
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
        "Effect" : "Allow",
        "Action" : [
          "ecs:CreateService",
          "ecs:RegisterTaskDefinition"
        ],
        "Resource" : [
          "arn:aws:ecs:${var.region}:${local.account_id}:service/${var.company_prefix}-*",
          "arn:aws:ecs:${var.region}:${local.account_id}:task-definition/${var.company_prefix}-*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "servicediscovery:RegisterInstance"
        ],
        "Resource" : "arn:aws:servicediscovery:${var.region}:${local.account_id}:service/*"
      },
      {
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
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:PutItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ],
        "Resource" : "arn:aws:dynamodb:${var.region}:${local.account_id}:table/${aws_dynamodb_table.metadata_table.name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "initial_service_lambda_execution_role_policy_attachment" {
  role       = aws_iam_role.initial_service_lambda_execution_role.id
  policy_arn = aws_iam_policy.initial_service_lambda_execution_role_policy.arn
}

resource "aws_lambda_function" "initial_service_lambda" {
  # code is in lambdas/initial-upload/lambda_function.py
  filename      = "lambdas/initial-upload/lambda_function.zip"
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
      aws_subnet.private_1a_with_nat,
      aws_subnet.private_1b_with_nat,
      aws_subnet.private_1c_with_nat
    ]
  }

  environment {
    variables = {
      "company_prefix" = var.company_prefix
      "domain" = var.domain
      "metadata_ddb_table" = aws_dynamodb_table.metadata_table.name
      "cloudmap_namespace_id" = aws_service_discovery_http_namespace.main_api_namespace.id
      "ecs_task_role_arn" = ""  # todo
      "ecs_execution_role_arn" = ""  # todo
      "ecs_log_group_arn" = aws_cloudwatch_log_group.lambda.name
      "ecs_log_group_region" = var.region
      "ecs_cluster_arn" = aws_ecs_cluster.main.arn
      "ecs_subnets" = "${aws_subnet.private_1a.id},${aws_subnet.private_1b.id},${aws_subnet.private_1c.id}"     ]
      "ecs_security_groups" = "${aws_security_group.ecs.id}"
      "shutdown_lambda_arn" = ""  # todo
      "scheduler_role_arn" = ""  # todo
    }
  }

  logging_config {
    log_group             = aws_cloudwatch_log_group.lambda.name
    application_log_group = aws_cloudwatch_log_group.lambda.name
  }

  depends_on = [
    aws_iam_role_policy_attachment.initial_service_lambda_execution_role_policy_attachment,
    aws_cloudwatch_log_group.lambda,
    aws_dynamodb_table.metadata_table,
    aws_ecs_cluster.main,
    aws_vpc.main
  ]
}


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
          "servicediscovery:GetInstance"
        ],
        "Resource" : "arn:aws:servicediscovery:${var.region}:${local.account_id}:service/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:GetItem"
        ],
        "Resource" : "arn:aws:dynamodb:${var.region}:${local.account_id}:table/${aws_dynamodb_table.metadata_table.name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_proxy_execution_role_policy_attachment" {
  role       = aws_iam_role.lambda_proxy_execution_role.id
  policy_arn = aws_iam_policy.lambda_proxy_execution_role_policy.arn
}

resource "aws_lambda_function" "lambda_proxy" {
  # code is in lambdas/lambda-proxy/lambda_function.py
  filename      = "lambdas/lambda-proxy/lambda_function.zip"
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
      aws_subnet.private_1a_with_nat,
      aws_subnet.private_1b_with_nat,
      aws_subnet.private_1c_with_nat
    ]
  }

  environment {
    variables = {
      "cloudmap_namespace" = aws_service_discovery_http_namespace.main_api_namespace.name
    }
  }

  logging_config {
    log_group             = aws_cloudwatch_log_group.lambda.name
    application_log_group = aws_cloudwatch_log_group.lambda.name
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_proxy_execution_role_policy_attachment,
    aws_cloudwatch_log_group.lambda,
    aws_dynamodb_table.metadata_table,
    aws_ecs_cluster.main,
    aws_vpc.main
  ]
}