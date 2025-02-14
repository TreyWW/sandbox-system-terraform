/* New github PR initiate infrastructure api gateway */

resource "aws_api_gateway_rest_api" "create_infrastructure_endpoint" {
  name        = "${var.company_prefix}_create_infrastructure_endpoint"
  description = "Create Infrastructure Endpoint"
}

resource "aws_api_gateway_resource" "create_infrastructure_resource" {
  rest_api_id = aws_api_gateway_rest_api.create_infrastructure_endpoint.id
  parent_id   = aws_api_gateway_rest_api.create_infrastructure_endpoint.root_resource_id
  path_part   = "/"
}

resource "aws_api_gateway_method" "create_infrastructure_method" {
  rest_api_id   = aws_api_gateway_rest_api.create_infrastructure_endpoint.id
  resource_id   = aws_api_gateway_resource.create_infrastructure_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_infrastructure_integration" {
  rest_api_id             = aws_api_gateway_rest_api.create_infrastructure_endpoint.id
  resource_id             = aws_api_gateway_resource.create_infrastructure_resource.id
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

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "create_infrastructure_stage" {
  stage_name    = "$default"
  rest_api_id   = aws_api_gateway_rest_api.create_infrastructure_endpoint.id
  deployment_id = aws_api_gateway_deployment.create_infrastructure_deployment.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format          = jsonencode({
      "apiId":  "$context.apiId",
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

resource "aws_api_gateway_rest_api" "user_service_endpoint" {
  name        = "${var.company_prefix}_user_service_endpoint"
  description = "User Service Endpoint"
}

resource "aws_api_gateway_resource" "user_service_resource" {
  rest_api_id = aws_api_gateway_rest_api.user_service_endpoint.id
  parent_id   = aws_api_gateway_rest_api.user_service_endpoint.root_resource_id
  path_part   = "/"
}

resource "aws_api_gateway_method" "user_service_method" {
  rest_api_id   = aws_api_gateway_rest_api.user_service_endpoint.id
  resource_id   = aws_api_gateway_resource.user_service_resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "user_service_integration" {
  rest_api_id             = aws_api_gateway_rest_api.user_service_endpoint.id
  resource_id             = aws_api_gateway_resource.user_service_resource.id
  http_method             = aws_api_gateway_method.user_service_method.http_method
  integration_http_method = "ANY"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_proxy.invoke_arn
}

resource "aws_api_gateway_deployment" "user_service_deployment" {
  rest_api_id = aws_api_gateway_rest_api.user_service_endpoint.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.user_service_endpoint))
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_api_gateway_stage" "user_service_stage" {
  stage_name    = "$default"
  rest_api_id   = aws_api_gateway_rest_api.user_service_endpoint.id
  deployment_id = aws_api_gateway_deployment.user_service_deployment.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format          = jsonencode({
      "apiId":  "$context.apiId",
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
