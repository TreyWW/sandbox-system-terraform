


## Setup



### VPC Peering

Already have a NAT in another account/VPC, no worries lets make use of that to save costs.

(todo)

Go in your NAT Security Group and allow inbound 3 inbound rules, 1 for each of the NAT subnets (sn_cidr_private_1a_with_nat, 
sn_cidr_private_1b_with_nat and sn_cidr_private_1c_with_nat)

Go into your NAT VPC Route Table and add the vpc_cidr and set it to the aws_vpc_peering_connection id 