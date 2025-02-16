/* ACM CERT FOR DOMAINS */


resource "aws_acm_certificate" "github_cert" {
  domain_name       = "*.gh.${var.domain}"
  validation_method = "DNS"
  tags = {
    Name = "github_cert"
  }
}

resource "aws_api_gateway_domain_name" "github_domain" {
  domain_name              = "*.gh.${var.domain}"
  regional_certificate_arn = aws_acm_certificate.github_cert.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

output "github_apigateway_domain_name_route" {
  value = aws_api_gateway_domain_name.github_domain.regional_domain_name
}

/* New github PR initiate infrastructure api gateway */

resource "aws_api_gateway_rest_api" "create_infrastructure_endpoint" {
  name        = "${var.company_prefix}_create_infrastructure_endpoint"
  description = "Create Infrastructure Endpoint"
}

resource "aws_api_gateway_method" "create_infrastructure_method" {
  rest_api_id   = aws_api_gateway_rest_api.create_infrastructure_endpoint.id
  resource_id = aws_api_gateway_rest_api.create_infrastructure_endpoint.root_resource_id # Changed this line
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_infrastructure_integration" {
  rest_api_id             = aws_api_gateway_rest_api.create_infrastructure_endpoint.id
  resource_id = aws_api_gateway_rest_api.create_infrastructure_endpoint.root_resource_id # Changed this line
  http_method             = aws_api_gateway_method.create_infrastructure_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.initial_service_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "create_infrastructure_deployment" {
  rest_api_id = aws_api_gateway_rest_api.create_infrastructure_endpoint.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.create_infrastructure_endpoint))
  }

  depends_on = [aws_api_gateway_integration.create_infrastructure_integration]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "create_infrastructure_stage" {
  stage_name    = "production"
  rest_api_id   = aws_api_gateway_rest_api.create_infrastructure_endpoint.id
  deployment_id = aws_api_gateway_deployment.create_infrastructure_deployment.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      "apiId" : "$context.apiId",
      "requestId" : "$context.requestId",
      "httpMethod" : "$context.httpMethod",
      "path" : "$context.path",
      "domainName" : "$context.domainName",
      "sourceIp" : "$context.identity.sourceIp",
      "userAgent" : "$context.identity.userAgent",
      "integrationStatus" : "$context.integration.status",
      "integrationLatency" : "$context.integration.latency",
      "integrationError" : "$context.integration.error",
      "integrationRequestId" : "$context.integration.requestId",
      "errorMessage" : "$context.error.message",
      "errorResponseType" : "$context.error.responseType",
      "responseLatency" : "$context.responseLatency",
      "responseLength" : "$context.responseLength",
      "requestTimeEpoch" : "$context.requestTimeEpoch"
    })
  }
}

/* Normal request to proxy to users instance api gateway */

resource "aws_iam_role" "api_gateway_execution_role_lambda_proxy" {
  name = "${var.company_prefix}-apigw-lambda-proxy-execution-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "apigateway.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "api_gateway_execution_role_lambda_proxy_policy" {
  name = "${var.company_prefix}-apigw-lambda-proxy-execution-role-policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "InvokeLambda",
        "Effect" : "Allow",
        "Action" : [
          "lambda:InvokeFunction"
        ],
        "Resource" : [
          aws_lambda_function.lambda_proxy.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_execution_role_lambda_proxy_policy_attachment" {
  role       = aws_iam_role.api_gateway_execution_role_lambda_proxy.id
  policy_arn = aws_iam_policy.api_gateway_execution_role_lambda_proxy_policy.arn
}

resource "aws_api_gateway_rest_api" "user_service_endpoint" {
  name        = "${var.company_prefix}_user_service_endpoint"
  description = "User Service Endpoint"

  disable_execute_api_endpoint = true
}

resource "aws_api_gateway_method" "user_service_method" {
  rest_api_id   = aws_api_gateway_rest_api.user_service_endpoint.id
  resource_id   = aws_api_gateway_rest_api.user_service_endpoint.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.user_service_endpoint.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "user_service_integration" {
  rest_api_id             = aws_api_gateway_rest_api.user_service_endpoint.id
  resource_id             = aws_api_gateway_rest_api.user_service_endpoint.root_resource_id
  http_method             = aws_api_gateway_method.user_service_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_proxy.invoke_arn
}

resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.user_service_endpoint.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_proxy.invoke_arn
}


resource "aws_api_gateway_deployment" "user_service_deployment" {
  rest_api_id = aws_api_gateway_rest_api.user_service_endpoint.id

  triggers = {
    redeployment = sha1(
      jsonencode(
        [
          aws_api_gateway_rest_api.user_service_endpoint,
          aws_api_gateway_method.user_service_method,
          aws_api_gateway_integration.user_service_integration,
          aws_api_gateway_method.proxy_method,
          aws_api_gateway_integration.proxy_integration
        ]
      ))
  }

  depends_on = [
    aws_api_gateway_integration.user_service_integration,
    aws_api_gateway_integration.proxy_integration
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_base_path_mapping" "user_service_github_mapping" {
  api_id      = aws_api_gateway_rest_api.user_service_endpoint.id
  stage_name  = aws_api_gateway_stage.user_service_stage.stage_name
  domain_name = aws_api_gateway_domain_name.github_domain.domain_name
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.user_service_endpoint.id
  parent_id   = aws_api_gateway_rest_api.user_service_endpoint.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_stage" "user_service_stage" {
  stage_name    = "production"
  rest_api_id   = aws_api_gateway_rest_api.user_service_endpoint.id
  deployment_id = aws_api_gateway_deployment.user_service_deployment.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      "apiId" : "$context.apiId",
      "requestId" : "$context.requestId",
      "httpMethod" : "$context.httpMethod",
      "path" : "$context.path",
      "domainName" : "$context.domainName",
      "sourceIp" : "$context.identity.sourceIp",
      "userAgent" : "$context.identity.userAgent",
      "integrationStatus" : "$context.integration.status",
      "integrationLatency" : "$context.integration.latency",
      "integrationError" : "$context.integration.error",
      "integrationRequestId" : "$context.integration.requestId",
      "errorMessage" : "$context.error.message",
      "errorResponseType" : "$context.error.responseType",
      "responseLatency" : "$context.responseLatency",
      "responseLength" : "$context.responseLength",
      "requestTimeEpoch" : "$context.requestTimeEpoch"
    })
  }
}