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
  public_key = file("./assets/keypair/ansible-node-keypair.pub")
}

resource "aws_security_group" "allow_tls" {
  name        = "ansible-node-sg"
  description = "Allow SSH inbound traffic and all outbound traffic"
  vpc_id      = var.vpc_id

  tags = {
    Name = "ansible-node-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_key_pair" "ansible_node_keypair" {
  key_name   = "ansible-node-keypair"
  public_key = local.public_key
}

resource "aws_instance" "ansible_node" {
  count = 3
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name = aws_key_pair.ansible_node_keypair.key_name
  vpc_security_group_ids = [ aws_security_group.allow_tls.id ]

  tags = {
    Name = "ansible-node-${count.index + 1}"
  }
}

output "node_ips" {
  value = {for i in aws_instance.ansible_node : i.tags_all.Name => i.public_ip }
}