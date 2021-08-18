# Complete example

terraform {
  required_version = "~> 0.14.2"

  backend "s3" {
    key    = "opencloudcx"
    bucket = "gsa-comet-opencloudcx-state-bucket"
    region = "us-east-1"
  }
}

resource "random_string" "random" {
  length  = 8
  special = false
  upper   = false
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  version             = ">= 3.0"
}

provider "aws" {
  alias               = "prod"
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  version             = ">= 3.0"
}

module "opencloudcx" {
  source  = "OpenCloudCX/opencloudcx/aws"
  version = ">= 0.3.11"

  # source = "../../terraform-aws-opencloudcx"

  name               = "example"
  stack              = "dev"
  detail             = "module-test"
  tags               = { "env" = "dev" }
  region             = "us-east-1"
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  cidr               = "10.0.0.0/16"
  dns_zone           = "your.private"
  kubernetes_version = "1.18"
  kubernetes_node_groups = {
    default = {
      instance_type = "m5.large"
      min_size      = "1"
      max_size      = "3"
      desired_size  = "2"
    }
  }

  jenkins_secret   = random_password.jenkins_password.result
  sonarqube_secret = random_password.sonarqube_password.result
  # portainer_secret = aws_secretsmanager_secret.portainer_secret

  aurora_cluster = {
    node_size = "1"
    node_type = "db.t3.medium"
    version   = "5.7.12"
  }
  helm_chart_version = "2.2.3"
  helm_chart_values  = [file("values.yaml")]
  assume_role_arn    = [module.spinnaker-managed-role.role_arn]
}

module "spinnaker-managed-role" {
  source  = "OpenCloudCX/opencloudcx/aws//modules/spinnaker-managed-aws"
  version = "~> 0.3.11"

  # source = "../../terraform-aws-opencloudcx/modules/spinnaker-managed-aws"

  providers        = { aws = aws.prod }
  name             = "example"
  stack            = "dev"
  trusted_role_arn = [module.opencloudcx.role_arn]
}