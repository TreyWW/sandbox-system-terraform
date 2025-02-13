resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# ---- PEER ANOTHER ACCOUNT ----

resource "aws_vpc_peering_connection" "main" {
  count = var.peer_vpc_enabled ? 1 : 0
  vpc_id = aws_vpc.main.id
  peer_vpc_id = var.peer_vpc_id
  peer_owner_id = var.peer_owner_id
  peer_region = var.peer_vpc_region

  tags = {
    Name = "${var.company_prefix}-vpc-root-peer"
  }
}

# ---- PUBLIC SUBNETS (1 per AZ) ----
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.sn_cidr_public_1a
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false  # Use explicit public IP assignment for EC2 instances
  tags = {
    Name = "main-sn-public-1a"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.sn_cidr_public_1b
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = false
  tags = {
    Name = "main-sn-public-1b"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.sn_cidr_public_1c
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = false
  tags = {
    Name = "main-sn-public-1c"
  }
}

# ---- PRIVATE SUBNETS (1 per AZ, NO internet access) ----
resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.sn_cidr_private_1a
  availability_zone = "${var.region}a"
  tags = {
    Name = "main-sn-private-1a"
  }
}

resource "aws_subnet" "private_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.sn_cidr_private_1b
  availability_zone = "${var.region}b"
  tags = {
    Name = "main-sn-private-1b"
  }
}

resource "aws_subnet" "private_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.sn_cidr_private_1c
  availability_zone = "${var.region}c"
  tags = {
    Name = "main-sn-private-1c"
  }
}

# ---- PRIVATE SUBNETS WITH NAT (1 per AZ, outbound access) ----
resource "aws_subnet" "private_1a_with_nat" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.sn_cidr_private_1a_with_nat
  availability_zone = "${var.region}a"
  tags = {
    Name = "main-sn-private-1a-nat"
  }
}

resource "aws_subnet" "private_1b_with_nat" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.sn_cidr_private_1b_with_nat
  availability_zone = "${var.region}b"
  tags = {
    Name = "main-sn-private-1b-nat"
  }
}

resource "aws_subnet" "private_1c_with_nat" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.sn_cidr_private_1c_with_nat
  availability_zone = "${var.region}c"
  tags = {
    Name = "main-sn-private-1c-nat"
  }
}

# ---- ROUTE TABLES FOR PUBLIC ----

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_1c" {
  subnet_id      = aws_subnet.public_1c.id
  route_table_id = aws_route_table.public_rt.id
}

# ---- ROUTE TABLES FOR PRIVATE ----

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route" "root_account_peer_pvt" {
  count = var.peer_vpc_enabled ? 1 : 0
  route_table_id = aws_route_table.private_rt.id

  destination_cidr_block = var.peer_vpc_cidr

  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_1b" {
  subnet_id      = aws_subnet.private_1b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_1c" {
  subnet_id      = aws_subnet.private_1c.id
  route_table_id = aws_route_table.private_rt.id
}

# ---- ROUTE TABLES FOR PRIVATE WITH NAT ----

resource "aws_route_table" "private_rt_with_nat" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "private-route-table-with-nat"
  }
}

resource "aws_route" "root_account_peer_pvt_nat" {
  count = var.peer_vpc_enabled ? 1 : 0
  route_table_id = aws_route_table.private_rt_with_nat.id

  destination_cidr_block = var.peer_vpc_cidr

  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
}

resource "aws_route_table_association" "private_1a_with_nat" {
  subnet_id      = aws_subnet.private_1a_with_nat.id
  route_table_id = aws_route_table.private_rt_with_nat.id
}

resource "aws_route_table_association" "private_1b_with_nat" {
  subnet_id      = aws_subnet.private_1b_with_nat.id
  route_table_id = aws_route_table.private_rt_with_nat.id
}

resource "aws_route_table_association" "private_1c_with_nat" {
  subnet_id      = aws_subnet.private_1c_with_nat.id
  route_table_id = aws_route_table.private_rt_with_nat.id
}