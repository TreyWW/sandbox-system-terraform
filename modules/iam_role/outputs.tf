output "arn" {
  description = "The Amazon Resource Name (ARN) identifying the role."
  value       = aws_iam_role.this.arn
}