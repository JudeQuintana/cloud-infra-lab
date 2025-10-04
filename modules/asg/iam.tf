# both AllowServiceLinkedRoleUseOfCMK and AllowAttachmentOfPersistentResources statements are required
# to allow EC2/Auto Scaling use the CMK to encrypt root volumes

data "aws_iam_policy_document" "this_kms" {
  statement {
    sid       = "EnableIAMUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowServiceLinkedRoleUseOfCMK"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${local.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
      ]
    }
  }

  statement {
    sid    = "AllowAttachmentOfPersistentResources"
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
    ]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${local.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
      ]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"] # must be a string here
    }
  }
}

resource "aws_kms_key_policy" "this" {
  key_id = aws_kms_key.this.key_id
  policy = data.aws_iam_policy_document.this_kms.json
}


## SSM
data "aws_iam_policy_document" "this_ssm_assume_role" {
  statement {
    sid     = "SSMAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

locals {
  ssm_iam_name = format("%s-asg-instance-ssm", local.name)
}

resource "aws_iam_role" "this_ssm" {
  name               = local.ssm_iam_name
  assume_role_policy = data.aws_iam_policy_document.this_ssm_assume_role.json
}

resource "aws_iam_role_policy_attachment" "this_ssm_core" {
  role       = aws_iam_role.this_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this_ssm" {
  name = local.ssm_iam_name
  role = aws_iam_role.this_ssm.name
}

