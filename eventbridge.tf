resource "aws_scheduler_schedule_group" "default" {
  name = "${var.company_prefix}-scheduler-group"
}

resource "aws_iam_role" "scheduler_role_invoke_shutdown_lambda" {
  name = "${var.company_prefix}-scheduler-role-invoke-shutdown-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "scheduler_role_invoke_shutdown_lambda" {
  name = "${var.company_prefix}-scheduler-role-invoke-shutdown-lambda-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect   = "Allow"
        Resource = [
          aws_lambda_function.shutdown_instance_lambda.arn,
          "${aws_lambda_function.shutdown_instance_lambda.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "scheduler_role_invoke_shutdown_lambda" {
  role       = aws_iam_role.scheduler_role_invoke_shutdown_lambda.name
  policy_arn = aws_iam_policy.scheduler_role_invoke_shutdown_lambda.arn
}