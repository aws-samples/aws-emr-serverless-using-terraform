## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved
##
### SPDX-License-Identifier: MIT-0

resource "aws_vpc" "click_logger_emr_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.app_prefix}-${var.stage_name}-VPC"
  }
}

resource "aws_subnet" "click_logger_emr_public_subnet1" {
  vpc_id     = aws_vpc.click_logger_emr_vpc.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "${var.app_prefix}-${var.stage_name}-public-subnet1"
  }
}

resource "aws_subnet" "click_logger_emr_private_subnet1" {
  vpc_id     = aws_vpc.click_logger_emr_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "${var.app_prefix}-${var.stage_name}-private-subnet1"
  }
}

resource "aws_internet_gateway" "click_logger_emr_igw" {
  vpc_id = aws_vpc.click_logger_emr_vpc.id
}

resource "aws_route_table" "click_logger_emr_route_table" {
  vpc_id = aws_vpc.click_logger_emr_vpc.id
}

resource aws_route "click_logger_emr_public_route" {
  route_table_id         = aws_route_table.click_logger_emr_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.click_logger_emr_igw.id
}

resource "aws_route_table_association" "click_logger_emr_route_table_association1" {
  subnet_id      = aws_subnet.click_logger_emr_public_subnet1.id
  route_table_id = aws_route_table.click_logger_emr_route_table.id
}

resource "aws_eip" "click_logger_emr_ip" {
  vpc = true

  tags = {
    Name = "${var.app_prefix}-${var.stage_name}-elastic-ip"
  }
}

resource "aws_nat_gateway" "click_logger_emr_ngw" {
  allocation_id = aws_eip.click_logger_emr_ip.id
  subnet_id = aws_subnet.click_logger_emr_public_subnet1.id

  tags = {
    "Name" = "${var.app_prefix}-${var.stage_name}-NATGateway"
  }
}

resource "aws_route_table" "click_logger_emr_ngw_route_table" {
  vpc_id = aws_vpc.click_logger_emr_vpc.id
}

resource aws_route "click_logger_emr_ngw_route" {
  route_table_id         = aws_route_table.click_logger_emr_ngw_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.click_logger_emr_ngw.id
}

resource "aws_route_table_association" "click_logger_emr_ngw_route_table_association1" {
  subnet_id      = aws_subnet.click_logger_emr_private_subnet1.id
  route_table_id = aws_route_table.click_logger_emr_ngw_route_table.id
}

resource "aws_route_table" "click_logger_emr_vpce_route_table" {
  vpc_id = aws_vpc.click_logger_emr_vpc.id
}

resource aws_route "click_logger_emr_vpce_route" {
  route_table_id         = aws_route_table.click_logger_emr_vpce_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.click_logger_emr_ngw.id
}

resource "aws_security_group" "click_logger_emr_security_group" {
  name                   = "${var.app_prefix}-${var.stage_name}-SecurityGroup"
  description            = "Allowed Ports"
  vpc_id                 = aws_vpc.click_logger_emr_vpc.id
}

resource "aws_security_group_rule" "click_logger_emr_security_group_rule" {
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.click_logger_emr_security_group.id
}
