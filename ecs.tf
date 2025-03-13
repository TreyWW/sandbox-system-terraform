resource "aws_ecs_cluster" "main" {
  name = "${var.company_prefix}-sandbox-cluster"

  configuration {
    execute_command_configuration {
      kms_key_id = "arn:aws:kms:${var.region}:${local.account_id}:alias/aws/ebs"
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs.name
      }
    }
  }
}

resource "aws_security_group" "ecs" {
  name   = "${var.company_prefix}-sandbox-ecs-sg"
  vpc_id = aws_vpc.main.id
}


resource "aws_vpc_security_group_ingress_rule" "ecs-ingress-443" {
  security_group_id = aws_security_group.ecs.id

  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = module.proxy_request_lambda.security_group_id
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ecs-ingress-80" {
  security_group_id = aws_security_group.ecs.id

  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = module.proxy_request_lambda.security_group_id
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs-egress-443" {
  security_group_id = aws_security_group.ecs.id

  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.fck_nat_sg.id
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs-egress-80" {
  security_group_id = aws_security_group.ecs.id

  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.fck_nat_sg.id
  ip_protocol                  = "tcp"
}


# ecs_execution_role

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.company_prefix}-sandbox-ecs-execution-role"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "ecs-tasks.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}

resource "aws_iam_policy" "ecs_execution_role" {
  name = "${var.company_prefix}-sandbox-ecs-execution-role-policy"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:logs:${var.region}:${local.account_id}:log-group:${aws_cloudwatch_log_group.ecs.name}:log-stream:*"
        } # todo add ECR
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_role.arn
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.company_prefix}-sandbox-ecs-task-role"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "ecs-tasks.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}