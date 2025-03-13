output "lambda_arn" {
  value = aws_lambda_function.lambda.arn
}

output "lambda_invoke_arn" {
  value = aws_lambda_function.lambda.invoke_arn
}

output "lambda_function_name" {
  value = aws_lambda_function.lambda.function_name
}

output "security_group_id" {
  value = length(aws_security_group.lambda_sg) == 1 ? aws_security_group.lambda_sg[0].id : null
}

output "execution_role_arn" {
  value = module.iam_role.arn
}