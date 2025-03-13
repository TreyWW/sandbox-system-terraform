resource "aws_iam_role" "this" {
  name = "${var.prefix}-${var.name}"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : var.principal_services
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "policies" {
  count = length(var.inline_iam_policies)
  name = "${var.prefix}-${var.name}-policy-${var.inline_iam_policies[count.index].name}"

  policy = var.inline_iam_policies[count.index].policy_json
}

resource "aws_iam_role_policy_attachment" "execution_role_policy_attachment" {
  count = length(var.inline_iam_policies)
  role       = aws_iam_role.this.id
  policy_arn = aws_iam_policy.policies[count.index].arn
}