# both AllowServiceLinkedRoleUseOfCMK and AllowAttachmentOfPersistentResources statements are required
# to allow EC2/Auto Scaling use the CMK

data "aws_iam_policy_document" "this" {
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
  policy = data.aws_iam_policy_document.this.json
}
