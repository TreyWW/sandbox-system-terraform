resource "aws_service_discovery_http_namespace" "main_api_namespace" {
  name = "${var.company_prefix}-instance-map"
}