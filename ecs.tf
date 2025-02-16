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