### IAM required for rds proxy accessing secrets and assume role
# trust policy
data "aws_iam_policy_document" "this_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

# RDS Proxy needs to read the secret value and (best practice) describe the secret.
data "aws_iam_policy_document" "this_secrets_read_only" {
  statement {
    sid = "AllowReadRDSSecrets"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [var.rds_proxy.secretsmanager_secret_arn]
  }
}

locals {
  iam_policy_name = format("%s-%s", var.env_prefix, "rds-proxy-secrets-readonly")
  iam_role_name   = format("%s-%s", var.env_prefix, "rds-proxy-role")
}

resource "aws_iam_policy" "this_secrets_read_only" {
  name   = local.iam_policy_name
  policy = data.aws_iam_policy_document.this_secrets_read_only.json
}

resource "aws_iam_role" "this" {
  name               = local.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.this_assume_role.json
}

resource "aws_iam_role_policy_attachment" "this_secrets_access" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this_secrets_read_only.arn
}


