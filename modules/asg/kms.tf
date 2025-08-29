resource "aws_kms_key" "this" {
  description             = format("KMS CMK for %s ASG EC2 encryption", local.name)
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

locals {
  kms_alias_name = format("alias/%s-%s", local.name, "ec2")
}

resource "aws_kms_alias" "this" {
  name          = local.kms_alias_name
  target_key_id = aws_kms_key.this.key_id
}

