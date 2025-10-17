locals {
  services = {
	"ec2messages": {
		"name": "com.amazonaws.ap-south-1.ec2messages"
	},
	"ssm": {
		"name": "com.amazonaws.ap-south-1.ssm"
	},
	"ssmmessages": {
		"name": "com.amazonaws.ap-south-1.ssmmessages"
	}
  }
}

resource "aws_vpc" "testvpc" {
	cidr_block	= var.vpc_cidr
	enable_dns_support	= true
	enable_dns_hostnames	= true
	tags = {
		environment = "test"
	}
}

resource "aws_subnet" "testsubnet" {
  vpc_id = aws_vpc.testvpc.id
  cidr_block = var.subnet_cidr
  availability_zone = var.availability_zone
  map_public_ip_on_launch = false
  tags = {
	environment = "test"
  }
}

resource "aws_security_group" "testsg" {
  name = "testsecuritygroup"
  vpc_id = aws_vpc.testvpc.id
}

resource "aws_vpc_security_group_ingress_rule" "testsgingressrule" {
  security_group_id = aws_security_group.testsg.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = -1
}

resource "aws_vpc_security_group_egress_rule" "testsgegressrule" {
  security_group_id = aws_security_group.testsg.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = -1
}

resource "aws_internet_gateway" "testigw" {
  vpc_id = aws_vpc.testvpc.id
  tags = {
	environment = "test"
  }
}

resource "aws_route_table" "testpublicroute" {
  vpc_id = aws_vpc.testvpc.id
  route {
	cidr_block = "0.0.0.0/0"
	gateway_id = aws_internet_gateway.testigw.id
  }
  route {
	cidr_block = "10.1.0.0/16"
	gateway_id = "local"
  }
  route {
	cidr_block = "172.16.0.0/24"
	network_interface_id = aws_instance.mastervm.primary_network_interface_id
  }
  route {
	cidr_block = "172.16.1.0/24"
	network_interface_id = aws_instance.workervm.primary_network_interface_id
  }
  tags = {
	environment = "test"
  }
}

resource "aws_route_table_association" "testpublicrouteassoc" {
  subnet_id = aws_subnet.testsubnet.id
  route_table_id = aws_route_table.testpublicroute.id
}

resource "aws_iam_role" "test_ssm_role" {
  name = "testssm-role"
  assume_role_policy = jsonencode({
	Version = "2012-10-17",
	Statement = [
		{
		Effect = "Allow",
		Principal = {
			Service = "ec2.amazonaws.com"
		},
		Action = "sts:AssumeRole"
	},
	# {
	# 	"Effect": "Allow",
	# 	"Action": "iam:CreateServiceLinkedRole",
	# 	"Resource": "arn:aws:iam::*:role/aws-service-role/ssm.amazonaws.com/AWSServiceRoleForAmazonSSM*",
	# 	"Condition": {
	# 		"StringLike": {
	# 			"iam:AWSServiceName": "ssm.amazonaws.com"
	# 		}
	# 	}
    # },
	]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role = aws_iam_role.test_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "testssm-instance-profile"
  role = aws_iam_role.test_ssm_role.name
}

resource "aws_key_pair" "mastervmkey" {
  key_name = "testvmkey.pub"
  public_key = "ssh-rsa blahblah"
}

resource "aws_instance" "mastervm" {
	subnet_id = aws_subnet.testsubnet.id
	vpc_security_group_ids = [aws_security_group.testsg.id]
	launch_template {
	  id = "lt-0c1be070d65a9ae3c"
	  version = 1
	}
	associate_public_ip_address = false
	iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
	instance_type = "t3a.nano"
	key_name = aws_key_pair.mastervmkey.key_name
	source_dest_check = false
}

resource "aws_instance" "workervm" {
	subnet_id = aws_subnet.testsubnet.id
	vpc_security_group_ids = [aws_security_group.testsg.id]
	launch_template {
	  id = "lt-0c1be070d65a9ae3c"
	  version = 1
	}
	iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
	instance_type = "t3a.nano"
	key_name = aws_key_pair.mastervmkey.key_name
	source_dest_check = false
}

resource "aws_vpc_endpoint" "ssm_endpoint" {
	for_each = local.services

	vpc_id = aws_vpc.testvpc.id
	service_name = each.value.name
	vpc_endpoint_type = "Interface"
	security_group_ids = [aws_security_group.testsg.id]
	private_dns_enabled = true
	ip_address_type = "ipv4"
	subnet_ids = [aws_subnet.testsubnet.id]
}

resource "aws_vpc_endpoint" "s3_endpoint" {
	vpc_id = aws_vpc.testvpc.id
	service_name = "com.amazonaws.ap-south-1.s3"
	vpc_endpoint_type = "Gateway"
	private_dns_enabled = false
	route_table_ids = [aws_route_table.testpublicroute.id]
  
}


