

# Allocate an Elastic IP for Fck-NAT
resource "aws_eip" "fck_nat_eip" {
  # Removed the domain attribute
}

# Disable Source/Destination Check on the ENI
resource "aws_network_interface" "fck_nat_eni" {
  description = "fck-nat static private ENI"
  subnet_id         = aws_subnet.public_1a.id
  security_groups = [aws_security_group.fck_nat_sg.id]
  source_dest_check = false

  tags = {
    Name = "fck-nat-eni-sdc"
  }
}

# Fck-NAT EC2 Instance
resource "aws_instance" "fck_nat" {
  ami                         = "ami-00d653f185e930c04"
  instance_type               = "t4g.nano"

  network_interface {
    device_index          = 0
    network_interface_id  = "${aws_network_interface.fck_nat_eni.id}"
  }

  tags = {
    Name = "fck-nat-instance"
  }

  lifecycle {
    ignore_changes = [
      source_dest_check,
      user_data,
      tags
    ]
  }
}

# Associate the Elastic IP with the NAT instance
resource "aws_eip_association" "fck_nat_eip_assoc" {
  instance_id   = aws_instance.fck_nat.id
  allocation_id = aws_eip.fck_nat_eip.id
}


resource "aws_security_group" "fck_nat_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "fck-nat-sg"
  description = "Security group for Fck-NAT instance"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      aws_subnet.private_1a_with_nat.cidr_block,
      aws_subnet.private_1b_with_nat.cidr_block,
      aws_subnet.private_1c_with_nat.cidr_block
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "fck-nat-sg"
  }
}

resource "aws_route" "private_route_to_nat" {
  route_table_id = aws_route_table.private_rt_with_nat.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id = aws_network_interface.fck_nat_eni.id
}