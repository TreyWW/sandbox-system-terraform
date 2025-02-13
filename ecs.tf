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

resource "aws_cloudwatch_log_group" "ecs" {
  name = "/ecs/${var.company_prefix}-sandbox/"
}