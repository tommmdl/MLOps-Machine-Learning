# Amazon Managed Prometheus
resource "aws_prometheus_workspace" "mlops" {
  alias = local.project
  tags  = local.tags
}

# IAM role — Prometheus agent (remote_write via SigV4)
resource "aws_iam_role" "prometheus_agent" {
  name = "prometheus-agent-${local.project}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "prometheus_agent_amp" {
  name = "amp-remote-write"
  role = aws_iam_role.prometheus_agent.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["aps:RemoteWrite", "aps:GetSeries", "aps:GetLabels", "aps:GetMetricMetadata"]
      Resource = aws_prometheus_workspace.mlops.arn
    }]
  })
}

# Amazon Managed Grafana
resource "aws_grafana_workspace" "mlops" {
  name                     = local.project
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  data_sources             = ["PROMETHEUS"]
  role_arn                 = aws_iam_role.grafana.arn
  tags                     = local.tags
}

resource "aws_iam_role" "grafana" {
  name = "grafana-${local.project}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "grafana.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "grafana_amp" {
  name = "amp-query"
  role = aws_iam_role.grafana.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["aps:QueryMetrics", "aps:GetSeries", "aps:GetLabels", "aps:GetMetricMetadata"]
      Resource = aws_prometheus_workspace.mlops.arn
    }]
  })
}

output "amp_remote_write_url" {
  value = "${aws_prometheus_workspace.mlops.prometheus_endpoint}api/v1/remote_write"
}

output "grafana_endpoint" {
  value = "https://${aws_grafana_workspace.mlops.endpoint}"
}
