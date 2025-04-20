data "aws_ami" "amazon_linux" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.7.20250331.0-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  public_key = file("./assets/keypair/node-keypair.pub")
}

resource "aws_security_group" "allow_tls" {
  name        = "node-sg"
  description = "Allow SSH inbound traffic and all outbound traffic"
  vpc_id      = var.vpc_id

  tags = {
    Name = "node-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = var.my_ip
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_k3s_api_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = var.my_ip
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  referenced_security_group_id = aws_security_group.allow_tls.id
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_key_pair" "keypair" {
  key_name   = "node-keypair"
  public_key = local.public_key
}

resource "aws_instance" "agent_node" {
  count = 3
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.keypair.key_name
  vpc_security_group_ids = [ aws_security_group.allow_tls.id ]

  tags = {
    Name = "k3s-agent-node-${count.index + 1}"
    Project = "k3s-ansible"
    Environment = "dev"
    Role = "agent"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "k3s_server_role" {
  name               = "k3s-server-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_instance_profile" "k3s_server_profile" {
  name = "k3s-server-profile"
  role = aws_iam_role.k3s_server_role.name
}

resource "aws_iam_role_policy_attachment" "api_execution_role_attachment" {
  role       = aws_iam_role.k3s_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_instance" "server_node" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.medium"
  key_name = aws_key_pair.keypair.key_name
  vpc_security_group_ids = [ aws_security_group.allow_tls.id ]
  iam_instance_profile = aws_iam_instance_profile.k3s_server_profile.name

  tags = {
    Name = "k3s-server-node"
    Project = "k3s-ansible"
    Environment = "dev"
    Role = "server"
  }
}

output "agent_node_ips" {
  value = {for i in aws_instance.agent_node : i.tags_all.Name => i.public_ip }
}

output "server_node_ip" {
  value = aws_instance.server_node.public_ip
}