locals {
  default_tags = merge({
    Environment = var.env_prefix
  }, var.tags)
  name_fmt        = "%s-%s"
  name            = format(local.name_fmt, var.env_prefix, var.security_group.name)
  rule_id_to_rule = { for this in var.security_group.rules : this.id => this }
}

resource "aws_security_group" "this" {
  name   = local.name
  vpc_id = var.security_group.vpc.id

  tags = merge(
    local.default_tags,
    {
      Name = local.name
    }
  )
}

resource "aws_security_group_rule" "this" {
  for_each = local.rule_id_to_rule

  security_group_id        = aws_security_group.this.id
  cidr_blocks              = each.value.cidr_blocks
  source_security_group_id = each.value.source_security_group_id
  type                     = each.value.type
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
}
