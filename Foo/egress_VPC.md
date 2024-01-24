Delete default VPC

## Bastion and Egress VPC
Create VPC
 Name: vpc-bne
 CIDR: 10.16.0.0/24
 
Create Subnet (public)
 Name: subnet-bne-public-1
 CIDR: 10.16.0.128/25

Create Subnet (private)
 Name: subnet-bne-private-1
 CIDR: 10.16.0.0/25

Create Internet Gateway
 Name: IGW-bne
 (attach to VPC)

Create NATGW
  Name: natgw-bne
  Subnet:  (public)
  EIP allocation:  click "Allocate Elastic IP"

## OCP4 VPC
Create VPC
  Name: vpc-ocp4-test
  CIDR: 10.0.0.0/24

Create Subnet (private)
 Name: subnet-ocp-private-1
 CIDR: 10.0.0.0/26

Create Subnet (private)
 Name: subnet-ocp-private-2
 CIDR: 10.0.0.64/26

Create Subnet (private)
 Name: subnet-ocp-private-3
 CIDR: 10.0.0.128/26

## Transit Gateway
Create Transit Gateway
  Name: tgw-mockup

Create Transit Gateway Attachment
  Name: tgw-attach-ocp4-test

Create Transit Gateway Route Table
  Name: tgw-rt-mockup

Create Routes

