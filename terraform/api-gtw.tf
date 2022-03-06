resource "aws_api_gateway_rest_api" "reporting-incidents" {
  name = "reporting-incidents"
}

resource "aws_cloudwatch_log_group" "reporting-incidents-log-group" {
  name              = "/aws/api_gtw/${aws_api_gateway_rest_api.reporting-incidents.name}"
  retention_in_days = 30
}

resource "aws_api_gateway_deployment" "reporting-incidents-deployment" {
  rest_api_id       = aws_api_gateway_rest_api.reporting-incidents.id
  stage_description = timestamp()
  description       = "Created with terraform deployment on ${timestamp()}"

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.reporting-incidents_report-post_integration,
    aws_api_gateway_integration_response.reporting-incidents_report-post-response_integration_200,
    aws_api_gateway_rest_api.reporting-incidents
  ]
}

resource "aws_api_gateway_stage" "reporting-incidents-stage" {
  deployment_id = aws_api_gateway_deployment.reporting-incidents-deployment.id
  rest_api_id   = aws_api_gateway_rest_api.reporting-incidents.id
  stage_name    = "live"

  depends_on = [
    aws_api_gateway_deployment.reporting-incidents-deployment,
  ]
}

resource "aws_api_gateway_resource" "reporting-incidents_api-resource" {
  parent_id   = aws_api_gateway_rest_api.reporting-incidents.root_resource_id
  path_part   = "api"
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
}

resource "aws_api_gateway_resource" "reporting-incidents_v1-resource" {
  parent_id   = aws_api_gateway_resource.reporting-incidents_api-resource.id
  path_part   = "v1"
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
}

resource "aws_api_gateway_resource" "reporting-incidents_report-resource" {
  parent_id   = aws_api_gateway_resource.reporting-incidents_v1-resource.id
  path_part   = "report"
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
}

resource "aws_api_gateway_method" "reporting-incidents_post-report" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.reporting-incidents_report-resource.id
  rest_api_id   = aws_api_gateway_rest_api.reporting-incidents.id
}

resource "aws_api_gateway_integration" "reporting-incidents_report-post_integration" {
  http_method             = aws_api_gateway_method.reporting-incidents_post-report.http_method
  resource_id             = aws_api_gateway_resource.reporting-incidents_report-resource.id
  rest_api_id             = aws_api_gateway_rest_api.reporting-incidents.id
  type                    = "AWS"
  integration_http_method = "POST"
  credentials             = aws_iam_role.apiSQS.arn
  uri                     = "arn:aws:apigateway:eu-central-1:sqs:path/${aws_sqs_queue.reporting-incidents_sqs.name}"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }
}

resource "aws_api_gateway_method_response" "reporting-incidents_report-post-response_200" {
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id = aws_api_gateway_resource.reporting-incidents_report-resource.id
  http_method = aws_api_gateway_method.reporting-incidents_post-report.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "reporting-incidents_report-post-response_integration_200" {
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id = aws_api_gateway_resource.reporting-incidents_report-resource.id
  http_method = aws_api_gateway_method.reporting-incidents_post-report.http_method
  status_code = aws_api_gateway_method_response.reporting-incidents_report-post-response_200.status_code

  response_templates = {
    "application/json" = <<EOF
{
  "message": "success"
}
EOF
  }
}