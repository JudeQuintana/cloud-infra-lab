locals {
  vpcs_with_private_route_table_and_subnet_ids = {
    for this in module.vpcs :
    this.name => this
    if length(this.private_route_table_ids) > 0 && length(this.private_subnet_name_to_subnet_id) > 0
  }
}

# at scale we're saving money right here
resource "aws_vpc_endpoint" "s3" {
  for_each = local.vpcs_with_private_route_table_and_subnet_ids

  vpc_id            = each.value.id
  service_name      = format("com.amazonaws.%s.s3", each.value.region)
  vpc_endpoint_type = "Gateway"
  route_table_ids   = each.value.private_route_table_ids

  tags = {
    Name = format("%s-s3-gateway", each.value.full_name)
  }
}

# Systems Manager endpoint
resource "aws_vpc_endpoint" "ssm" {
  for_each = local.vpcs_with_private_route_table_and_subnet_ids

  vpc_id            = each.value.id
  service_name      = format("com.amazonaws.%s.ssm", each.value.region)
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    lookup(each.value.private_subnet_name_to_subnet_id, "proxy1"),
    lookup(each.value.private_subnet_name_to_subnet_id, "proxy2")
  ]
  security_group_ids  = [aws_security_group.ssm.id]
  private_dns_enabled = true

  tags = {
    Name = format("%s-ssm-endpoint", each.value.full_name)
  }
}

# EC2 messages endpoint
resource "aws_vpc_endpoint" "ec2messages" {
  for_each = local.vpcs_with_private_route_table_and_subnet_ids

  vpc_id            = each.value.id
  service_name      = format("com.amazonaws.%s.ec2messages", each.value.region)
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    lookup(each.value.private_subnet_name_to_subnet_id, "proxy1"),
    lookup(each.value.private_subnet_name_to_subnet_id, "proxy2")
  ]
  security_group_ids  = [aws_security_group.ssm.id]
  private_dns_enabled = true

  tags = {
    Name = format("%s-ec2messages-endpoint", each.value.full_name)
  }
}

# SSM messages endpoint
resource "aws_vpc_endpoint" "ssmmessages" {
  for_each = local.vpcs_with_private_route_table_and_subnet_ids

  vpc_id            = each.value.id
  service_name      = format("com.amazonaws.%s.ssmmessages", each.value.region)
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    lookup(each.value.private_subnet_name_to_subnet_id, "proxy1"),
    lookup(each.value.private_subnet_name_to_subnet_id, "proxy2")
  ]
  security_group_ids  = [aws_security_group.ssm.id]
  private_dns_enabled = true

  tags = {
    Name = format("%s-ssmmessages-endpoint", each.value.full_name)
  }
}

# (Optional) CloudWatch Logs endpoint for session logging
resource "aws_vpc_endpoint" "logs" {
  for_each = local.vpcs_with_private_route_table_and_subnet_ids

  vpc_id            = each.value.id
  service_name      = format("com.amazonaws.%s.logs", each.value.region)
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    lookup(each.value.private_subnet_name_to_subnet_id, "proxy1"),
    lookup(each.value.private_subnet_name_to_subnet_id, "proxy2")
  ]
  security_group_ids  = [aws_security_group.ssm.id]
  private_dns_enabled = true

  tags = {
    Name = format("%s-logs-endpoint", each.value.full_name)
  }
}

